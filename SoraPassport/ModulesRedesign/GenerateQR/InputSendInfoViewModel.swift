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

import Foundation
import SoraUIKit

import sorawallet
import Combine

final class InputSendInfoViewModel {

    enum Input {
        case choiseAsset
        case createQr
    }

    enum Output { }
    
    @Published var address: String?
    @Published var username: String?
    @Published var assetSymbol: String?
    @Published var assetImage: UIImage?
    @Published var balanceFiatText: String?
    @Published var inputedFiatAmountText: String?
    @Published var state: InputFieldState?
    
    var assetBalance: BalanceData = BalanceData(identifier: WalletAssetId.xor.rawValue, balance: AmountDecimal(value: 0)) {
        didSet {
            balanceFiatText = setupFullBalanceText(from: assetBalance)
        }
   }
    
    var asset: AssetInfo? {
        didSet {
            guard let asset = asset else { return }
            assetImage = RemoteSerializer.shared.image(with: asset.icon ?? "")
            assetSymbol = asset.symbol
            inputedFiatAmountText = setupInputedFiatText(from: inputedAmount, assetId: asset.assetId)
            setupBalanceDataProvider()
        }
    }
    
    var inputedAmount: Decimal = 0 {
        didSet {
            guard let asset = asset else { return }
            inputedFiatAmountText = setupInputedFiatText(from: inputedAmount, assetId: asset.assetId)
        }
    }
    
    var fiatData: [FiatData] = [] {
        didSet {
            guard let asset = asset else { return }
            balanceFiatText = setupFullBalanceText(from: assetBalance)
            inputedFiatAmountText = setupInputedFiatText(from: inputedAmount, assetId: asset.assetId)
        }
    }

    weak var fiatService: FiatServiceProtocol?
    weak var assetManager: AssetManagerProtocol?
    weak var assetsProvider: AssetProviderProtocol?

    private let output: PassthroughSubject<Output, Never> = .init()
    private var cancellables = Set<AnyCancellable>()
    private weak var wireframe: GenerateQRWireframeProtocol?
    private let accountId: String
    private var qrEncoder: WalletQREncoderProtocol
    private var sharingFactory: AccountShareFactoryProtocol
    private let marketCapService: MarketCapServiceProtocol
    
    init(
        address: String,
        accountId: String,
        username: String,
        fiatService: FiatServiceProtocol?,
        assetManager: AssetManagerProtocol?,
        assetsProvider: AssetProviderProtocol?,
        wireframe: GenerateQRWireframeProtocol?,
        qrEncoder: WalletQREncoderProtocol,
        sharingFactory: AccountShareFactoryProtocol,
        marketCapService: MarketCapServiceProtocol
    ) {
        self.address = address
        self.accountId = accountId
        self.username = username
        self.fiatService = fiatService
        self.assetManager = assetManager
        self.assetsProvider = assetsProvider
        self.wireframe = wireframe
        self.qrEncoder = qrEncoder
        self.sharingFactory = sharingFactory
        self.marketCapService = marketCapService
    }
    
    func transform(input: AnyPublisher<Input, Never>) -> AnyPublisher<Output, Never> {
        input.sink { [weak self] event in
            guard let self = self, let assetManager = self.assetManager, let fiatService = self.fiatService else { return }
            switch event {
            case .choiseAsset:
                let assetInfos = assetManager.getAssetList() ?? []
                let assetViewModelFactory = AssetViewModelFactory(walletAssets: assetInfos,
                                                                  assetManager: assetManager,
                                                                  fiatService: fiatService)
                self.wireframe?.showAssetSelection(assetManager: assetManager,
                                                   fiatService: fiatService,
                                                   assetViewModelFactory: assetViewModelFactory,
                                                   assetsProvider: self.assetsProvider,
                                                   assetIds: assetInfos.map { $0.assetId },
                                                   marketCapService: self.marketCapService,
                                                   completion: { selectedAssetId in
                    self.asset = assetManager.assetInfo(for: selectedAssetId)
                })
                break
            case .createQr:
                guard let asset = self.asset else { return }
                self.wireframe?.showReceive(selectedAsset: asset,
                                            accountId: self.accountId,
                                            address: self.address ?? "",
                                            amount: AmountDecimal(value: self.inputedAmount),
                                            qrEncoder: self.qrEncoder,
                                            sharingFactory: self.sharingFactory,
                                            fiatService: fiatService,
                                            assetProvider: self.assetsProvider,
                                            assetManager: assetManager)
                break
            }
        }.store(in: &cancellables)
        return output.eraseToAnyPublisher()
    }
    
    func viewDidLoad() {
        asset = assetManager?.assetInfo(for: WalletAssetId.xor.rawValue)
        
        Task { [weak self] in
            guard let self else { return }
            self.fiatData = await self.fiatService?.getFiat() ?? []
        }

        assetsProvider?.add(observer: self)
    }
    
    func setupBalanceDataProvider() {
        guard let asset = asset, let balance = assetsProvider?.getBalances(with: [asset.assetId]).first else { return }
        assetBalance = balance
    }
    
    func setupFullBalanceText(from balanceData: BalanceData) -> String {
        let balance = NumberFormatter.polkaswapBalance.stringFromDecimal(balanceData.balance.decimalValue) ?? ""
        let fiatBalanceText = setupInputedFiatText(from: balanceData.balance.decimalValue, assetId: balanceData.identifier)
        return fiatBalanceText.isEmpty ? "\(balance)" : "\(balance) (\(fiatBalanceText))"
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
}

extension InputSendInfoViewModel: AssetProviderObserverProtocol {
    func processBalance(data: [BalanceData]) {
        setupBalanceDataProvider()
    }
}

extension InputSendInfoViewModel: FiatServiceObserverProtocol {
    func processFiat(data: [FiatData]) {
        fiatData = data
    }
}
