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
import IrohaCrypto
import SoraUIKit

import RobinHood
import SoraFoundation
import sorawallet

protocol InputAssetAmountViewModelProtocol: InputAccessoryViewDelegate {
    var inputedFirstAmount: Decimal { get set }
    func viewDidLoad()
    func choiceBaseAssetButtonTapped()
    func reviewButtonTapped()
    func selectAddress()
}

final class InputAssetAmountViewModel {
    
    weak var fiatService: FiatServiceProtocol?
    weak var view: InputAssetAmountViewProtocol?
    let assetManager: AssetManagerProtocol?
    let networkFacade: WalletNetworkOperationFactoryProtocol?
    var providerFactory: BalanceProviderFactory
    
    var firstAssetBalance: BalanceData = BalanceData(identifier: WalletAssetId.xor.rawValue, balance: AmountDecimal(value: 0)) {
        didSet {
            showFirstAssetBalance()
        }
    }

    /// The balance of the asset to send could not be read. While this is
    /// so, `firstAssetBalance` carries no information (it is a placeholder
    /// or the value of an earlier read): the screen says "Balance
    /// unavailable", nothing is checked against it and the amount cannot be
    /// reviewed.
    private(set) var firstAssetBalanceUnavailable = false
    /// Whether a needed balance was unavailable when the line under the
    /// amount and the button were last worked out.
    private var validatedWithNeededBalanceUnavailable = false
    
    var firstAssetId: String = "" {
        didSet {
            guard let asset = assetManager?.assetInfo(for: firstAssetId) else {
                return
            }
            let image = RemoteSerializer.shared.image(with: asset.icon ?? "")
            view?.updateFirstAsset(symbol: asset.symbol, image: image)
            updateBalanceData()
            view?.set(firstAmountText: "0")
            inputedFirstAmount = 0
        }
    }
    
    var selectedAddress: String? {
        didSet {
            view?.updateRecipientView(with: selectedAddress ?? "")
            self.updateButtonState()
        }
    }

    private var isApplyingPresetAmount = false
    private var isMaximumPresetSelected = false
    
    var inputedFirstAmount: Decimal = 0 {
        didSet {
            if !isApplyingPresetAmount {
                isMaximumPresetSelected = false
            }
            if let fromAsset = assetManager?.assetInfo(for: firstAssetId), fromAsset.isFeeAsset {
                // A warning about a low balance needs a balance.
                warningViewModel?.isHidden = firstAssetBalanceUnavailable ||
                    firstAssetBalance.balance.decimalValue - inputedFirstAmount - fee > fee
            }
            
            let fiatText = setupInputedFiatText(from: inputedFirstAmount, assetId: firstAssetId)
            let text = validationText(with: fiatText, isEnoghtAssetBalance: checkBalances(), isEnoghtXorBalance: checkXorBalance())

            let amountColor: SoramitsuColor = checkBalances() && checkXorBalance() ? .fgPrimary : .statusError
            let fiatColor: SoramitsuColor = checkBalances() && checkXorBalance() ? .fgSecondary : .statusError
            let state: InputFieldState = checkBalances() && checkXorBalance() ? .focused : .fail
            
            view?.updateFirstAsset(state: state, amountColor: amountColor, fiatColor: fiatColor)
            view?.updateFirstAsset(fiatText: text)
            updateButtonState()
        }
    }
    
    private var warningViewModelFactory: WarningViewModelFactory
    private var warningViewModel: WarningViewModel? {
        didSet {
            guard let warningViewModel else { return }
            view?.updateWarinignView(model: warningViewModel)
        }
    }
    
    private let feeProvider: FeeProviderProtocol
    private var fiatData: [PIExactFiatData] = []
    private var fee: Decimal = 0 {
        didSet {
            let feeAssetSymbol = assetManager?.getAssetList()?.first { $0.isFeeAsset }?.symbol ?? ""
            warningViewModel = warningViewModelFactory.insufficientBalanceViewModel(feeAssetSymbol: feeAssetSymbol, feeAmount: fee)
            
            guard !checkXorBalance() else { return }
            
            let fiatText = setupInputedFiatText(from: inputedFirstAmount, assetId: firstAssetId)
            let text = validationText(with: fiatText, isEnoghtAssetBalance: checkBalances(), isEnoghtXorBalance: checkXorBalance())
            
            let amountColor: SoramitsuColor = checkBalances() && checkXorBalance() ? .fgPrimary : .statusError
            let fiatColor: SoramitsuColor = checkBalances() && checkXorBalance() ? .fgSecondary : .statusError
            let state: InputFieldState = checkBalances() && checkXorBalance() ? .focused : .fail
            
            self.view?.updateFirstAsset(state: state, amountColor: amountColor, fiatColor: fiatColor)
            self.view?.updateFirstAsset(fiatText: text)
            self.updateButtonState()
        }
    }
    private var selectedTokenId: String? = WalletAssetId.xor.rawValue
    private let wireframe: InputAssetAmountWireframeProtocol
    private var balances: [BalanceData] = []
    private weak var assetsProvider: AssetProviderProtocol?
    private var qrEncoder: WalletQREncoderProtocol
    private var sharingFactory: AccountShareFactoryProtocol
    private var marketCapService: MarketCapServiceProtocol
    private var pricesObservation: PIPricesObservation?
    init(
        selectedTokenId: String?,
        selectedAddress: String?,
        fiatService: FiatServiceProtocol?,
        assetManager: AssetManagerProtocol?,
        providerFactory: BalanceProviderFactory,
        networkFacade: WalletNetworkOperationFactoryProtocol?,
        wireframe: InputAssetAmountWireframeProtocol,
        assetsProvider: AssetProviderProtocol?,
        qrEncoder: WalletQREncoderProtocol,
        sharingFactory: AccountShareFactoryProtocol,
        warningViewModelFactory: WarningViewModelFactory = WarningViewModelFactory(),
        marketCapService: MarketCapServiceProtocol
    ) {
        self.selectedAddress = selectedAddress
        self.fiatService = fiatService
        self.assetManager = assetManager
        self.providerFactory = providerFactory
        self.feeProvider = FeeProvider()
        self.networkFacade = networkFacade
        self.selectedTokenId = selectedTokenId
        self.wireframe = wireframe
        self.assetsProvider = assetsProvider
        self.qrEncoder = qrEncoder
        self.sharingFactory = sharingFactory
        self.marketCapService = marketCapService
        self.warningViewModelFactory = warningViewModelFactory
    }
}

extension InputAssetAmountViewModel: InputAssetAmountViewModelProtocol {
    
    func didSelect(variant: Decimal) {
        // A share of a balance that could not be read is not an amount.
        guard !firstAssetBalanceUnavailable else { return }
        guard firstAssetBalance.balance.decimalValue > fee  else { return }
        let isFeeAsset = assetManager?.assetInfo(for: firstAssetId)?.isFeeAsset ?? false
        let value = firstAssetBalance.balance.decimalValue * variant
        isMaximumPresetSelected = variant == 1
        isApplyingPresetAmount = true
        inputedFirstAmount = isFeeAsset ? value - fee : value
        isApplyingPresetAmount = false
        let formatter = NumberFormatter.inputedAmoutFormatter(with: assetManager?.assetInfo(for: firstAssetId)?.precision ?? 0)
        view?.set(firstAmountText: formatter.stringFromDecimal(inputedFirstAmount) ?? "")
    }
    
    func viewDidLoad() {
        updateBalanceData()
        
        if let selectedAddress = selectedAddress {
            view?.updateRecipientView(with: selectedAddress)
        } else {
            changeAddress()
        }
        
        firstAssetId = selectedTokenId ?? WalletAssetId.xor.rawValue
        view?.setupButton(isEnabled: false)
        assetsProvider?.add(observer: self)
        
        loadFiat()
        // The first answer can be the catalog of an earlier day, served at
        // once while PI is read. Ask again when that read ends, so the
        // fiat value under the amount is not left at yesterday's price for
        // as long as the screen is open.
        pricesObservation = PIPricesObservation { [weak self] in
            self?.loadFiat()
        }
    }

    private func loadFiat() {
        Task { [weak self] in
            guard let self else { return }
            let fiatData = await self.fiatService?.getFiat() ?? []
            await MainActor.run { [weak self] in
                self?.apply(fiatData: fiatData)
            }
        }
    }

    /// Takes new prices and writes the two texts that depend on them again:
    /// the balance and the value of the amount entered. Nothing else on the
    /// screen changes; the amount, the recipient and the button stay.
    private func apply(fiatData: [PIExactFiatData]) {
        guard fiatData != self.fiatData else { return }
        self.fiatData = fiatData
        showFirstAssetBalance()
        // The line under the amount shows either the value or a warning
        // (not enough balance, not enough XOR for the fee). Only the value
        // depends on prices, so a warning is left as it is.
        if checkBalances() && checkXorBalance() {
            view?.updateFirstAsset(
                fiatText: setupInputedFiatText(from: inputedFirstAmount, assetId: firstAssetId)
            )
        }
        updateButtonState()
    }
    
    func choiceBaseAssetButtonTapped() {
        guard
            let assetManager = assetManager,
            let fiatService = fiatService,
            let assets = assetManager.getAssetList() else {
            return
        }
        
        let factory = AssetViewModelFactory(walletAssets: assets,
                                            assetManager: assetManager,
                                            fiatService: fiatService)
        
        wireframe.showChoiceBaseAsset(on: view?.controller,
                                      assetManager: assetManager,
                                      fiatService: fiatService,
                                      assetViewModelFactory: factory,
                                      assetsProvider: assetsProvider,
                                      assetIds: assets.map { $0.identifier },
                                      marketCapService: marketCapService) { [weak self] assetId in
            self?.firstAssetId = assetId
        }
    }
    
    func reviewButtonTapped() {
        guard let fiatService = fiatService,
              let assetManager = assetManager,
              let networkFacade = networkFacade else {
            return
        }

        // Never reached while a needed balance is unavailable (the button
        // is off); checked here as well because this is where an amount
        // would be accepted.
        guard !neededBalanceUnavailable else {
            view?.setupButton(isEnabled: false)
            return
        }

        view?.setupButton(isEnabled: false)
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                guard
                    let reviewedAccount = SelectedWalletSettings.shared
                        .currentAccount,
                    reviewedAccount.isSelected,
                    let reviewedRecipient = self.selectedAddress,
                    !reviewedRecipient.isEmpty
                else {
                    throw WalletNetworkOperationFactoryError.invalidContext
                }
                let reviewedAssetId = self.firstAssetId
                let reviewedAmount = self.inputedFirstAmount
                let reviewedBalance = self.firstAssetBalance
                let reviewedMaximumPreset = self.isMaximumPresetSelected
                guard reviewedBalance.identifier == reviewedAssetId else {
                    throw WalletNetworkOperationFactoryError.invalidContext
                }
                let info = try self.makeExactTransferFeeInfo(
                    selectedAccount: reviewedAccount,
                    recipientAddress: reviewedRecipient,
                    assetId: reviewedAssetId,
                    amount: reviewedAmount
                )
                var exactFee = try await networkFacade.estimateTransferFee(
                    for: info
                )
                try Task.checkCancellation()
                guard exactFee > 0 else {
                    throw WalletNetworkOperationFactoryError.invalidFee
                }
                guard
                    self.firstAssetId == reviewedAssetId,
                    self.selectedAddress == reviewedRecipient,
                    self.inputedFirstAmount == reviewedAmount,
                    self.firstAssetBalance == reviewedBalance,
                    self.isMaximumPresetSelected == reviewedMaximumPreset,
                    let currentAccount = SelectedWalletSettings.shared
                        .currentAccount,
                    currentAccount.isSelected,
                    currentAccount.address == reviewedAccount.address,
                    currentAccount.publicKeyData ==
                        reviewedAccount.publicKeyData,
                    currentAccount.cryptoType == reviewedAccount.cryptoType,
                    currentAccount.networkType == reviewedAccount.networkType
                else {
                    throw WalletNetworkOperationFactoryError.invalidContext
                }

                var transferAmount = reviewedAmount
                let isFeeAsset = assetManager.assetInfo(
                    for: reviewedAssetId
                )?.isFeeAsset ?? false
                if reviewedMaximumPreset, isFeeAsset {
                    for _ in 0..<3 {
                        transferAmount = try Sora2TransferFeeQualification
                            .maximumTransferAmount(
                                assetBalance: reviewedBalance.balance
                                    .decimalValue,
                                exactFee: exactFee
                            )
                        let adjustedInfo = try self.makeExactTransferFeeInfo(
                            selectedAccount: reviewedAccount,
                            recipientAddress: reviewedRecipient,
                            assetId: reviewedAssetId,
                            amount: transferAmount
                        )
                        let adjustedFee = try await networkFacade
                            .estimateTransferFee(for: adjustedInfo)
                        try Task.checkCancellation()
                        guard adjustedFee > 0 else {
                            throw WalletNetworkOperationFactoryError.invalidFee
                        }
                        if adjustedFee == exactFee {
                            break
                        }
                        exactFee = adjustedFee
                    }
                    try Sora2TransferFeeQualification
                        .requireMaximumTransferAmount(
                            amount: transferAmount,
                            assetBalance: reviewedBalance.balance.decimalValue,
                            exactFee: exactFee
                        )
                }

                guard
                    self.firstAssetId == reviewedAssetId,
                    self.selectedAddress == reviewedRecipient,
                    self.inputedFirstAmount == reviewedAmount,
                    self.firstAssetBalance == reviewedBalance,
                    self.isMaximumPresetSelected == reviewedMaximumPreset,
                    let currentAccount = SelectedWalletSettings.shared
                        .currentAccount,
                    currentAccount.isSelected,
                    currentAccount.address == reviewedAccount.address,
                    currentAccount.publicKeyData ==
                        reviewedAccount.publicKeyData,
                    currentAccount.cryptoType == reviewedAccount.cryptoType,
                    currentAccount.networkType == reviewedAccount.networkType
                else {
                    throw WalletNetworkOperationFactoryError.invalidContext
                }
                try Sora2TransferFeeQualification.requireSufficientBalances(
                    amount: transferAmount,
                    assetId: reviewedAssetId,
                    exactFee: exactFee,
                    balances: self.transferBalances(for: reviewedAssetId)
                )
                if transferAmount != reviewedAmount {
                    self.isApplyingPresetAmount = true
                    self.inputedFirstAmount = transferAmount
                    self.isApplyingPresetAmount = false
                    let formatter = NumberFormatter.inputedAmoutFormatter(
                        with: assetManager.assetInfo(
                            for: reviewedAssetId
                        )?.precision ?? 0
                    )
                    self.view?.set(
                        firstAmountText: formatter.stringFromDecimal(
                            transferAmount
                        ) ?? ""
                    )
                }
                self.fee = exactFee
                self.wireframe.showConfirmSendingAsset(
                    on: self.view?.controller.navigationController,
                    assetId: reviewedAssetId,
                    walletService: WalletService(
                        operationFactory: networkFacade
                    ),
                    assetManager: assetManager,
                    fiatService: fiatService,
                    recipientAddress: reviewedRecipient,
                    firstAssetAmount: transferAmount,
                    fee: exactFee,
                    assetsProvider: self.assetsProvider
                )
            } catch {
                let message: String
                if let runtimeMessage = ExtrinsicServiceError
                    .runtimeUserMessage(for: error) {
                    message = runtimeMessage
                } else if let walletError = error as? WalletNetworkOperationFactoryError,
                   case .insufficientBalance = walletError {
                    message = R.string.localizable.commonNotEnoughBalance(
                        preferredLanguages: .currentLocale
                    )
                } else {
                    message = R.string.localizable.commonErrorRetry(
                        preferredLanguages: .currentLocale
                    )
                }
                self.wireframe.present(
                    message: message,
                    title: nil,
                    closeAction: R.string.localizable.commonOk(
                        preferredLanguages: .currentLocale
                    ),
                    from: self.view
                )
            }
            self.updateButtonState()
        }
    }
    
    func selectAddress() {
        changeAddress()
    }
}

extension InputAssetAmountViewModel: AssetProviderObserverProtocol {
    /// The provider calls this on its own queue. Everything this screen
    /// keeps and shows is changed on the main thread.
    func processBalance(data: [BalanceData]) {
        DispatchQueue.main.async { [weak self] in
            self?.updateBalanceData()
        }
    }
}

extension InputAssetAmountViewModel {
    private func makeExactTransferFeeInfo(
        selectedAccount: AccountItem,
        recipientAddress: String,
        assetId: String,
        amount: Decimal
    ) throws -> TransferInfo {
        guard selectedAccount.isSelected,
              !recipientAddress.isEmpty,
              !assetId.isEmpty,
              amount > 0 else {
            throw WalletNetworkOperationFactoryError.invalidContext
        }
        let addressFactory = SS58AddressFactory()
        let accountId = try addressFactory.accountId(
            fromAddress: selectedAccount.address,
            type: selectedAccount.addressType
        ).toHex()
        let destination = try addressFactory.accountId(
            fromAddress: recipientAddress,
            type: selectedAccount.addressType
        ).toHex()
        return TransferInfo(
            source: accountId,
            destination: destination,
            amount: AmountDecimal(value: amount),
            asset: assetId,
            details: "",
            fees: [],
            context: [
                TransactionContextKeys.transactionType:
                    TransactionType.outgoing.rawValue
            ]
        )
    }

    private func transferBalances(for assetId: String) -> [BalanceData] {
        var assetIds = [assetId]
        if assetId != WalletAssetId.xor.rawValue {
            assetIds.append(WalletAssetId.xor.rawValue)
        }
        return assetIds.compactMap { currentAssetId in
            if !firstAssetBalanceUnavailable,
               firstAssetBalance.identifier == currentAssetId {
                return firstAssetBalance
            }
            return assetsProvider?.getBalances(with: [currentAssetId])
                .first(where: { $0.identifier == currentAssetId })
        }
    }

    func updateBalanceData() {
        guard !firstAssetId.isEmpty else { return }
        if let balance = assetsProvider?.getBalances(with: [firstAssetId]).first {
            firstAssetBalanceUnavailable = false
            firstAssetBalance = balance
        } else if assetsProvider?.unavailableBalanceAssetIds(among: [firstAssetId]).contains(firstAssetId) == true {
            // The balance could not be read: say so instead of leaving a
            // zero that reads as "nothing to send".
            firstAssetBalanceUnavailable = true
            showFirstAssetBalance()
        } else if firstAssetBalanceUnavailable {
            // Another asset was chosen whose balance has not arrived yet:
            // "unavailable" was about the one before.
            firstAssetBalanceUnavailable = false
            showFirstAssetBalance()
        }
        // The line under the amount and the button depend on whether
        // there is a balance to check against. What the screen was last
        // drawn for is kept here: the provider already holds the new state
        // when it reports a change.
        let unavailableNow = neededBalanceUnavailable
        if unavailableNow != validatedWithNeededBalanceUnavailable {
            validatedWithNeededBalanceUnavailable = unavailableNow
            refreshAmountValidation()
        }
    }

    /// The fee is paid in XOR; its balance could not be read.
    private var feeBalanceUnavailable: Bool {
        let xor = WalletAssetId.xor.rawValue
        return assetsProvider?.unavailableBalanceAssetIds(among: [xor]).contains(xor) == true
    }

    /// A balance this send is checked against could not be read: the
    /// asset's own, or XOR for the fee.
    private var neededBalanceUnavailable: Bool {
        firstAssetBalanceUnavailable || feeBalanceUnavailable
    }

    /// The one place the balance text is written from: "Balance
    /// unavailable" while the balance could not be read, the balance and
    /// its value otherwise. Always on the main thread, whichever queue the
    /// balance or the prices arrived on.
    private func showFirstAssetBalance() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // What is shown is what holds when this runs, not what held
            // when it was queued.
            self.view?.updateFirstAsset(
                balance: self.firstAssetBalanceUnavailable
                    ? WalletUX.balanceUnavailableText
                    : self.fullBalanceText(from: self.firstAssetBalance)
            )
        }
    }

    /// Writes the line under the amount, its colours and the button again.
    private func refreshAmountValidation() {
        let fiatText = setupInputedFiatText(from: inputedFirstAmount, assetId: firstAssetId)
        let isEnough = checkBalances() && checkXorBalance()
        let text = validationText(with: fiatText, isEnoghtAssetBalance: checkBalances(), isEnoghtXorBalance: checkXorBalance())
        view?.updateFirstAsset(state: isEnough ? .focused : .fail,
                               amountColor: isEnough ? .fgPrimary : .statusError,
                               fiatColor: isEnough ? .fgSecondary : .statusError)
        view?.updateFirstAsset(fiatText: text)
        updateButtonState()
    }

    private func fullBalanceText(from balanceData: BalanceData) -> String {
        var text = ""
        setupFullBalanceText(from: balanceData) { text = $0 }
        return text
    }
    
    func setupFullBalanceText(from balanceData: BalanceData, complention: @escaping (String) -> Void) {
        let balance = NumberFormatter.polkaswapBalance.stringFromDecimal(balanceData.balance.decimalValue) ?? ""
        var fiatBalanceText = ""
        
        if let usdPrice = fiatData.first(where: { $0.id == balanceData.identifier })?.priceUsd?.decimalValue {
            let fiatDecimal = balanceData.balance.decimalValue * usdPrice
            fiatBalanceText = "$" + (NumberFormatter.fiat.stringFromDecimal(fiatDecimal) ?? "")
        }
        
        let balanceText = fiatBalanceText.isEmpty ? "\(balance)" : "\(balance) (\(fiatBalanceText))"
        complention(balanceText)
    }
    
    func setupInputedFiatText(from inputedAmount: Decimal, assetId: String) -> String {
        guard let asset = assetManager?.assetInfo(for: assetId) else { return "" }
        
        var fiatText = ""
        
        if let usdPrice = fiatData.first(where: { $0.id == asset.assetId })?.priceUsd?.decimalValue {
            let fiatDecimal = inputedAmount * usdPrice
            fiatText = "$" + (NumberFormatter.fiat.stringFromDecimal(fiatDecimal) ?? "")
        }
        
        return fiatText
    }
    
    func checkBalances() -> Bool {
        // A balance that could not be read is not "not enough": no warning
        // is derived from its placeholder. The button stays off (see
        // `updateButtonState`) and the balance line says why.
        if firstAssetBalanceUnavailable {
            return true
        }

        // check if balance is enough
        if inputedFirstAmount > firstAssetBalance.balance.decimalValue {
            view?.setupButton(isEnabled: false)
            return false
        }

        // check if exchanging from XOR, and have not enough XOR to pay the fee
        if let fromAsset = assetManager?.assetInfo(for: firstAssetId),
           fromAsset.isFeeAsset,
           inputedFirstAmount + fee > firstAssetBalance.balance.decimalValue {
            view?.setupButton(isEnabled: false)
            return false
        }

        return true
    }
    
    func checkXorBalance() -> Bool {
        // The same for the XOR that pays the fee.
        if feeBalanceUnavailable {
            return true
        }

        guard let xorBalance = assetsProvider?.getBalances(with: [WalletAssetId.xor.rawValue]).first else {
            view?.setupButton(isEnabled: false)
            return false
        }

        // check have enough XOR to pay the fee
        if fee > xorBalance.balance.decimalValue {
            view?.setupButton(isEnabled: false)
            return false
        }

        return true
    }
    
    func validationText(with text: String, isEnoghtAssetBalance: Bool, isEnoghtXorBalance: Bool) -> String {
        if !isEnoghtXorBalance {
            return R.string.localizable.errorTransactionFeeTitle(preferredLanguages: .currentLocale)
        }
        
        if !isEnoghtAssetBalance {
            return R.string.localizable.commonNotEnoughBalance(preferredLanguages: .currentLocale)
        }

        return text
    }
    
    func changeAddress() {
        guard let networkFacade = networkFacade,
              let dataProvider = try? providerFactory.createContactsDataProvider(),
              let assetManager = assetManager else { return }

        wireframe.showSelectAddress(on: view?.controller,
                                    assetId: firstAssetId,
                                    dataProvider: dataProvider,
                                    walletService: WalletService(operationFactory: networkFacade),
                                    networkFacade: networkFacade,
                                    assetManager: assetManager,
                                    qrEncoder: qrEncoder,
                                    sharingFactory: sharingFactory,
                                    assetsProvider: assetsProvider,
                                    providerFactory: providerFactory,
                                    feeProvider: feeProvider,
                                    marketCapService: marketCapService) { [weak self] result in
            self?.selectedAddress = result.firstName
            if let assetId = result.receiverInfo?.assetId {
                self?.firstAssetId = assetId
            }
            self?.view?.focusFirstField()
        }
    }
    
    private func updateButtonState() {
        if firstAssetId.isEmpty {
            view?.setupButton(isEnabled: false)
            return
        }

        // Nothing can be reviewed against a balance that could not be
        // read.
        if neededBalanceUnavailable {
            view?.setupButton(isEnabled: false)
            return
        }
        
        if inputedFirstAmount == .zero {
            view?.setupButton(isEnabled: false)
            return
        }
        
        if !checkBalances() {
            view?.setupButton(isEnabled: false)
            return
        }
        
        if !checkXorBalance() {
            view?.setupButton(isEnabled: false)
            return
        }
        
        if selectedAddress?.isEmpty ?? true {
            view?.setupButton(isEnabled: false)
            return
        }

        view?.setupButton(isEnabled: true)
    }
}
