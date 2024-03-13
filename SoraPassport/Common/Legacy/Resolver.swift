//
//  Resolver.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 3/12/24.
//  Copyright © 2024 Soramitsu. All rights reserved.
//

import Foundation
import SoraFoundation

public protocol WalletLoggerProtocol {
    func verbose(message: String, file: String, function: String, line: Int)
    func debug(message: String, file: String, function: String, line: Int)
    func info(message: String, file: String, function: String, line: Int)
    func warning(message: String, file: String, function: String, line: Int)
    func error(message: String, file: String, function: String, line: Int)
}

protocol ResolverProtocol: AnyObject {
    var account: WalletAccountSettingsProtocol { get }
    var networkOperationFactory: WalletNetworkOperationFactoryProtocol { get }
    var eventCenter: WalletEventCenterProtocol { get }
    var navigation: NavigationProtocol? { get }
    var logger: WalletLoggerProtocol? { get }
    var localizationManager: LocalizationManagerProtocol? { get }
    var statusDateFormatter: LocalizableResource<DateFormatter> { get }
    var commandFactory: WalletCommandFactoryProtocol { get }
}

final class Resolver: ResolverProtocol, CommonWalletContextProtocol, WalletCommandFactoryProtocol {
    var account: WalletAccountSettingsProtocol
    var networkOperationFactory: WalletNetworkOperationFactoryProtocol
    var navigation: NavigationProtocol?

    lazy var eventCenter: WalletEventCenterProtocol = WalletEventCenter()

    lazy var statusDateFormatter: LocalizableResource<DateFormatter> = DateFormatter.statusDateFormatter.localizableResource()

    var logger: WalletLoggerProtocol?

    var localizationManager: LocalizationManagerProtocol?

    var commandFactory: WalletCommandFactoryProtocol { return self }

    init(
        account: WalletAccountSettingsProtocol,
        networkOperationFactory: WalletNetworkOperationFactoryProtocol
    ) {
        self.account = account
        self.networkOperationFactory = networkOperationFactory
    }
    
    func prepareAccountUpdateCommand() -> WalletCommandProtocol {
        return AccountUpdateCommand(resolver: self)
    }

    func prepareLanguageSwitchCommand(with newLanguage: WalletLanguage) -> WalletCommandProtocol {
        return LanguageSwitchCommand(resolver: self, language: newLanguage)
    }
}
