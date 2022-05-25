import Foundation

struct CallCodingPath: Equatable, Codable {
    let moduleName: String
    let callName: String
}

extension CallCodingPath {
    static var transfer: CallCodingPath {
        CallCodingPath(moduleName: "Assets", callName: "transfer")
    }

    static var transferKeepAlive: CallCodingPath {
        CallCodingPath(moduleName: "Assets", callName: "transfer_keep_alive")
    }

    static var swap: CallCodingPath {
        CallCodingPath(moduleName: "LiquidityProxy", callName: "swap")
    }

    var isTransfer: Bool {
        [.transfer, .transferKeepAlive].contains(self)
    }

    var isSwap: Bool {
        [.swap].contains(self)
    }
}
