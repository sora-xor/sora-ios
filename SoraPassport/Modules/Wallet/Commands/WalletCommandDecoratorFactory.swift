/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CoreData
import CommonWallet
import RobinHood
import SoraFoundation

final class WalletCommandDecoratorFactory: WalletCommandDecoratorFactoryProtocol {
    let ethereumAssetId: String
    let xorAssetId: String
    let ethereumAddress: String
    let xorAddress: String
    let valAssetId: String
    let valAddress: String
    let dataProvider: StreamableProvider<EthereumInit>
    let repository: AnyDataProviderRepository<EthereumInit>
    let localizationManager: LocalizationManagerProtocol
    let operationManager: OperationManagerProtocol
    let amountFormatter: LocalizableResource<TokenAmountFormatter>
    let logger: LoggerProtocol

    init(xorAssetId: String,
         valAssetId: String,
         ethereumAssetId: String,
         ethereumAddress: String,
         xorAddress: String,
         valAddress: String,
         dataProvider: StreamableProvider<EthereumInit>,
         repository: AnyDataProviderRepository<EthereumInit>,
         localizationManager: LocalizationManagerProtocol,
         operationManager: OperationManagerProtocol,
         amountFormatter: LocalizableResource<TokenAmountFormatter>,
         logger: LoggerProtocol) {
        self.xorAssetId = xorAssetId
        self.ethereumAssetId = ethereumAssetId
        self.ethereumAddress = ethereumAddress
        self.xorAddress = xorAddress
        self.valAssetId = valAssetId
        self.valAddress = valAddress
        self.dataProvider = dataProvider
        self.repository = repository
        self.localizationManager = localizationManager
        self.operationManager = operationManager
        self.amountFormatter = amountFormatter
        self.logger = logger
    }

    func createAssetDetailsDecorator(with commandFactory: WalletCommandFactoryProtocol,
                                     asset: WalletAsset,
                                     balanceData: BalanceData?) -> WalletCommandDecoratorProtocol? {
        do {
            if asset.identifier == ethereumAssetId {
                return try createEthAssetDecorator(with: commandFactory,
                                                   asset: asset,
                                                   balanceData: balanceData)
            } else {
                return try createXorAssetDecorator(with: commandFactory,
                                                   asset: asset,
                                                   balanceData: balanceData)
            }
        } catch {
            logger.error("Can't create asset command decorator: \(error)")
            return nil
        }
    }

    // MARK: Private

    private func createEthAssetDecorator(with commandFactory: WalletCommandFactoryProtocol,
                                         asset: WalletAsset,
                                         balanceData: BalanceData?) throws -> WalletCommandDecoratorProtocol? {
        return EthereumAssetDetailsCommand(commandFactory: commandFactory,
                                           dataProvider: dataProvider,
                                           repository: repository,
                                           operationManager: operationManager,
                                           localizationManager: localizationManager,
                                           address: ethereumAddress)
    }

    private func createXorAssetDecorator(with commandFactory: WalletCommandFactoryProtocol,
                                         asset: WalletAsset,
                                         balanceData: BalanceData?) throws -> WalletCommandDecoratorProtocol? {
        guard let balanceData = balanceData else {
            return nil
        }
        
        return XorAssetDetailsCommand(commandFactory: commandFactory,
                                        dataProvider: dataProvider,
                                        repository: repository,
                                        operationManager: operationManager,
                                        localizationManager: localizationManager,
                                        address: ethereumAddress,
                                        xorAddress: valAddress,
                                        balance: balanceData,
                                        tokenFormatter: amountFormatter)
    }
}
