import Vapor
@testable import SwiftlyFeedbackKitVapor

/// The one place in the target that knows how to construct a Vapor `Application`
/// (QA-UNIT12 §14.2, §18). Used by exactly the two host-extension suites.
///
/// The `Application` is deliberately bare: no `configure`, no Fluent in the
/// dependency graph, no route, no `run()` — which is what keeps those tests L1.
/// It must never gain a database or a route.
func withTestApp(_ body: (Application) async throws -> Void) async throws {
    let app = try await Application.make(.testing)
    do {
        try await body(app)
    } catch {
        try? await app.asyncShutdown()
        throw error
    }
    try await app.asyncShutdown()
}
