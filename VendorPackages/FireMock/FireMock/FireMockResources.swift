import Foundation

enum FireMockResources {
    static var bundle: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        return Bundle(for: FireMockViewController.self)
        #endif
    }
}
