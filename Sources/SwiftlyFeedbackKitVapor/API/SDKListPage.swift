import Foundation

/// Follows a paged list response.
///
/// A JSON array is the previous server and is already the whole collection,
/// so the walker does not request another page.
enum SDKListPage {
    static let maxPages = 100

    struct Meta: Decodable, Sendable {
        var page: Int
        var perPage: Int
        var totalPages: Int
    }

    struct Envelope<Item: Decodable>: Decodable {
        var items: [Item]
        var meta: Meta
    }

    enum Decoded<Item> {
        case legacy([Item])
        case page(items: [Item], meta: Meta)
    }

    static func collect<Item>(
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
            if page != nil || meta.perPage < 1 || items.isEmpty || meta.page >= meta.totalPages {
                return items
            }
            var collected = items
            var next = meta.page + 1
            var size = meta.perPage
            var totalPages = meta.totalPages
            while next <= totalPages && next <= maxPages {
                let more = try decode(try await fetch(query(page: next, perPage: size)))
                switch more {
                case .legacy:
                    return collected
                case .page(let moreItems, let moreMeta):
                    if moreItems.isEmpty || moreMeta.perPage < 1 {
                        return collected
                    }
                    collected.append(contentsOf: moreItems)
                    if moreMeta.page >= moreMeta.totalPages {
                        return collected
                    }
                    next = moreMeta.page + 1
                    size = moreMeta.perPage
                    totalPages = moreMeta.totalPages
                }
            }
            return collected
        }
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
