// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
import SoraUIKit

import RobinHood
import sorawallet

struct AssetDetailsData {
    let priceInfo: PriceInfo
    let referralBalance: Decimal?
}

protocol AssetDetailsViewModelProtocol {
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)? { get set }
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)? { get set }
    func viewDidLoad()
}

final class AssetDetailsViewModel {
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
 
    weak var view: AssetDetailsViewProtocol?

    private let assetInfo: AssetInfo
    private let wireframe: AssetDetailsWireframeProtocol
    private let appEventService = AppEventService()
    private let referralFactory: ReferralsOperationFactoryProtocol
    private let priceInfoService: PriceInfoServiceProtocol
    private let itemsFactory: AssetDetailsItemFactory
    private var task: Task<Void, Swift.Error>?
    private var activityItem: SoramitsuTableViewItemProtocol?
    private var pricesObserver: NSObjectProtocol?

    deinit {
        if let pricesObserver {
            NotificationCenter.default.removeObserver(pricesObserver)
        }
    }

    init(
        wireframe: AssetDetailsWireframeProtocol,
        assetInfo: AssetInfo,
        referralFactory: ReferralsOperationFactoryProtocol,
        priceInfoService: PriceInfoServiceProtocol,
        itemsFactory: AssetDetailsItemFactory
    ) {
        self.assetInfo = assetInfo
        self.wireframe = wireframe
        self.referralFactory = referralFactory
        self.priceInfoService = priceInfoService
        self.itemsFactory = itemsFactory
    }
    
    /// - Parameter pricesLoaded: The price read has finished. Before that
    ///   the screen is drawn from balances alone and the price is left
    ///   blank; after it, an asset without a price reads "Price
    ///   unavailable". An unknown price is never shown as "$0".
    func createItems(with data: AssetDetailsData, pricesLoaded: Bool = true) {
        var items: [SoramitsuTableViewItemProtocol] = []
        
        let priceInfo = data.priceInfo
        let usdPrice = priceInfo.fiatData.first(where: { $0.id == assetInfo.assetId })?.priceUsd?.decimalValue
        
        let priceItem = itemsFactory.createPriceItem(with: assetInfo,
                                                     usdPrice: usdPrice,
                                                     priceInfo: priceInfo,
                                                     pricesLoaded: pricesLoaded)
        items.append(priceItem)
        items.append(SoramitsuTableViewSpacerItem(space: 16, color: .custom(uiColor: .clear)))
        
        let referralBalance = data.referralBalance
        let transferableItem = itemsFactory.createTranferableItem(with: assetInfo,
                                                                  usdPrice: usdPrice,
                                                                  referralBalance: referralBalance,
                                                                  wireframe: wireframe) { [weak self] balanceContext in
            self?.showFrozenDetails(with: usdPrice, balanceContext: balanceContext, referralBalance: referralBalance)
        }
        items.append(transferableItem)

        if let poolsItem = itemsFactory.createPooledItem(with: assetInfo, fiatData: priceInfo.fiatData) {
            items.append(SoramitsuTableViewSpacerItem(space: 16, color: .custom(uiColor: .clear)))
            items.append(poolsItem)
        }
        
        // Built once: the screen is drawn again when prices arrive, and
        // that must not read the activity a second time.
        let activityItem = self.activityItem ?? itemsFactory.createRecentActivity(with: assetInfo.assetId) { [weak self] item in
            self?.reloadItems?([ item ])
        }
        self.activityItem = activityItem
        items.append(activityItem)

        let assetIdItem = AssetIdItem(assetId: assetInfo.assetId, tapHandler: self.showAppEvent)
        items.append(SoramitsuTableViewSpacerItem(space: 16, color: .custom(uiColor: .clear)))
        items.append(assetIdItem)

        setupItems?(items)
    }
}

extension AssetDetailsViewModel: AssetDetailsViewModelProtocol {
    func viewDidLoad() {
        // Balance, Send, Receive and Swap do not depend on PI: show them
        // at once and fill the prices in when they arrive.
        createItems(
            with: AssetDetailsData(
                priceInfo: PriceInfo(fiatData: [], marketCapInfo: []),
                referralBalance: nil
            ),
            pricesLoaded: false
        )
        loadPrices()
        if pricesObserver == nil {
            // Prices were refreshed, or became available: ask again.
            pricesObserver = NotificationCenter.default.addObserver(
                forName: PICatalogs.pricesDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.loadPrices()
            }
        }
    }

    private func loadPrices() {
        task?.cancel()
        task = Task { [weak self] in
            guard let data = await self?.fetchData(), !Task.isCancelled else { return }
            self?.createItems(with: data)
        }
    }
}

private extension AssetDetailsViewModel {
    
    func fetchData() async -> AssetDetailsData  {
        async let priceInfo = priceInfoService.getPriceInfo(for: [assetInfo.identifier])
        async let referralBalance = assetInfo.isFeeAsset ? getReferralBalance() : nil
        return await AssetDetailsData(priceInfo: priceInfo, referralBalance: referralBalance)
    }
    
    func getReferralBalance() async -> Decimal? {
        return await withCheckedContinuation { continuation in
            guard let operation = referralFactory.createReferrerBalancesOperation() else {
                continuation.resume(returning: nil)
                return
            }
            operation.completionBlock = {
                do {
                    guard let data = try operation.extractResultData()?.underlyingValue else {
                        continuation.resume(returning: nil)
                        return
                    }
                    let referralBalance = Decimal.fromSubstrateAmount(data.value, precision: 18) ?? Decimal(0)
                    continuation.resume(returning: referralBalance)
                } catch {
                    Logger.shared.error("Request unsuccessful")
                    continuation.resume(returning: nil)
                }
            }
            OperationManagerFacade.sharedManager.enqueue(operations: [operation], in: .transient)
        }
    }

    func showAppEvent() {
        let title = NSAttributedString(string: R.string.localizable.assetDetailsAssetIdCopied(preferredLanguages: .currentLocale))
        let viewModel = AppEventViewController.ViewModel(title: title)
        let appEventController = AppEventViewController(style: .custom(viewModel))
        appEventService.showToasterIfNeeded(viewController: appEventController)
        UIPasteboard.general.string = assetInfo.assetId
    }
    
    func balanceDetailViewModel(title: String, amount: String, fiatAmount: String, type: BalanceDetailType = .body) -> BalanceDetailViewModel {
        let frozenTitleText = SoramitsuTextItem(text: title,
                                                fontData: type.titleFont,
                                                textColor: type.titleColor,
                                                alignment: .left)
        
        let frozenAmountText = SoramitsuTextItem(text: amount,
                                                 fontData: type.amountFont,
                                                 textColor: .fgPrimary,
                                                 alignment: .right)
        
        let frozenFiatText = SoramitsuTextItem(text: fiatAmount,
                                               fontData: type.fiatAmountFont,
                                               textColor: .fgSecondary,
                                               alignment: .right)
        return BalanceDetailViewModel(title: frozenTitleText, amount: frozenAmountText, fiatAmount: frozenFiatText)
    }
    
    func showFrozenDetails(with usdPrice: Decimal?, balanceContext: BalanceContext?, referralBalance: Decimal?) {
        let decimalsDetails: [Decimal] = [
            (balanceContext?.frozen ?? Decimal(0)) + (referralBalance ?? Decimal(0)),
            balanceContext?.locked ?? Decimal(0),
            referralBalance ?? Decimal(0),
            balanceContext?.reserved ?? Decimal(0),
            balanceContext?.redeemable ?? Decimal(0),
            balanceContext?.unbonding ?? Decimal(0)
        ]
        
        let amountDetails = decimalsDetails.compactMap { Amount(value: $0) }
        let fiatDetails = amountDetails.map { WalletUX.fiatText(amount: $0.decimalValue, price: usdPrice) }
        
        let models = FrozenDetailType.allCases.map { type in
            balanceDetailViewModel(title: type.title,
                                   amount: amountDetails[type.rawValue].stringValue + " " + assetInfo.symbol,
                                   fiatAmount: fiatDetails[type.rawValue],
                                   type: type == .frozen ? .header : .body)
        }
        
        wireframe.showFrozenBalance(frozenDetailViewModels: models)
    }
}
