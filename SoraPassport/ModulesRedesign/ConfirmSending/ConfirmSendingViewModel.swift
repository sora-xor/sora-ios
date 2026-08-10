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

/// Revoked by navigation before a queued ordinary transfer can reach secret
/// use. The network layer also binds the signer to the same selected account.
final class Sora2TransferSigningAuthorization: @unchecked Sendable {
    private let lock = NSLock()
    private var isAuthorized = true

    func requireAuthorized() throws {
        lock.lock()
        defer { lock.unlock() }
        guard isAuthorized else {
            throw CancellationError()
        }
    }

    func revoke() {
        lock.lock()
        isAuthorized = false
        lock.unlock()
    }
}

struct Sora2ConfirmSendingResultProjection {
    let status: TransactionBase.Status
    let transactionHash: String

    static func make(
        from result: Result<Data, Swift.Error>
    ) -> Sora2ConfirmSendingResultProjection {
        do {
            // A typed post-handoff ambiguity opens the exact staged hash as
            // pending. Every pre-transport or unrelated failure still opens as
            // failed and cannot borrow a hash from another submission.
            let hash = try Sora2LegacySubmissionProjection
                .transactionHash(from: result)
            return Sora2ConfirmSendingResultProjection(
                status: .pending,
                transactionHash: hash.toHex(includePrefix: true)
            )
        } catch {
            return Sora2ConfirmSendingResultProjection(
                status: .failed,
                transactionHash: ""
            )
        }
    }
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
    private var isSubmitting = false
    private var preflightTask: Task<Void, Never>?
    private let signingAuthorization = Sora2TransferSigningAuthorization()

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

    func viewWillDisappear() {
        signingAuthorization.revoke()
        preflightTask?.cancel()
        preflightTask = nil
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
    func updateContent(with fiatData: [PIExactFiatData] = []) {

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
        guard !isSubmitting,
              confirmationState == .readyToSubmit,
              fee > 0 else {
            return
        }
        isSubmitting = true
        wireframe?.showActivityIndicator()
        preflightTask = Task { @MainActor [weak self] in
            await self?.runExactTransferPreflight()
        }
    }

    @MainActor
    private func runExactTransferPreflight() async {
        do {
            guard let selectedAccount =
                SelectedWalletSettings.shared.currentAccount else {
                throw WalletNetworkOperationFactoryError.invalidContext
            }
            let reviewInfo = try makeTransferInfo(
                fee: fee,
                selectedAccount: selectedAccount
            )

            // Obtain a live balance snapshot adjacent to the queued signer and
            // reject the reviewed transfer before secret use when it is already
            // unaffordable.
            let reviewedBalances = try await fetchLiveTransferBalances()
            try Sora2TransferFeeQualification.requireSufficientBalances(
                amount: firstAssetAmount,
                assetId: assetId,
                exactFee: fee,
                balances: reviewedBalances
            )
            try Task.checkCancellation()
            try signingAuthorization.requireAuthorized()
            try requireSelectedAccount(selectedAccount)

            let prepared = try await walletService.prepareTransferSubmission(
                for: reviewInfo,
                preSigningValidation: { [signingAuthorization] in
                    try signingAuthorization.requireAuthorized()
                    try Self.requireSelectedAccountSnapshot(selectedAccount)
                }
            )
            defer { prepared.discard() }
            let exactFee = try Sora2TransferFeeQualification.requireExact(
                reviewedFee: fee,
                signedBytesFee: prepared.fee
            )

            // Re-read both balances after exact-byte fee qualification. This is
            // the final asynchronous affordability check before the transport
            // helper re-queries the exact same signed bytes and hands them off.
            let exactBalances = try await fetchLiveTransferBalances()
            try Sora2TransferFeeQualification.requireSufficientBalances(
                amount: firstAssetAmount,
                assetId: assetId,
                exactFee: exactFee,
                balances: exactBalances
            )
            let submissionInfo = try makeTransferInfo(
                fee: exactFee,
                selectedAccount: selectedAccount
            )
            try Task.checkCancellation()
            try signingAuthorization.requireAuthorized()
            try requireSelectedAccount(selectedAccount)

            do {
                let hash = try await walletService.submitPreparedTransfer(
                    prepared,
                    info: submissionInfo,
                    preTransportValidation: { [signingAuthorization] in
                        try signingAuthorization.requireAuthorized()
                        try Self.requireSelectedAccountSnapshot(
                            selectedAccount
                        )
                    }
                )
                finishExactTransfer(with: .success(hash))
            } catch let transportError as PreparedExtrinsicTransportError {
                switch transportError {
                case .submissionUnknown:
                    finishExactTransfer(with: .failure(transportError))
                case .failedBeforeTransport:
                    throw transportError
                }
            }
        } catch is CancellationError {
            isSubmitting = false
            preflightTask = nil
            wireframe?.hideActivityIndicator()
        } catch {
            finishExactTransferPreflight(with: error)
        }
    }

    @MainActor
    private func fetchLiveTransferBalances() async throws -> [BalanceData] {
        let assetIds = Array(Set([
            assetId,
            WalletAssetId.xor.rawValue
        ])).sorted()
        return try await withCheckedThrowingContinuation { continuation in
            walletService.fetchBalance(
                for: assetIds,
                runCompletionIn: .main
            ) { result in
                guard let result else {
                    continuation.resume(
                        throwing: WalletNetworkOperationFactoryError
                            .invalidContext
                    )
                    return
                }
                switch result {
                case let .success(balances):
                    guard let balances else {
                        continuation.resume(
                            throwing: WalletNetworkOperationFactoryError
                                .invalidContext
                        )
                        return
                    }
                    continuation.resume(returning: balances)
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func makeTransferInfo(
        fee exactFee: Decimal,
        selectedAccount: AccountItem
    ) throws -> TransferInfo {
        guard exactFee > 0,
              firstAssetAmount > 0 else {
            throw WalletNetworkOperationFactoryError.invalidAmount
        }
        let addressFactory = SS58AddressFactory()
        let accountId = try addressFactory.accountId(
            fromAddress: selectedAccount.address,
            type: selectedAccount.addressType
        ).toHex()
        let destinationAccountId = try addressFactory.accountId(
            fromAddress: recipientAddress,
            type: selectedAccount.addressType
        ).toHex()
        let networkFeeDescription = FeeDescription(
            identifier: WalletAssetId.xor.rawValue,
            assetId: WalletAssetId.xor.rawValue,
            type: "fee",
            parameters: [],
            accountId: nil,
            minValue: nil,
            maxValue: nil,
            context: nil
        )
        return TransferInfo(
            source: accountId,
            destination: destinationAccountId,
            amount: AmountDecimal(value: firstAssetAmount),
            asset: assetId,
            details: "",
            fees: [
                Fee(
                    value: AmountDecimal(value: exactFee),
                    feeDescription: networkFeeDescription
                )
            ],
            context: [
                TransactionContextKeys.transactionType:
                    TransactionType.outgoing.rawValue
            ]
        )
    }

    private func requireSelectedAccount(_ expected: AccountItem) throws {
        try Self.requireSelectedAccountSnapshot(expected)
    }

    private static func requireSelectedAccountSnapshot(
        _ expected: AccountItem
    ) throws {
        guard let current = SelectedWalletSettings.shared.currentAccount,
              current.isSelected,
              current.address == expected.address,
              current.publicKeyData == expected.publicKeyData,
              current.cryptoType == expected.cryptoType,
              current.networkType == expected.networkType else {
            throw SigningWrapperError.missingSelectedAccount
        }
    }

    @MainActor
    private func finishExactTransfer(with result: Result<Data, Swift.Error>) {
        isSubmitting = false
        preflightTask = nil
        wireframe?.hideActivityIndicator()
        handleTransfer(result: result)
    }

    @MainActor
    private func finishExactTransferPreflight(with error: Swift.Error) {
        isSubmitting = false
        preflightTask = nil
        wireframe?.hideActivityIndicator()
        let message: String
        if let walletError = error as? WalletNetworkOperationFactoryError {
            switch walletError {
            case .insufficientBalance:
                message = R.string.localizable.commonNotEnoughBalance(
                    preferredLanguages: .currentLocale
                )
            case .invalidFee:
                message = NexusToriiError.quoteChanged.localizedDescription
            default:
                message = R.string.localizable.commonErrorRetry(
                    preferredLanguages: .currentLocale
                )
            }
        } else {
            message = R.string.localizable.commonErrorRetry(
                preferredLanguages: .currentLocale
            )
        }
        wireframe?.present(
            message: message,
            title: nil,
            closeAction: R.string.localizable.commonOk(
                preferredLanguages: .currentLocale
            ),
            from: view
        )
    }

    private func handleTransfer(result: Result<Data, Swift.Error>) {
        let projection = Sora2ConfirmSendingResultProjection.make(
            from: result
        )
        let base = TransactionBase(txHash: projection.transactionHash,
                                   blockHash: "",
                                   fee: Amount(value: fee * pow(10, 18)),
                                   status: projection.status,
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

    func setupFullBalanceText(from balanceData: BalanceData, fiatData: [PIExactFiatData]) -> String {
        let balance = NumberFormatter.polkaswapBalance.stringFromDecimal(balanceData.balance.decimalValue) ?? ""
        var fiatBalanceText = ""

        if let usdPrice = fiatData.first(where: { $0.id == balanceData.identifier })?.priceUsd?.decimalValue {
            let fiatDecimal = balanceData.balance.decimalValue * usdPrice
            fiatBalanceText = "$" + (NumberFormatter.fiat.stringFromDecimal(fiatDecimal) ?? "")
        }

        return fiatBalanceText.isEmpty ? "\(balance)" : "\(balance) (\(fiatBalanceText))"
    }

    func setupFiatText(from amount: Decimal, assetId: String, fiatData: [PIExactFiatData]) -> String {
        guard let asset = assetManager.assetInfo(for: assetId) else { return "" }

        var fiatText = ""

        if let usdPrice = fiatData.first(where: { $0.id == asset.assetId })?.priceUsd?.decimalValue {
            let fiatDecimal = amount * usdPrice
            fiatText = "$" + (NumberFormatter.fiat.stringFromDecimal(fiatDecimal) ?? "")
        }

        return fiatText
    }
}
