import Foundation
import Vapor
@testable import SwiftlyFeedbackKitVapor

/// A recording, scriptable `Vapor.Client` for driving the real `FeedbackKitClient`
/// through its synthesised internal memberwise init (the seam, QA-UNIT12 §4.2).
///
/// - Records every `ClientRequest` in call order.
/// - Scripts a response (or a transport failure) **per call**; when nothing is
///   scripted it answers `200 OK` with an empty body.
/// - Shape inherited from the server test suite's `CapturingClient`
///   (`LinearServiceTests.swift`, the in-repo L1 precedent), extended with
///   ordered recording and per-call scripting.
/// - Holds no credential: the auth attach is the product's real code, below the seam.
final class StubClient: Client, @unchecked Sendable {
    enum Scripted {
        case response(status: HTTPResponseStatus, headers: HTTPHeaders, body: Data?)
        case failure(any Error)
    }

    let eventLoop: EventLoop
    private let lock = NSLock()
    private var _requests: [ClientRequest] = []
    private var _scripted: [Scripted] = []

    init() {
        // `EmbeddedEventLoop` is re-exported by Vapor (`Exports.swift`), so the
        // harness needs no NIO package dependency (QA-UNIT12 §9.4).
        self.eventLoop = EmbeddedEventLoop()
    }

    /// Every request sent so far, in call order. Find a request by predicate,
    /// never by `.last` — several operations issue more than one call.
    var requests: [ClientRequest] {
        lock.lock(); defer { lock.unlock() }
        return _requests
    }

    func firstRequest(where predicate: (ClientRequest) -> Bool) -> ClientRequest? {
        requests.first(where: predicate)
    }

    /// Script the response for the next un-scripted call. Per call, not per stub.
    func script(status: HTTPResponseStatus = .ok, headers: HTTPHeaders = [:], body: Data? = nil) {
        lock.lock(); defer { lock.unlock() }
        _scripted.append(.response(status: status, headers: headers, body: body))
    }

    /// Script a transport failure for the next un-scripted call.
    func scriptFailure(_ error: any Error) {
        lock.lock(); defer { lock.unlock() }
        _scripted.append(.failure(error))
    }

    func delegating(to eventLoop: EventLoop) -> Client { self }

    func send(_ request: ClientRequest) -> EventLoopFuture<ClientResponse> {
        lock.lock()
        _requests.append(request)
        let next: Scripted = _scripted.isEmpty
            ? .response(status: .ok, headers: [:], body: nil)
            : _scripted.removeFirst()
        lock.unlock()

        switch next {
        case .failure(let error):
            return eventLoop.makeFailedFuture(error)
        case .response(let status, let headers, let body):
            var buffer: ByteBuffer? = nil
            if let body {
                var b = ByteBufferAllocator().buffer(capacity: body.count)
                b.writeBytes(body)
                buffer = b
            }
            return eventLoop.makeSucceededFuture(ClientResponse(status: status, headers: headers, body: buffer))
        }
    }
}
