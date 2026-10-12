import Foundation
#if canImport(Darwin)
import CoreFoundation
#endif

/// JSON boolean vs number after `JSONSerialization`.
/// The server test target cannot share this file, so the rule is copied and
/// locked by `JSONNumberKindTests` in this package.
enum JSONNumberKind {
    static func isBoolean(_ number: NSNumber) -> Bool {
        #if canImport(Darwin)
        return CFGetTypeID(number) == CFBooleanGetTypeID()
        #else
        return type(of: number) != NSNumber.self
            && String(cString: number.objCType) == "c"
        #endif
    }

    static func isFloat(_ number: NSNumber) -> Bool {
        #if canImport(Darwin)
        return CFNumberIsFloatType(number)
        #else
        let code = String(cString: number.objCType)
        return code == "d" || code == "f"
        #endif
    }
}
