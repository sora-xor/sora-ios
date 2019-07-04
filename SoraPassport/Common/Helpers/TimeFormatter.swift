/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

protocol TimeFormatterProtocol: class {
    func string(from timeInterval: TimeInterval) throws -> String
}

final class TimeFormatter: TimeFormatterProtocol {
    func string(from timeInterval: TimeInterval) throws -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60

        let minutesString = minutes < 10 ? "0\(minutes)" : String(minutes)
        let secondsString = seconds < 10 ? "0\(seconds)" : String(seconds)

        return "\(minutesString):\(secondsString)"
    }
}
