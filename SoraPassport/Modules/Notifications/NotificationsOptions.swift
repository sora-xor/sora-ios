/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

struct NotificationsOptions: OptionSet {
    typealias RawValue = UInt8

    static var alert: NotificationsOptions { return NotificationsOptions(rawValue: 1 << 0) }
    static var badge: NotificationsOptions { return NotificationsOptions(rawValue: 1 << 1) }
    static var sound: NotificationsOptions { return NotificationsOptions(rawValue: 1 << 2) }

    private(set) var rawValue: UInt8

    init(rawValue: NotificationsOptions.RawValue) {
        self.rawValue = rawValue
    }

    mutating func formUnion(_ other: NotificationsOptions) {
        rawValue |= other.rawValue
    }

    mutating func formIntersection(_ other: NotificationsOptions) {
        rawValue &= other.rawValue
    }

    mutating func formSymmetricDifference(_ other: NotificationsOptions) {
        rawValue ^= other.rawValue
    }
}
