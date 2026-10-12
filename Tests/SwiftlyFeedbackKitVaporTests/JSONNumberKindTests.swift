import Foundation
import Testing

@Test func jsonOneIsNotABoolean() throws {
    let data = Data(#"{"yes":true,"one":1,"frac":1.5}"#.utf8)
    let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

    #expect(JSONNumberKind.isBoolean(try #require(object["yes"] as? NSNumber)))
    #expect(!JSONNumberKind.isBoolean(try #require(object["one"] as? NSNumber)))
    #expect(JSONNumberKind.isFloat(try #require(object["frac"] as? NSNumber)))
    #expect(!JSONNumberKind.isFloat(try #require(object["one"] as? NSNumber)))
}
