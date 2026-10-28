//
//  CommonWalletContext.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 3/12/24.
//  Copyright © 2024 Soramitsu. All rights reserved.
//

import Foundation
import UIKit

public protocol WalletCommandFactoryProtocol: AnyObject {
    func prepareAccountUpdateCommand() -> WalletCommandProtocol
    func prepareLanguageSwitchCommand(with newLanguage: WalletLanguage) -> WalletCommandProtocol
}

public protocol CommonWalletContextProtocol: WalletCommandFactoryProtocol {
    var networkOperationFactory: WalletNetworkOperationFactoryProtocol { get }
}
