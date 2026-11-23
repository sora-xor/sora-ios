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

protocol ReceiveViewModelProtocol {
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)? { get set }
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)? { get set }
    func viewDidLoad()
}

final class ReceiveViewModel {
    
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    
    weak var view: ReceiveViewProtocol?
    private var qrService: WalletQRServiceProtocol
    private var sharingFactory: AccountShareFactoryProtocol
    private var accountId: String
    private var address: String
    private var selectedAsset: AssetInfo
    private let accountRepository: AnyDataProviderRepository<AccountItem>
    private var accountName = ""

    private var currentImage: UIImage?
    private var generationID: UUID?
    private var amount: AmountDecimal?
    private var qrOperation: Operation?
    private var fiatData: [PIExactFiatData] = []
    private weak var fiatService: FiatServiceProtocol?
    private weak var assetManager: AssetManagerProtocol?
    
    init(
        qrService: WalletQRServiceProtocol,
        sharingFactory: AccountShareFactoryProtocol,
        accountId: String,
        address: String,
        selectedAsset: AssetInfo,
        amount: AmountDecimal? = nil,
        fiatService: FiatServiceProtocol?,
        assetProvider: AssetProviderProtocol?,
        assetManager: AssetManagerProtocol?
    ) {
        self.qrService = qrService
        self.sharingFactory = sharingFactory
        self.accountId = accountId
        self.address = address
        self.selectedAsset = selectedAsset
        self.amount = amount
        self.fiatService = fiatService
        self.assetManager = assetManager
        
        self.accountRepository = AnyDataProviderRepository(
            UserDataStorageFacade.shared
            .createRepository(filter: nil,
                              sortDescriptors: [],
                              mapper: AnyCoreDataMapper(AccountItemMapper()))
        )

    }
    
    deinit {
        cancelQRGeneration()
    }
}

extension ReceiveViewModel: ReceiveViewModelProtocol {
    func viewDidLoad() {
        // The code and the address do not depend on prices and never wait
        // for them. Prices only add a fiat text to a requested amount: they
        // are read after the code has been asked for, and the item is built
        // again when they arrive.
        Task { @MainActor [weak self] in
            let size = UIScreen.main.bounds.width - 112
            self?.generateQR(with: CGSize(width: size, height: size) )

            guard self?.amount != nil else { return }
            let loaded = await self?.fiatService?.getFiat() ?? []
            self?.show(fiatData: loaded)
        }
    }
}

private extension ReceiveViewModel {
    func generateQR(with size: CGSize) {
        cancelQRGeneration()
        let id = UUID()
        generationID = id
        currentImage = nil
        publishReceive()
        do {
            guard let receiveInfo = createReceiveInfo() else {
                processOperation(image: nil)
                return
            }
            qrOperation = try qrService.generate(from: receiveInfo, qrSize: size, runIn: .main) { [weak self] result in
                DispatchQueue.main.async { [weak self] in
                    guard let self, generationID == id else { return }
                    processOperation(image: try? result?.get())
                }
            }
        } catch {
            processOperation(image: nil)
        }
    }

    func processOperation(image: UIImage?) {
        generationID = nil
        qrOperation = nil
        currentImage = image
        publishReceive()
        let persistentOperation = self.accountRepository.fetchAllOperation(with: RepositoryFetchOptions())
        persistentOperation.completionBlock = { [weak self] in
            guard let accounts = try? persistentOperation.extractNoCancellableResultData() else { return }
            DispatchQueue.main.async {
                guard let self, let name = accounts.first(where: { $0.address == self.address })?.username,
                      name != self.accountName else { return }
                self.accountName = name
                self.publishReceive()
            }
        }
        OperationManagerFacade.runtimeBuildingQueue.addOperation(persistentOperation)
    }

    @MainActor
    func show(fiatData loaded: [PIExactFiatData]) {
        guard loaded != fiatData else { return }
        fiatData = loaded
        publishReceive()
    }
    
    func createReceiveInfo() -> ReceiveInfo? {
        return ReceiveInfo(accountId: accountId,
                           assetId: selectedAsset.identifier,
                           amount: amount,
                           details: "")
    }
    
    func cancelQRGeneration() {
        generationID = nil
        qrOperation?.cancel()
        qrOperation = nil
    }
    
    
    func share() {
        guard let qrImage = currentImage, let receiveInfo = createReceiveInfo() else { return }
        let sources = sharingFactory.createSources(for: receiveInfo, qrImage: qrImage)
        
        let activityController = UIActivityViewController(activityItems: sources, applicationActivities: nil)
        view?.controller.present(activityController, animated: true, completion: nil)
    }
}

private extension ReceiveViewModel {
    func publishReceive() {
        let item = ReceiveItem(name: accountName, address: address, qrImage: currentImage, sendAssetViewModel: setupSendAsset(),
                               isGenerating: generationID != nil)
        if currentImage != nil { item.shareHandler = { [weak self] in self?.share() } }
        item.accountTapHandler = { [weak self, address] in
            UIPasteboard.general.string = address
            self?.view?.didCopyAddress(address)
        }
        setupItems?([item])
    }

    func setupSendAsset() -> SendAssetViewModel? {
        guard let amount else { return nil }
       
        return SendAssetViewModel(symbol: selectedAsset.symbol,
                                  amount: amount.stringValue,
                                  balance: nil,
                                  fiat: setupFiatText(from: amount.decimalValue, assetId: selectedAsset.assetId, fiatData: fiatData),
                                  svgString: selectedAsset.icon)
    }
    
    func setupFiatText(from amount: Decimal, assetId: String, fiatData: [PIExactFiatData]) -> String {
        guard let asset = assetManager?.assetInfo(for: assetId) else { return "" }
        
        var fiatText = ""
        
        if let usdPrice = fiatData.first(where: { $0.id == asset.assetId })?.priceUsd?.decimalValue {
            let fiatDecimal = amount * usdPrice
            fiatText = "$" + (NumberFormatter.fiat.stringFromDecimal(fiatDecimal) ?? "")
        }
        
        return fiatText
    }
}
