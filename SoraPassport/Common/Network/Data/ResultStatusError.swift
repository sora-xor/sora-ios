import Foundation

struct ResultStatusError: Error {
    var code: String
    var message: String

    init(statusData: StatusData) {
        code = statusData.code
        message = statusData.message
    }
}
