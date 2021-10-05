import Foundation
import FearlessUtils

struct EventCodingPath: Equatable {
    let moduleName: String
    let eventName: String

    init(moduleName: String, eventName: String) {
        self.moduleName = moduleName
        self.eventName = eventName
    }
}

extension EventCodingPath {
    static var extrinsicSuccess: EventCodingPath {
        EventCodingPath(moduleName: "System", eventName: "ExtrinsicSuccess")
    }

    static var extrinsicFailed: EventCodingPath {
        EventCodingPath(moduleName: "System", eventName: "ExtrinsicFailed")
    }

    static var balanceDeposit: EventCodingPath {
        EventCodingPath(moduleName: "Balances", eventName: "Deposit")
    }

    static var feeWitdrawn: EventCodingPath {
        EventCodingPath(moduleName: "XorFee", eventName: "FeeWithdrawn")
    }
}
