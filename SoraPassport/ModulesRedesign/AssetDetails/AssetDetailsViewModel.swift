// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import UIKit
import SCard
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
    
    func createItems(with data: AssetDetailsData) {
        var items: [SoramitsuTableViewItemProtocol] = []
        
        let priceInfo = data.priceInfo
        let usdPrice = priceInfo.fiatData.first(where: { $0.id == assetInfo.assetId })?.priceUsd?.decimalValue ?? Decimal(0)
        
        let priceItem = itemsFactory.createPriceItem(with: assetInfo, usdPrice: usdPrice, priceInfo: priceInfo)
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
        
        let activityItem = itemsFactory.createRecentActivity(with: assetInfo.assetId) { [weak self] item in
            self?.reloadItems?([ item ])
        }
        items.append(activityItem)

        let assetIdItem = AssetIdItem(assetId: assetInfo.assetId, tapHandler: self.showAppEvent)
        items.append(SoramitsuTableViewSpacerItem(space: 16, color: .custom(uiColor: .clear)))
        items.append(assetIdItem)

        setupItems?(items)
    }
}

extension AssetDetailsViewModel: AssetDetailsViewModelProtocol {
    func viewDidLoad() {
        task?.cancel()
        task = Task { [weak self] in
            guard let data = await self?.fetchData() else { return }
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
            guard let operation = referralFactory.createReferrerBalancesOperation() else { return }
            operation.completionBlock = {
                do {
                    guard let data = try operation.extractResultData()?.underlyingValue else {
                        continuation.resume(with: .success(nil))
                        return
                    }
                    let referralBalance = Decimal.fromSubstrateAmount(data.value, precision: 18) ?? Decimal(0)
                    continuation.resume(with: .success(referralBalance))
                } catch {
                    Logger.shared.error("Request unsuccessful")
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
        
        let frozenFiatText = SoramitsuTextItem(text: "$" + fiatAmount,
                                               fontData: type.fiatAmountFont,
                                               textColor: .fgSecondary,
                                               alignment: .right)
        return BalanceDetailViewModel(title: frozenTitleText, amount: frozenAmountText, fiatAmount: frozenFiatText)
    }
    
    func showFrozenDetails(with usdPrice: Decimal, balanceContext: BalanceContext?, referralBalance: Decimal?) {
        let decimalsDetails: [Decimal] = [
            (balanceContext?.frozen ?? Decimal(0)) + (referralBalance ?? Decimal(0)),
            balanceContext?.locked ?? Decimal(0),
            referralBalance ?? Decimal(0),
            balanceContext?.reserved ?? Decimal(0),
            balanceContext?.redeemable ?? Decimal(0),
            balanceContext?.unbonding ?? Decimal(0)
        ]
        
        let amountDetails = decimalsDetails.compactMap { Amount(value: $0) }
        let fiatDetails = amountDetails.compactMap { NumberFormatter.fiat.stringFromDecimal($0.decimalValue * usdPrice) }
        
        let models = FrozenDetailType.allCases.map { type in
            balanceDetailViewModel(title: type.title,
                                   amount: amountDetails[type.rawValue].stringValue + " " + assetInfo.symbol,
                                   fiatAmount: fiatDetails[type.rawValue],
                                   type: type == .frozen ? .header : .body)
        }
        
        wireframe.showFrozenBalance(frozenDetailViewModels: models)
    }
}
