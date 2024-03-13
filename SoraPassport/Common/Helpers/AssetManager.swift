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

import Foundation
import SoraKeystore

import RobinHood
import sorawallet

protocol AssetManagerProtocol: AnyObject {
    func assetInfo(for identifier: String) -> AssetInfo?
    func getAssetList() -> [AssetInfo]?
    func updateAssetList(_ list: [AssetInfo])
    func saveAssetList(_ list: [AssetInfo])
    func sortedAssets(_ list: [WalletAsset], onlyVisible: Bool) -> [WalletAsset]
    func visibleCount() -> UInt
    static var networkAssets: [AssetInfo] { get set }
    func setup(for accountSettings: SelectedWalletSettings)
}

final class AssetManager: AssetManagerProtocol {
    static var networkAssets: [AssetInfo] = [] //very dirty, bur we need to pass network assets into initialization of the chain.

    private let accountRepository: AnyDataProviderRepository<AccountItem>
    private let storage: AnyDataProviderRepository<AssetInfo>
    private let operationManager: OperationManagerProtocol
    private let chainProvider: StreamableProvider<ChainModel>
    private let chainId: ChainModel.Id
    private var chain: ChainModel?
    private var settings: AccountSettings?
    private let queue = DispatchQueue(label: "co.jp.soramitsu.sora.asset.manager", attributes: .concurrent)
    private var accountSettings: SelectedWalletSettings? {
        didSet {
            settings = accountSettings?.value?.settings ?? AccountSettings()
        }
    }

    private var assets: [AssetInfo]?

    init(storage: AnyDataProviderRepository<AssetInfo>,
         chainProvider: StreamableProvider<ChainModel>,
         chainId: ChainModel.Id,
         operationManager: OperationManagerProtocol) {
        self.storage = storage
        self.operationManager = operationManager
        self.chainProvider = chainProvider
        self.chainId = chainId

        self.accountRepository = AnyDataProviderRepository(
            UserDataStorageFacade.shared
            .createRepository(filter: nil,
                              sortDescriptors: [],
                              mapper: AnyCoreDataMapper(AccountItemMapper()))
        )

        let updateClosure: ([DataProviderChange<ChainModel>]) -> Void = { [weak self] changes in
            self?.handle(changes: changes)
        }

        let failureClosure: (Swift.Error) -> Void = { error in
            Logger.shared.error("Unexpected error chains listener setup: \(error)")
        }

        let options = StreamableProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false,
            refreshWhenEmpty: false
        )


        chainProvider.addObserver(
            self,
            deliverOn: DispatchQueue.global(qos: .userInitiated),
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    private func handle(changes: [DataProviderChange<ChainModel>]) {
        changes.forEach { change in
            switch change {
            case let .insert(chain):
                guard chain.chainId == self.chainId else {
                    return
                }
                self.chain = chain
            case let .update(chain):
                guard chain.chainId == self.chainId else {
                    return
                }
                self.chain = chain
            case let .delete(_):
                break
            }
        }
    }

    func setup(for accountSettings: SelectedWalletSettings) {
        self.accountSettings = accountSettings
        Logger.shared.info("ASSET MANAGER SETUP \(chain?.chainAssets)")
        let chainAssets = chain?.chainAssets.map { $0.asset } ?? []
        self.updateWhitelisted(chainAssets)
    }

    func sortedAssets(_ list: [WalletAsset], onlyVisible: Bool = false) -> [WalletAsset] {
        let sorted = list.sorted(by: orderSort)

        if onlyVisible {
            var visible =  sorted.filter { (asset) -> Bool in
                if let info = assetInfo(for: asset.identifier) {
                    if asset.isFeeAsset { return true }
                    return info.visible
                }
                return true
            }
            if let topAsset = visible.first(where: { $0.isFeeAsset }),
               let info = assetInfo(for: topAsset.identifier),
               info.visible {
                    visible.append(WalletAsset.dummyAsset)
                    //fee asset should be always visible, but balance might be hidden, so we need to force reload in capital by altering the array
            }
            return visible
        }
        return sorted
    }

    private func orderSort(_ asset0: WalletAsset, _ asset1: WalletAsset) -> Bool {
        if let index0 = settings?.orderedAssetIds?.firstIndex(where: {$0 == asset0.identifier }),
           let index1 = settings?.orderedAssetIds?.firstIndex(where: {$0 == asset1.identifier }) {
            return index0 < index1
        } else {
            return asset0.symbol < asset1.symbol
        }
    }

    func assetInfo(for identifier: String) -> AssetInfo? {
        if let assetInfo = assets?.first(where: { $0.assetId == identifier}) {
            return assetInfo
        } else {
            return nil
        }
    }

    func visibleCount() -> UInt {
        Logger.shared.info("VISIBLE COUNT \(settings?.visibleAssetIds?.count)")
        guard let visibleAssets = settings?.visibleAssetIds,
              visibleAssets.count > 0 else {
            return 1
        }
        return UInt(visibleAssets.count)
    }

    private func defaultSort(_ a0: AssetInfo, _ a1: AssetInfo) -> Bool {
        let defAssetA = WalletAssetId(rawValue: a0.assetId)
        let defAssetB = WalletAssetId(rawValue: a1.assetId)
        if let assetA = defAssetA?.defaultSort,
           let assetB = defAssetB?.defaultSort {
            return assetA < assetB
        } else if defAssetA != nil {
            return true
        } else if defAssetB != nil {
            return false
        } else {
            return a0.symbol < a1.symbol
        }
    }

    private func updateWhitelisted(_ list: [AssetInfo]) {
        var updated: [AssetInfo] = list

        if let settings = self.settings,
           let order = settings.orderedAssetIds,  //they are always ordered
           !order.isEmpty {
            updated = order.enumerated().compactMap { identifier in
                if var asset = list.first(where: { $0.identifier == identifier.element }) {
                    if let visibles = settings.visibleAssetIds {
                        asset.visible = visibles.contains(where: { identifier in
                            asset.identifier == identifier
                        })
                    }
                    return asset
                }
                return nil
            }
            
            let updatedIds = updated.map { $0.assetId }
            self.assets = updated + list.filter { !updatedIds.contains($0.identifier) }
        } else { //default sort
            updated =  list.sorted(by: defaultSort).map { asset in
                var item = asset
                if WalletAssetId(rawValue: item.assetId) != nil {
                    item.visible = true
                } else {
                    item.visible = false
                }
                return item as AssetInfo
            }
            self.assets = updated
        }
        updateAssetList(updated)
    }
    
    func updateAssetList(_ list: [AssetInfo]) {
        print("list = \(list)")

        Logger.shared.info("ASSETS UPDATE \(self.assets?.count)")
        var newOrder: [String] = []
        var newVisible: [String] = []
        if let assets = assets, assets.count > 0 {
            newOrder = assets.enumerated().map { $0.element.identifier }
            newVisible = assets.compactMap { return $0.visible ? $0.identifier : nil}
        }
        settings?.orderedAssetIds = newOrder
        settings?.visibleAssetIds = newVisible
        self.persistAssets()
    }
    
    func saveAssetList(_ list: [AssetInfo]) {
        self.assets = list

        Logger.shared.info("ASSETS UPDATE \(self.assets?.count)")
        var newOrder: [String] = []
        var newVisible: [String] = []
        if let assets = assets, assets.count > 0 {
            newOrder = assets.enumerated().map { $0.element.identifier }
            newVisible = assets.compactMap { return $0.visible ? $0.identifier : nil}
        }
        settings?.orderedAssetIds = newOrder
        settings?.visibleAssetIds = newVisible
        self.persistAssets()
    }

    private func persistAssets() {
        guard let account = accountSettings?.value,
              let updatedSettings = settings
        else {
            return
        }

        let updatedAccount = account.replacingSettings(updatedSettings)

        let saveOperation = accountRepository.saveOperation {
            [updatedAccount]
        } _: {
            []
        }

        saveOperation.completionBlock = { [weak self] in
            self?.accountSettings?.performSave(value: updatedAccount) { result in
                switch result {
                case let .success(account):
                    DispatchQueue.main.async {

                    }
                case .failure:
                    break
                }
            }
        }

        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        queue.addOperation(saveOperation)
    }

    func getAssetList() -> [AssetInfo]? {
        assets
    }
}
