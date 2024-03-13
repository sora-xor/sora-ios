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
import IrohaCrypto
import SoraUIKit
import RobinHood
import SoraFoundation
import sorawallet

enum ConfirmationState: Equatable {
    case notEnoughtBalance(String)
    case readyToSubmit
    
    var title: String {
        switch self {
        case .readyToSubmit:
            return R.string.localizable.commonConfirm(preferredLanguages: .currentLocale)
        case .notEnoughtBalance(let assetSymbol):
            return R.string.localizable.polkaswapInsufficientBalance(assetSymbol, preferredLanguages: .currentLocale)
        }
    }
    
    var textColor: SoramitsuColor {
        switch self {
        case .readyToSubmit:
            return .bgSurface
        case .notEnoughtBalance:
            let disableColor = SoramitsuUI.shared.theme.palette.color(.fgPrimary).withAlphaComponent(0.04)
            return .custom(uiColor: disableColor)
        }
    }
}

protocol ConfirmSendingViewModelProtocol: AnyObject {
    func networkFeeInfoButtonTapped()
}


final class ConfirmSendingViewModel {
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    
    weak var fiatService: FiatServiceProtocol?
    weak var view: ConfirmViewProtocol?
    var wireframe: ConfirmWireframeProtocol?
    let assetManager: AssetManagerProtocol
    let detailsFactory: DetailViewModelFactoryProtocol
    let debouncer = Debouncer(interval: 0.8)
    var items: [SoramitsuTableViewItemProtocol] = []
    
    private var confirmationState: ConfirmationState = .readyToSubmit {
        didSet {
            updateContent()
            Task { [weak self] in
                let fiatDate = await self?.fiatService?.getFiat() ?? []
                self?.updateContent(with: fiatDate)
            }
        }
    }
    
    var firstAssetBalance: BalanceData = BalanceData(identifier: WalletAssetId.xor.rawValue, balance: AmountDecimal(value: 0)) {
        didSet {
            // check if balance is enough
            if firstAssetAmount > firstAssetBalance.balance.decimalValue {
                let firstAssetSymbol = assetManager.assetInfo(for: assetId)?.symbol ?? ""
                confirmationState = .notEnoughtBalance(firstAssetSymbol)
                return
            }

            // check if exchanging from XOR, and have not enough XOR to pay the fee
            if let fromAsset = assetManager.assetInfo(for: assetId),
               fromAsset.isFeeAsset,
               firstAssetAmount + fee > firstAssetBalance.balance.decimalValue {
                let firstAssetSymbol = assetManager.assetInfo(for: assetId)?.symbol ?? ""
                confirmationState = .notEnoughtBalance(firstAssetSymbol)
                return
            }

            if let feeAssetBalance = assetsProvider?.getBalances(with: [.xor]).first,
               fee > feeAssetBalance.balance.decimalValue {
                let feeAssetSymbol = assetManager.assetInfo(for: .xor)?.symbol ?? ""
                confirmationState = .notEnoughtBalance(feeAssetSymbol)
                return
            }
            
            confirmationState = .readyToSubmit
        }
    }
    
    let assetId: String
    let recipientAddress: String
    var firstAssetAmount: Decimal
    var details: [DetailViewModel] = []
    let transactionType: TransactionType
    let fee: Decimal
    let walletService: WalletServiceProtocol
    private weak var assetsProvider: AssetProviderProtocol?
    
    var title: String? {
        return R.string.localizable.confirmSending(preferredLanguages: .currentLocale)
    }
    
    var imageName: String? {
        return nil
    }
    
    init(
        wireframe: ConfirmWireframeProtocol?,
        fiatService: FiatServiceProtocol,
        assetManager: AssetManagerProtocol,
        detailsFactory: DetailViewModelFactoryProtocol,
        assetId: String,
        recipientAddress: String,
        firstAssetAmount: Decimal,
        transactionType: TransactionType,
        fee: Decimal,
        walletService: WalletServiceProtocol,
        assetsProvider: AssetProviderProtocol?
    ) {
        self.assetId = assetId
        self.recipientAddress = recipientAddress
        self.fiatService = fiatService
        self.wireframe = wireframe
        self.assetManager = assetManager
        self.detailsFactory = detailsFactory
        self.assetsProvider = assetsProvider
        self.firstAssetAmount = firstAssetAmount
        self.transactionType = transactionType
        self.fee = fee
        self.walletService = walletService
        self.assetsProvider = assetsProvider
    }
    
    private func updateBalanceData() {
        if !assetId.isEmpty, let balance = assetsProvider?.getBalances(with: [assetId]).first {
            firstAssetBalance = balance
        }
    }
    
}

extension ConfirmSendingViewModel: ConfirmViewModelProtocol {
    func viewDidLoad() {
        updateBalanceData()
        assetsProvider?.add(observer: self)
    }
}

extension ConfirmSendingViewModel: ConfirmSendingViewModelProtocol {
    func networkFeeInfoButtonTapped() {
        wireframe?.present(
            message: R.string.localizable.polkaswapNetworkFeeInfo(preferredLanguages: .currentLocale),
            title: R.string.localizable.networkFee(preferredLanguages: .currentLocale),
            closeAction: R.string.localizable.commonOk(preferredLanguages: .currentLocale),
            from: view
        )
    }
}

extension ConfirmSendingViewModel: AssetProviderObserverProtocol {
    func processBalance(data: [BalanceData]) {
        updateBalanceData()
    }
}

extension ConfirmSendingViewModel {
    func updateContent(with fiatData: [FiatData] = []) {
        
        let addressItem = RecipientAddressItem(address: self.recipientAddress)
        
        let firstAsset = self.assetManager.assetInfo(for: self.assetId)
        let firstAssetPrecision = firstAsset?.precision ?? 0
        let firstAssetFormatter: NumberFormatter = NumberFormatter.inputedAmoutFormatter(with: firstAssetPrecision)
        
        let sendAssetItem = SendAssetItem(imageViewModel: WalletSvgImageViewModel(svgString: firstAsset?.icon ?? ""),
                                          symbol: firstAsset?.symbol ?? "",
                                          amount: firstAssetFormatter.stringFromDecimal(self.firstAssetAmount) ?? "",
                                          balance: self.setupFullBalanceText(from: self.firstAssetBalance, fiatData: fiatData),
                                          fiat: self.setupFiatText(from: self.firstAssetAmount, assetId: self.assetId, fiatData: fiatData))
        
        let details = self.detailsFactory.createSendingAssetViewModels(fee: self.fee, fiatData: fiatData, viewModel: self)
        let detailItem = ConfirmDetailsItem(detailViewModels: details)
        
        let buttonText = SoramitsuTextItem(text: self.confirmationState.title,
                                           fontData: FontType.buttonM,
                                           textColor: self.confirmationState.textColor,
                                           alignment: .center)
        let buttonItem = SoramitsuButtonItem(title: buttonText, isEnable: self.confirmationState == .readyToSubmit) { [weak self] in
            self?.submit()
        }
        
        self.items = [addressItem,
                      SoramitsuTableViewSpacerItem(space: 16, color: .custom(uiColor: .clear)),
                      sendAssetItem,
                      SoramitsuTableViewSpacerItem(space: 16, color: .custom(uiColor: .clear)),
                      detailItem,
                      SoramitsuTableViewSpacerItem(space: 16, color: .custom(uiColor: .clear)),
                      buttonItem]
        self.setupItems?(self.items)
    }
    
    func submit() {
        let networkFeeDescription = FeeDescription(identifier: WalletAssetId.xor.rawValue,
                                                   assetId: WalletAssetId.xor.rawValue,
                                                   type: "fee",
                                                   parameters: [],
                                                   accountId: nil,
                                                   minValue: nil,
                                                   maxValue: nil,
                                                   context: nil)
        let networkFee = Fee(
            value: AmountDecimal(value: fee),
            feeDescription: networkFeeDescription
        )
        
        guard let selectedAccount = SelectedWalletSettings.shared.currentAccount else { return }
        let accountId = try? SS58AddressFactory().accountId(fromAddress: selectedAccount.address, type: selectedAccount.addressType).toHex()
        let destinationAccountId = try? SS58AddressFactory().accountId(fromAddress: recipientAddress, type: selectedAccount.addressType).toHex()
        
        let info = TransferInfo(source: accountId ?? "",
                                destination: destinationAccountId ?? "",
                                amount: AmountDecimal(value: firstAssetAmount),
                                asset: assetId,
                                details: "",
                                fees: [networkFee],
                                context: [:])
        
        wireframe?.showActivityIndicator()
        walletService.transfer(info: info, runCompletionIn: .main) { [weak self] (optionalResult) in
            self?.wireframe?.hideActivityIndicator()
            
            if let result = optionalResult {
                self?.handleTransfer(result: result)
            }
        }
    }
    
    private func handleTransfer(result: Result<Data, Swift.Error>) {
        var status: TransactionBase.Status = .pending
        var txHash = ""
        if case .failure = result {
            status = .failed
        }
        if case let .success(hex) = result {
            txHash = hex.toHex(includePrefix: true)
        }
        let base = TransactionBase(txHash: txHash,
                                   blockHash: "",
                                   fee: Amount(value: fee * pow(10, 18)),
                                   status: status,
                                   timestamp: "\(Date().timeIntervalSince1970)")
        let transaction = TransferTransaction(base: base,
                                                  amount: Amount(value: firstAssetAmount),
                                                  peer: recipientAddress,
                                                  transferType: .outcoming,
                                                  tokenId: assetId)
        EventCenter.shared.notify(with: NewTransactionCreatedEvent(item: transaction))
        wireframe?.showActivityDetails(on: view?.controller, model: transaction, assetManager: assetManager) { [weak self] in
            self?.view?.dismiss(competion: {})
        }
    }
    
    func setupFullBalanceText(from balanceData: BalanceData, fiatData: [FiatData]) -> String {
        let balance = NumberFormatter.polkaswapBalance.stringFromDecimal(balanceData.balance.decimalValue) ?? ""
        var fiatBalanceText = ""
        
        if let usdPrice = fiatData.first(where: { $0.id == balanceData.identifier })?.priceUsd?.decimalValue {
            let fiatDecimal = balanceData.balance.decimalValue * usdPrice
            fiatBalanceText = "$" + (NumberFormatter.fiat.stringFromDecimal(fiatDecimal) ?? "")
        }

        return fiatBalanceText.isEmpty ? "\(balance)" : "\(balance) (\(fiatBalanceText))"
    }
    
    func setupFiatText(from amount: Decimal, assetId: String, fiatData: [FiatData]) -> String {
        guard let asset = assetManager.assetInfo(for: assetId) else { return "" }
        
        var fiatText = ""
        
        if let usdPrice = fiatData.first(where: { $0.id == asset.assetId })?.priceUsd?.decimalValue {
            let fiatDecimal = amount * usdPrice
            fiatText = "$" + (NumberFormatter.fiat.stringFromDecimal(fiatDecimal) ?? "")
        }
        
        return fiatText
    }
}
