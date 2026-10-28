//
//  CommonWalletBuilder.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 3/12/24.
//  Copyright © 2024 Soramitsu. All rights reserved.
//

import UIKit
import SoraFoundation

public protocol CommonWalletBuilderProtocol: AnyObject {
    static func builder(with account: WalletAccountSettingsProtocol,
                        networkOperationFactory: WalletNetworkOperationFactoryProtocol)
        -> CommonWalletBuilderProtocol

    @discardableResult
    func with(localizationManager: LocalizationManagerProtocol) -> Self
    
    func build() throws -> CommonWalletContextProtocol
}

public enum CommonWalletBuilderError: Error {
    case moduleCreationFailed
}

public final class CommonWalletBuilder {
    fileprivate var account: WalletAccountSettingsProtocol
    fileprivate var networkOperationFactory: WalletNetworkOperationFactoryProtocol
    fileprivate var statusDateFormatter: LocalizableResource<DateFormatter>?
    fileprivate var transferDescriptionLimit: UInt8 = 64
    fileprivate var language: WalletLanguage = .english
    fileprivate var localizationManager: LocalizationManagerProtocol?

    init(account: WalletAccountSettingsProtocol, networkOperationFactory: WalletNetworkOperationFactoryProtocol) {
        self.account = account
        self.networkOperationFactory = networkOperationFactory
    }
}

extension CommonWalletBuilder: CommonWalletBuilderProtocol {

    public static func builder(with account: WalletAccountSettingsProtocol,
                               networkOperationFactory: WalletNetworkOperationFactoryProtocol)
        -> CommonWalletBuilderProtocol {
        return CommonWalletBuilder(account: account, networkOperationFactory: networkOperationFactory)
    }

    public func with(localizationManager: LocalizationManagerProtocol) -> Self {
        self.localizationManager = localizationManager
        return self
    }

    public func build() throws -> CommonWalletContextProtocol {
        let resolver = Resolver(
            account: account,
            networkOperationFactory: networkOperationFactory
        )

        if let statusDateFormatter = statusDateFormatter {
            resolver.statusDateFormatter = statusDateFormatter
        }

        let allLanguages: [String] = WalletLanguage.allCases.map { $0.rawValue }
        resolver.localizationManager = self.localizationManager ?? LocalizationManager(localization: language.rawValue,
                                                           availableLocalizations: allLanguages)

        return resolver
    }
}
