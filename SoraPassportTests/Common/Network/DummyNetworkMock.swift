import Foundation
import FireMock

struct DummyNetworkMock: FireMockProtocol {
    var afterTime: TimeInterval
    var statusCode: Int
    var responseFilename: String

    init() {
        self.init(delay: 1.0)
    }

    init(delay: TimeInterval) {
        self.init(delay: delay, statusCode: 200)
    }

    init(delay: TimeInterval, statusCode: Int) {
        self.init(delay: delay, statusCode: statusCode, responseFilename: "emptyResponse.json")
    }

    init(delay: TimeInterval, statusCode: Int, responseFilename: String) {
        self.afterTime = delay
        self.statusCode = statusCode
        self.responseFilename = responseFilename
    }


    func mockFile() -> String {
        return responseFilename
    }
}
