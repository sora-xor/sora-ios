import Foundation

extension Result where Success == Void {
    static var success: Result { .success(()) }
}
