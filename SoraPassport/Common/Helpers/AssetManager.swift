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
    /// The on-chain asset list of this session, read by the chain sync. It is
    /// empty until the list has been loaded; the chain sync then keeps the
    /// assets saved in the chain store. The list is loaded in the background
    /// and read on the chain sync's queue, so access is locked.
    static var networkAssets: [AssetInfo] {
        get {
            networkAssetsLock.lock()
            defer { networkAssetsLock.unlock() }
            return storedNetworkAssets
        }
        set {
            networkAssetsLock.lock()
            storedNetworkAssets = newValue
            networkAssetsLock.unlock()
        }
    }
    private static let networkAssetsLock = NSLock()
    private static var storedNetworkAssets: [AssetInfo] = []

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

        let updateClosure: ([DataProviderChange<ChainModel>]) -> Void = { [weak self] changes in
            self?.handle(changes: changes)
        }

        let failureClosure: (Swift.Error) -> Void = { _ in
            Logger.shared.error("Asset chain listener setup failed")
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
                self.updateChain(chain)
            case let .update(chain):
                guard chain.chainId == self.chainId else {
                    return
                }
                self.updateChain(chain)
            case let .delete(_):
                break
            }
        }
    }

    /// The first chain sync after an update can use an older asset whitelist than the
    /// live one; the live list arrives a moment later as a chain update. When the set of
    /// listed assets changes after `setup`, the asset list is rebuilt, so a token that was
    /// missing for a moment is listed again with the user's order and visibility.
    private func updateChain(_ chain: ChainModel) {
        let previousIds = Set(self.chain?.chainAssets.map(\.asset.assetId) ?? [])
        self.chain = chain
        let currentIds = Set(chain.chainAssets.map(\.asset.assetId))
        guard previousIds != currentIds else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.accountSettings != nil else {
                return
            }
            let chainAssets = self.chain?.chainAssets.map { $0.asset } ?? []
            self.updateWhitelisted(chainAssets)
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

    private static func defaultSort(_ a0: AssetInfo, _ a1: AssetInfo) -> Bool {
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
        let arranged = Self.arrangedAssets(list, settings: settings)
        self.assets = arranged
        updateAssetList(arranged)
    }

    /// The asset list in the user's order and with their visibility. Assets the user has
    /// not ordered yet follow; without any saved order, the default sort is used and only
    /// the wallet's own assets are visible.
    static func arrangedAssets(_ list: [AssetInfo], settings: AccountSettings?) -> [AssetInfo] {
        guard let order = settings?.orderedAssetIds, !order.isEmpty else {
            return list.sorted(by: defaultSort).map { asset in
                var item = asset
                item.visible = WalletAssetId(rawValue: item.assetId) != nil
                return item
            }
        }
        let ordered: [AssetInfo] = order.compactMap { identifier in
            guard var asset = list.first(where: { $0.identifier == identifier }) else {
                return nil
            }
            if let visibles = settings?.visibleAssetIds {
                asset.visible = visibles.contains(asset.identifier)
            }
            return asset
        }
        let orderedIds = ordered.map { $0.assetId }
        return ordered + list.filter { !orderedIds.contains($0.identifier) }
    }

    /// The order and visibility to save for `assets`. Ids the user had saved that are not
    /// in `assets` are kept, each after the id it followed: an asset can be missing for a
    /// while (an older whitelist on the first launch after an update, a whitelist outage,
    /// a chain that is not loaded yet), and the user's choice must outlive that.
    static func savedSelection(
        for assets: [AssetInfo],
        keeping previous: AccountSettings?
    ) -> (ordered: [String], visible: [String]) {
        var ordered: [String] = []
        var placed = Set<String>()
        for identifier in assets.map(\.identifier) where placed.insert(identifier).inserted {
            ordered.append(identifier)
        }
        let listed = placed

        // Walk the saved order; a missing id goes right after the id before it there.
        var predecessor: String?
        for identifier in previous?.orderedAssetIds ?? [] {
            if listed.contains(identifier) {
                predecessor = identifier
                continue
            }
            guard placed.insert(identifier).inserted else {
                continue
            }
            let position = predecessor.flatMap { ordered.firstIndex(of: $0) }.map { $0 + 1 } ?? 0
            ordered.insert(identifier, at: position)
            predecessor = identifier
        }

        var visible = assets.filter(\.visible).map(\.identifier)
        var shown = Set(visible)
        for identifier in previous?.visibleAssetIds ?? []
        where !listed.contains(identifier) && shown.insert(identifier).inserted {
            visible.append(identifier)
        }
        return (ordered, visible)
    }

    func updateAssetList(_ list: [AssetInfo]) {
        Logger.shared.info("ASSETS UPDATE \(self.assets?.count)")
        saveSelection(of: assets ?? [])
    }

    func saveAssetList(_ list: [AssetInfo]) {
        self.assets = list

        Logger.shared.info("ASSETS UPDATE \(self.assets?.count)")
        saveSelection(of: list)
    }

    private func saveSelection(of assets: [AssetInfo]) {
        let selection = Self.savedSelection(for: assets, keeping: settings)
        settings?.orderedAssetIds = selection.ordered
        settings?.visibleAssetIds = selection.visible
        self.persistAssets()
    }

    private func persistAssets() {
        guard let account = accountSettings?.value,
              let updatedSettings = settings
        else {
            return
        }

        accountSettings?.performUpdateAssetSettings(
            account: account,
            settings: updatedSettings
        ) { result in
            if case .failure = result {
                Logger.shared.error("Unable to persist account asset settings")
            }
        }
    }

    func getAssetList() -> [AssetInfo]? {
        assets
    }
}
