import Foundation
import Logging

/// Follows a paged list response.
///
/// A JSON array is the previous server and is already the whole collection,
/// so the walker does not request another page.
enum SDKListPage {
    static let maxFollowedPages = 100

    /// Every field is optional so a proxy that strips one can be noticed by the
    /// walker. Throwing here would lose the rows already read.
    struct Meta: Decodable, Sendable {
        var page: Int?
        var perPage: Int?
        var totalPages: Int?
    }

    struct Envelope<Item: Decodable>: Decodable {
        var items: [Item]
        var meta: Meta?
    }

    enum Decoded<Item> {
        case legacy([Item])
        case page(items: [Item], meta: Meta?)
    }

    static func collect<Item>(
        path: String,
        logger: Logger,
        page: Int?,
        perPage: Int?,
        fetch: ([URLQueryItem]) async throws -> Data,
        decode: (Data) throws -> Decoded<Item>
    ) async throws -> [Item] {
        let first = try decode(try await fetch(query(page: page, perPage: perPage)))
        switch first {
        case .legacy(let items):
            return items
        case .page(let items, let meta):
            // A first response without `page` answers the page the caller asked for: page 1.
            let firstPage = meta?.page ?? 1
            var size = meta?.perPage ?? items.count
            var totalPages = meta?.totalPages ?? 1
            if page != nil || size < 1 || items.isEmpty || firstPage >= totalPages {
                return items
            }
            var collected = items
            var next = firstPage + 1
            var followed = 0
            while next <= totalPages {
                guard followed < maxFollowedPages else {
                    logStopped(logger, path: path, requested: next, received: next - 1)
                    return collected
                }
                let more = try decode(try await fetch(query(page: next, perPage: size)))
                followed += 1
                switch more {
                case .legacy:
                    return collected
                case .page(let moreItems, let moreMeta):
                    let moreSize = moreMeta?.perPage ?? moreItems.count
                    if moreItems.isEmpty || moreSize < 1 {
                        return collected
                    }
                    // A proxy that ignores the query answers with a page already read.
                    // Its rows are not appended, so no page is counted twice.
                    guard moreMeta?.page == next else {
                        logStopped(logger, path: path, requested: next, received: moreMeta?.page)
                        return collected
                    }
                    collected.append(contentsOf: moreItems)
                    totalPages = moreMeta?.totalPages ?? 1
                    if next >= totalPages {
                        return collected
                    }
                    next += 1
                    size = moreSize
                }
            }
            return collected
        }
    }

    /// The path and the two page numbers only. Never the query, a key, a user id or a row.
    private static func logStopped(_ logger: Logger, path: String, requested: Int, received: Int?) {
        logger.warning(
            "FeedbackKit stopped following pages of \(path): requested page \(requested), received page \(received.map(String.init) ?? "missing")"
        )
    }

    /// List decoding used to go through `FeedbackKitClient.decodeOrThrow`, which
    /// turns a `DecodingError` into `FeedbackKitError.decodingError`. The page
    /// walker decodes the body itself, so it has to keep that same mapping.
    /// A tolerant element drop still happens inside `body`; this only wraps
    /// errors that escape it.
    static func decoding<T>(_ body: () throws -> T) throws -> T {
        do {
            return try body()
        } catch let error as FeedbackKitError {
            throw error
        } catch {
            throw FeedbackKitError.decodingError(String(describing: error))
        }
    }

    static func query(page: Int?, perPage: Int?) -> [URLQueryItem] {
        var items: [URLQueryItem] = [URLQueryItem(name: "paged", value: "1")]
        if let page {
            items.append(URLQueryItem(name: "page", value: String(page)))
        }
        if let perPage {
            items.append(URLQueryItem(name: "per_page", value: String(perPage)))
        }
        return items
    }
}
