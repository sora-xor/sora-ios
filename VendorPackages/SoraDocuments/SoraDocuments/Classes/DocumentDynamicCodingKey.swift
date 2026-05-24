/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public struct DocumentDynamicCodingKey: CodingKey {
    public var stringValue: String

    public init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = Int(stringValue)
    }

    public var intValue: Int?

    public init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = String(intValue)
    }
}
