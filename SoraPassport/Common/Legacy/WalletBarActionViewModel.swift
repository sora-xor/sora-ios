/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/


import Foundation
import UIKit

public enum WalletBarActionDisplayType {
    case title(_ title: String)
    case icon(_ image: UIImage)
}

public protocol WalletBarActionViewModelProtocol {
    var displayType: WalletBarActionDisplayType { get }
    var command: WalletCommandProtocol { get }
}

public struct WalletBarActionViewModel: WalletBarActionViewModelProtocol {
    public let displayType: WalletBarActionDisplayType
    public let command: WalletCommandProtocol

    public init(displayType: WalletBarActionDisplayType, command: WalletCommandProtocol) {
        self.displayType = displayType
        self.command = command
    }
}
