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

enum GenerateQRMode {
    case receive
    case request
}

protocol GenerateQRViewModelProtocol {
    var setupSwicherView: ((SwitcherViewModel) -> Void)? { get set }
    var setupReceiveView: ((ReceiveQRViewModel) -> Void)? { get set }
    var setupRequestView: ((InputSendInfoViewModel) -> Void)? { get set }
    var updateContent: ((GenerateQRMode) -> Void)? { get set }
    var showShareContent: (([Any]) -> Void)? { get set }
    var closeHadler: (() -> Void)? { get }
    func viewDidLoad()
}

final class GenerateQRViewModel {
    var setupReceiveView: ((ReceiveQRViewModel) -> Void)?
    var setupSwicherView: ((SwitcherViewModel) -> Void)?
    var setupRequestView: ((InputSendInfoViewModel) -> Void)?
    var updateContent: ((GenerateQRMode) -> Void)?
    var showShareContent: (([Any]) -> Void)?
    var closeHadler: (() -> Void)?
    var scanCompletion: ((ScanQRResult) -> Void)?
    
    weak var view: GenerateQRViewProtocol?
    var wireframe: GenerateQRWireframeProtocol?
    private var qrService: WalletQRServiceProtocol
    private var sharingFactory: AccountShareFactoryProtocol
    private var accountId: String
    private var address: String
    private var username: String
    private let accountRepository: AnyDataProviderRepository<AccountItem>
    private let qrEncoder: WalletQREncoderProtocol
    private var appEventService = AppEventService()
    private var networkFacade: WalletNetworkOperationFactoryProtocol?
    private let providerFactory: BalanceProviderFactory
    private let feeProvider: FeeProviderProtocol
    
    private var mode: GenerateQRMode = .receive {
        didSet(oldValue) {
            guard oldValue != mode else { return }
            requestModel.isSelected = mode == .request
            reveiveModel.isSelected = mode == .receive
            setupSwicherView?(swicherViewModel)
            updateContent?(mode)
        }
    }
    
    private lazy var reveiveModel: SwitcherButtonViewModel = {
        var reveiveModel = SwitcherButtonViewModel(title: R.string.localizable.commonReceive(preferredLanguages: .currentLocale),
                                                   isSelected: true)
        reveiveModel.actionBlock = { [weak self] in
            self?.mode = .receive
        }
        return reveiveModel
    }()
    
    private lazy var requestModel: SwitcherButtonViewModel = {
        var requestModel = SwitcherButtonViewModel(title: R.string.localizable.commonRequest(preferredLanguages: .currentLocale),
                                                isSelected: false)
        requestModel.actionBlock = { [weak self] in
            self?.mode = .request
        }
        return requestModel
    }()
    
    private lazy var swicherViewModel = SwitcherViewModel(buttonViewModels: [ reveiveModel, requestModel ])
    
    private lazy var requestViewModel = InputSendInfoViewModel(address: address,
                                                               accountId: accountId,
                                                               username: username,
                                                               fiatService: fiatService,
                                                               assetManager: assetManager,
                                                               assetsProvider: assetsProvider,
                                                               wireframe: wireframe,
                                                               qrEncoder: qrEncoder,
                                                               sharingFactory: sharingFactory,
                                                               marketCapService: marketCapService)

    private var currentImage: UIImage?
    private let fiatService: FiatServiceProtocol?
    private let assetManager: AssetManagerProtocol?
    private let assetsProvider: AssetProviderProtocol?
    private let isScanQRShown: Bool
    private let marketCapService: MarketCapServiceProtocol
    
    init(
        qrService: WalletQRServiceProtocol,
        sharingFactory: AccountShareFactoryProtocol,
        accountId: String,
        address: String,
        username: String,
        fiatService: FiatServiceProtocol?,
        assetManager: AssetManagerProtocol?,
        assetsProvider: AssetProviderProtocol?,
        qrEncoder: WalletQREncoderProtocol,
        networkFacade: WalletNetworkOperationFactoryProtocol?,
        providerFactory: BalanceProviderFactory,
        feeProvider: FeeProviderProtocol,
        marketCapService: MarketCapServiceProtocol,
        isScanQRShown: Bool = true
    ) {
        self.qrService = qrService
        self.sharingFactory = sharingFactory
        self.accountId = accountId
        self.address = address
        self.username = username
        self.fiatService = fiatService
        self.assetManager = assetManager
        self.assetsProvider = assetsProvider
        self.qrEncoder = qrEncoder
        self.networkFacade = networkFacade
        self.feeProvider = feeProvider
        self.providerFactory = providerFactory
        self.isScanQRShown = isScanQRShown
        self.marketCapService = marketCapService

        self.accountRepository = AnyDataProviderRepository(
            UserDataStorageFacade.shared
            .createRepository(filter: nil,
                              sortDescriptors: [],
                              mapper: AnyCoreDataMapper(AccountItemMapper()))
        )

    }
}

extension GenerateQRViewModel: GenerateQRViewModelProtocol {
    func viewDidLoad() {
        requestViewModel.viewDidLoad()
        generateQR()
        setupSwicherView?(swicherViewModel)
        setupRequestView?(requestViewModel)
    }
    
    func scanQRCodeButtonTapped() {
        if isScanQRShown {
            view?.controller.dismiss(animated: true)
            return
        }
        
        guard let controller = view?.controller,
              let assetManager = assetManager,
              let networkFacade = networkFacade else {
            return
        }
        
        let completion: (ScanQRResult) -> Void = { [weak self] result in
            self?.handle(result)
        }
        
        wireframe?.showScanQR(on: controller,
                              networkFacade: networkFacade,
                              assetManager: assetManager,
                              qrEncoder: qrEncoder,
                              sharingFactory: sharingFactory,
                              assetsProvider: assetsProvider,
                              providerFactory: providerFactory,
                              feeProvider: feeProvider,
                              marketCapService: marketCapService,
                              scanCompletion: completion)
    }
}

private extension GenerateQRViewModel {
    func generateQR() {
        guard let receiveInfo = createGenerateQRInfo() else { return }
        
        let size = UIScreen.main.bounds.width - 112
        let qrSize = CGSize(width: size, height: size)
        try? qrService.generate(from: receiveInfo, qrSize: qrSize, runIn: .main) { [weak self] operationResult in
            guard case .success(let image) = operationResult else { return }
            self?.currentImage = image
            self?.processOperation()
        }
    }
    
    func processOperation() {
        let persistentOperation = self.accountRepository.fetchAllOperation(with: RepositoryFetchOptions())
        
        persistentOperation.completionBlock = { [weak self] in
            guard let accounts = try? persistentOperation.extractNoCancellableResultData() else { return }
            
            let selectedAccountAddress = SelectedWalletSettings.shared.currentAccount?.address ?? ""
            let selectedAccount = accounts.first { $0.address == selectedAccountAddress }
            
            var viewModel = ReceiveQRViewModel(name: selectedAccount?.username ?? "",
                                               address: selectedAccountAddress,
                                               qrImage: self?.currentImage)
            viewModel.shareHandler = { [weak self] in
                self?.share()
            }
            viewModel.scanQRHandler = { [weak self] in
                self?.scanQRCodeButtonTapped()
            }
            viewModel.accountTapHandler = {
                let title = NSAttributedString(string: R.string.localizable.commonCopied(preferredLanguages: .currentLocale))
                let viewModel = AppEventViewController.ViewModel(title: title)
                let appEventController = AppEventViewController(style: .custom(viewModel))
                self?.appEventService.showToasterIfNeeded(viewController: appEventController)
                UIPasteboard.general.string = selectedAccountAddress
            }
            self?.setupReceiveView?(viewModel)
        }

        OperationManagerFacade.runtimeBuildingQueue.addOperation(persistentOperation)
    }
    
    func createGenerateQRInfo() -> ReceiveInfo? {
        return ReceiveInfo(accountId: accountId,
                           assetId: WalletAssetId.xor.rawValue,
                           amount: nil,
                           details: "")
    }

    func share() {
        guard let qrImage = currentImage, let receiveInfo = createGenerateQRInfo() else { return }
        let sources = sharingFactory.createSources(for: receiveInfo, qrImage: qrImage)
        showShareContent?(sources)
    }
    
    func handle(_ result: ScanQRResult) {
        guard let fiatService = fiatService,
              let assetsProvider = assetsProvider,
              let assetManager = assetManager,
              let networkFacade = networkFacade else { return }
        
        if let amount = result.receiverInfo?.amount {
            Task { @MainActor [weak self] in
                guard let self,
                      let selectedAccount = SelectedWalletSettings.shared
                        .currentAccount,
                      selectedAccount.isSelected else {
                    return
                }
                do {
                    let reviewedRecipient = result.firstName
                    let reviewedAmount = amount
                    let addressFactory = SS58AddressFactory()
                    let source = try addressFactory.accountId(
                        fromAddress: selectedAccount.address,
                        type: selectedAccount.addressType
                    ).toHex()
                    let destination = try addressFactory.accountId(
                        fromAddress: reviewedRecipient,
                        type: selectedAccount.addressType
                    ).toHex()
                    let assetId = result.receiverInfo?.assetId ?? .xor
                    let info = TransferInfo(
                        source: source,
                        destination: destination,
                        amount: reviewedAmount,
                        asset: assetId,
                        details: "",
                        fees: [],
                        context: [
                            TransactionContextKeys.transactionType:
                                TransactionType.outgoing.rawValue
                        ]
                    )
                    let exactFee = try await networkFacade
                        .estimateTransferFee(for: info)
                    try Task.checkCancellation()
                    guard exactFee > 0 else {
                        throw WalletNetworkOperationFactoryError.invalidFee
                    }
                    guard
                        let currentAccount = SelectedWalletSettings.shared
                            .currentAccount,
                        currentAccount.isSelected,
                        currentAccount.address == selectedAccount.address,
                        currentAccount.publicKeyData ==
                            selectedAccount.publicKeyData,
                        currentAccount.cryptoType == selectedAccount.cryptoType,
                        currentAccount.networkType == selectedAccount.networkType
                    else {
                        throw WalletNetworkOperationFactoryError.invalidContext
                    }
                    self.wireframe?.showConfirmSendingAsset(
                        on: self.view?.controller,
                        assetId: assetId,
                        walletService: WalletService(
                            operationFactory: networkFacade
                        ),
                        assetManager: assetManager,
                        fiatService: fiatService,
                        recipientAddress: reviewedRecipient,
                        firstAssetAmount: reviewedAmount.decimalValue,
                        fee: exactFee,
                        assetsProvider: assetsProvider
                    )
                } catch {
                    self.wireframe?.showFeeEstimationError(
                        on: self.view?.controller,
                        retry: { [weak self] in
                            self?.handle(result)
                        }
                    )
                }
            }
            return
        }
        wireframe?.showSend(on: view?.controller,
                            selectedTokenId: result.receiverInfo?.assetId ?? .xor,
                            selectedAddress: result.firstName,
                            fiatService: fiatService,
                            assetManager: assetManager,
                            providerFactory: providerFactory,
                            networkFacade: networkFacade,
                            assetsProvider: assetsProvider,
                            qrEncoder: qrEncoder,
                            sharingFactory: sharingFactory,
                            marketCapService: marketCapService)
    }
}
