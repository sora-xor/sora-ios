import BigInt
import Foundation
import SSFModels
import SSFNetwork
import SSFUtils

// sourcery: AutoMockable
protocol XcmCallFactoryProtocol {
    func reserveNativeToken(
        version: XcmCallFactoryVersion,
        fromChainModel: ChainModel,
        destChainModel: ChainModel,
        destAccountId: AccountId,
        amount: BigUInt,
        weightLimit: BigUInt?,
        path: XcmCallPath
    ) -> RuntimeCall<ReserveTransferAssetsCall>

    func xTokensTransfer(
        version: XcmCallFactoryVersion,
        accountId: AccountId?,
        currencyId: CurrencyId,
        destChainModel: ChainModel,
        amount: BigUInt,
        weightLimit: BigUInt,
        path: XcmCallPath
    ) -> RuntimeCall<XTokensTransferCall>

    func xTokensTransferMultiasset(
        version: XcmCallFactoryVersion,
        assetSymbol: String,
        accountId: AccountId?,
        fromChainModel: ChainModel,
        destChainModel: ChainModel,
        amount: BigUInt,
        weightLimit: BigUInt,
        path: XcmCallPath,
        destWeightIsPrimitive: Bool?
    ) async throws -> RuntimeCall<XTokensTransferMultiassetCall>

    func polkadotXcmLimitedReserveTransferAssets(
        fromChainModel: ChainModel,
        version: XcmCallFactoryVersion,
        assetSymbol: String,
        accountId: AccountId?,
        destChainModel: ChainModel,
        amount: BigUInt,
        weightLimit: BigUInt,
        path: XcmCallPath
    ) async throws -> RuntimeCall<ReserveTransferAssetsCall>

    func bridgeProxyBurn(
        fromChainModel: ChainModel,
        currencyId: String,
        destChainModel: ChainModel,
        accountId: AccountId?,
        amount: BigUInt,
        path: XcmCallPath
    ) -> RuntimeCall<BridgeProxyBurnCall>
}

final class XcmCallFactory: XcmCallFactoryProtocol {
    private let assetMultilocationFetcher: XcmAssetMultilocationFetching

    init(assetMultilocationFetcher: XcmAssetMultilocationFetching? = nil) {
        self.assetMultilocationFetcher = assetMultilocationFetcher ??
            XcmAssetMultilocationFetcher(
                sourceUrl: XcmConfig.shared.tokenLocationsSourceUrl,
                dataFetchFactory: NetworkOperationFactory(),
                retryStrategy: ExponentialReconnection(),
                operationQueue: OperationQueue()
            )
    }

    // MARK: - Public methods

    func reserveNativeToken(
        version: XcmCallFactoryVersion,
        fromChainModel _: ChainModel,
        destChainModel: ChainModel,
        destAccountId: AccountId,
        amount: BigUInt,
        weightLimit: BigUInt?,
        path: XcmCallPath
    ) -> RuntimeCall<ReserveTransferAssetsCall> {
        let destParachainId = UInt32(destChainModel.paraId ?? "")
        let destParents: UInt8 = destChainModel.isRelaychain ? 1 : 0
        let destination = createVersionedMultiLocation(
            version: version,
            chainModel: destChainModel,
            parachainId: destParachainId,
            accountId: nil,
            parents: destParents
        )

        let beneficiary = createVersionedMultiLocation(
            version: version,
            chainModel: destChainModel,
            parachainId: nil,
            accountId: destAccountId,
            parents: 0
        )

        let assetsParents: UInt8 = destChainModel.isRelaychain ? 1 : 0
        let assets = createVersionedMultiAssets(
            version: version,
            chainModel: destChainModel,
            amount: amount,
            parachainId: nil,
            accountId: nil,
            parents: assetsParents,
            generalKey: nil
        )

        let weightLimit = createWeight(version: version, weightLimit: weightLimit)

        let args = ReserveTransferAssetsCall(
            destination: destination,
            beneficiary: beneficiary,
            assets: assets,
            weightLimit: weightLimit,
            feeAssetItem: 0
        )

        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.itemName,
            args: args
        )
    }

    func xTokensTransfer(
        version: XcmCallFactoryVersion,
        accountId: AccountId?,
        currencyId: CurrencyId,
        destChainModel: ChainModel,
        amount: BigUInt,
        weightLimit: BigUInt,
        path: XcmCallPath
    ) -> RuntimeCall<XTokensTransferCall> {
        let destParachainId = UInt32(destChainModel.paraId ?? "")
        let destParents: UInt8 = destChainModel.isRelaychain ? 1 : 0
        let destination = createVersionedMultiLocation(
            version: version,
            chainModel: destChainModel,
            parachainId: destParachainId,
            accountId: accountId,
            parents: destParents
        )

        let weightLimit = createWeight(version: version, weightLimit: weightLimit)

        let args = XTokensTransferCall(
            currencyId: currencyId,
            amount: amount,
            dest: destination,
            destWeightLimit: weightLimit
        )

        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.itemName,
            args: args
        )
    }

    func xTokensTransferMultiasset(
        version: XcmCallFactoryVersion,
        assetSymbol: String,
        accountId: AccountId?,
        fromChainModel: ChainModel,
        destChainModel: ChainModel,
        amount: BigUInt,
        weightLimit: BigUInt,
        path: XcmCallPath,
        destWeightIsPrimitive: Bool?
    ) async throws -> RuntimeCall<XTokensTransferMultiassetCall> {
        guard let originAssetId = fromChainModel.xcm?.availableAssets
            .first(where: { $0.symbol.lowercased() == assetSymbol.lowercased() })?.id else
        {
            throw XcmError.noAvailableXcmAsset(symbol: assetSymbol)
        }
        let multilocation = try await assetMultilocationFetcher.versionedMultilocation(
            originAssetId: originAssetId,
            destChainId: destChainModel.parentId ?? destChainModel.chainId
        )

        let remoteAsset = try createRemoteVersionedMultiasset(
            with: multilocation,
            version: version,
            amount: amount
        )

        let destParachainId = UInt32(destChainModel.paraId ?? "")
        let destination = createVersionedMultiLocation(
            version: version,
            chainModel: destChainModel,
            parachainId: destParachainId,
            accountId: accountId,
            parents: 1
        )

        let destWeightLimit = createWeight(
            version: version,
            weightLimit: weightLimit
        )

        let args = XTokensTransferMultiassetCall(
            asset: remoteAsset,
            dest: destination,
            destWeightLimit: destWeightLimit,
            destWeightIsPrimitive: destWeightIsPrimitive,
            destWeight: weightLimit
        )

        let runtimeCall = RuntimeCall(
            moduleName: path.moduleName,
            callName: path.itemName,
            args: args
        )
        return runtimeCall
    }

    func polkadotXcmLimitedReserveTransferAssets(
        fromChainModel: ChainModel,
        version: XcmCallFactoryVersion,
        assetSymbol: String,
        accountId: AccountId?,
        destChainModel: ChainModel,
        amount: BigUInt,
        weightLimit: BigUInt,
        path: XcmCallPath
    ) async throws -> RuntimeCall<ReserveTransferAssetsCall> {
        guard let originAssetId = fromChainModel.xcm?.availableAssets
            .first(where: { $0.symbol.lowercased() == assetSymbol.lowercased() })?.id else
        {
            throw XcmError.noAvailableXcmAsset(symbol: assetSymbol)
        }
        let multilocation = try await assetMultilocationFetcher.versionedMultilocation(
            originAssetId: originAssetId,
            destChainId: destChainModel.parentId ?? destChainModel.chainId
        )

        let remoteAsset = createRemoteVersionedMultiassets(
            with: multilocation,
            version: version,
            amount: amount
        )

        let destParachainId = UInt32(destChainModel.paraId ?? "")
        let destination = createVersionedMultiLocation(
            version: version,
            chainModel: destChainModel,
            parachainId: destParachainId,
            accountId: nil,
            parents: 1
        )

        let beneficiary = createVersionedMultiLocation(
            version: version,
            chainModel: destChainModel,
            parachainId: nil,
            accountId: accountId,
            parents: 0
        )

        let destWeightLimit = createWeight(
            version: version,
            weightLimit: weightLimit
        )

        let args = ReserveTransferAssetsCall(
            destination: destination,
            beneficiary: beneficiary,
            assets: remoteAsset,
            weightLimit: destWeightLimit,
            feeAssetItem: 0
        )

        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.itemName,
            args: args
        )
    }

    func bridgeProxyBurn(
        fromChainModel _: ChainModel,
        currencyId: String,
        destChainModel: ChainModel,
        accountId: AccountId?,
        amount: BigUInt,
        path: XcmCallPath
    ) -> RuntimeCall<BridgeProxyBurnCall> {
        let networkId = BridgeTypesGenericNetworkId(from: destChainModel)
        let assetId = SoraAssetId(wrappedValue: currencyId)

        let destParachainId = UInt32(destChainModel.paraId ?? "")
        let destParents: UInt8 = destChainModel.isRelaychain ? 1 : 0
        let destination = createVersionedMultiLocation(
            version: .V3,
            chainModel: destChainModel,
            parachainId: destParachainId,
            accountId: accountId,
            parents: destParents
        )
        let recipient = BridgeTypesGenericAccount.parachain(destination)

        let args = BridgeProxyBurnCall(
            networkId: networkId,
            assetId: assetId,
            recipient: recipient,
            amount: amount
        )

        return RuntimeCall(
            moduleName: path.moduleName,
            callName: path.itemName,
            args: args
        )
    }

    // MARK: - Private methods

    // MARK: - XcmVersionedMultiLocation

    private func createVersionedMultiLocation(
        version: XcmCallFactoryVersion,
        chainModel: ChainModel,
        parachainId: ParaId?,
        accountId: AccountId?,
        parents: UInt8
    ) -> XcmVersionedMultiLocation {
        let multiLocation = createMultiLocation(
            version: version,
            chainModel: chainModel,
            parachainId: parachainId,
            accountId: accountId,
            parents: parents,
            generalKey: nil
        )

        let versionedMultiLocation: XcmVersionedMultiLocation
        switch version {
        case .V1:
            versionedMultiLocation = .V1(multiLocation)
        case .V3:
            versionedMultiLocation = .V3(multiLocation)
        }

        return versionedMultiLocation
    }

    private func createMultiLocation(
        version: XcmCallFactoryVersion,
        chainModel: ChainModel,
        parachainId: ParaId?,
        accountId: AccountId?,
        parents: UInt8,
        generalKey: Data?
    ) -> XcmV1MultiLocation {
        let interior = createMultilocationJunctions(
            version: version,
            chainModel: chainModel,
            parachainId: parachainId,
            accountId: accountId,
            generalKey: generalKey
        )
        let multiLocation = XcmV1MultiLocation(
            parents: parents,
            interior: interior
        )
        return multiLocation
    }

    private func createMultilocationJunctions(
        version: XcmCallFactoryVersion,
        chainModel: ChainModel,
        parachainId: ParaId?,
        accountId: AccountId?,
        generalKey: Data?
    ) -> XcmV1MultilocationJunctions {
        let items = createJunctions(
            version: version,
            chainModel: chainModel,
            parachainId: parachainId,
            accountId: accountId,
            generalKey: generalKey
        )
        return XcmV1MultilocationJunctions(items: items)
    }

    private func createJunctions(
        version: XcmCallFactoryVersion,
        chainModel: ChainModel,
        parachainId: ParaId?,
        accountId: AccountId?,
        generalKey: Data?
    ) -> [XcmJunction] {
        let accountIdJunction = createAccountJunction(
            version: version,
            accountId: accountId,
            isEthereumBased: chainModel.isEthereumBased,
            chainModel: chainModel
        )

        let parachainJunction = parachainId.map {
            XcmJunction.parachain($0)
        }

        let generalKeyJunction = generalKey.map {
            XcmJunction.generalKey($0)
        }

        let items: [XcmJunction] = [
            parachainJunction,
            accountIdJunction,
            generalKeyJunction,
        ].compactMap { $0 }
        return items
    }

    private func createAccountJunction(
        version: XcmCallFactoryVersion,
        accountId: AccountId?,
        isEthereumBased: Bool,
        chainModel: ChainModel
    ) -> XcmJunction? {
        switch version {
        case .V1:
            let accountIdJunction = accountId.map {
                if isEthereumBased {
                    let accountIdValue = AccountId20Value(network: .any, key: $0)
                    return XcmJunction.accountKey20(accountIdValue)
                } else {
                    let accountIdValue = AccountId32Value(network: .any, accountId: $0)
                    return XcmJunction.accountId32(accountIdValue)
                }
            }
            return accountIdJunction
        case .V3:
            let accountIdJunction = accountId.map {
                let network = XcmJunctionNetworkId
                    .from(ecosystem: ChainEcosystem.defineEcosystem(chain: chainModel))
                if isEthereumBased {
                    let accountIdValue = AccountId20Value(network: network, key: $0)
                    return XcmJunction.accountKey20(accountIdValue)
                } else {
                    let accountIdValue = AccountId32Value(network: network, accountId: $0)
                    return XcmJunction.accountId32(accountIdValue)
                }
            }
            return accountIdJunction
        }
    }

    // MARK: - XcmVersionedMultiAssets

    private func createVersionedMultiAssets(
        version: XcmCallFactoryVersion,
        chainModel: ChainModel,
        amount: BigUInt,
        parachainId: ParaId?,
        accountId: AccountId?,
        parents: UInt8,
        generalKey: Data?
    ) -> XcmVersionedMultiAssets {
        let assets = createMultiAssets(
            version: version,
            chainModel: chainModel,
            amount: amount,
            parachainId: parachainId,
            accountId: accountId,
            parents: parents,
            generalKey: generalKey
        )

        switch version {
        case .V1:
            return XcmVersionedMultiAssets.V1(assets)
        case .V3:
            return XcmVersionedMultiAssets.V3(assets)
        }
    }

    private func createMultiAssets(
        version: XcmCallFactoryVersion,
        chainModel: ChainModel,
        amount: BigUInt,
        parachainId: ParaId?,
        accountId: AccountId?,
        parents: UInt8,
        generalKey: Data?
    ) -> [XcmV1MultiAsset] {
        let multilocation = createMultiLocation(
            version: version,
            chainModel: chainModel,
            parachainId: parachainId,
            accountId: accountId,
            parents: parents,
            generalKey: generalKey
        )

        return [XcmV1MultiAsset(multilocation: multilocation, amount: amount)]
    }

    // MARK: - XcmVersionedMultiAsset

    private func createVersionedMultiAsset(
        version: XcmCallFactoryVersion,
        chainModel: ChainModel,
        amount: BigUInt,
        parachainId: ParaId?,
        accountId: AccountId?,
        parents: UInt8,
        generalKey: Data?
    ) -> XcmVersionedMultiAsset {
        let asset = createMultiAsset(
            version: version,
            chainModel: chainModel,
            amount: amount,
            parachainId: parachainId,
            accountId: accountId,
            parents: parents,
            generalKey: generalKey
        )

        switch version {
        case .V1:
            return XcmVersionedMultiAsset.V1(asset)
        case .V3:
            return XcmVersionedMultiAsset.V3(asset)
        }
    }

    private func createMultiAsset(
        version: XcmCallFactoryVersion,
        chainModel: ChainModel,
        amount: BigUInt,
        parachainId: ParaId?,
        accountId: AccountId?,
        parents: UInt8,
        generalKey: Data?
    ) -> XcmV1MultiAsset {
        let multilocation = createMultiLocation(
            version: version,
            chainModel: chainModel,
            parachainId: parachainId,
            accountId: accountId,
            parents: parents,
            generalKey: generalKey
        )

        return XcmV1MultiAsset(multilocation: multilocation, amount: amount)
    }

    // MARK: - from remote

    private func createRemoteVersionedMultiasset(
        with remote: AssetMultilocation,
        version: XcmCallFactoryVersion,
        amount: BigUInt
    ) throws -> XcmVersionedMultiAsset {
        let interior: XcmV1MultilocationJunctions = .init(items: remote.interiors)
        let parents: UInt8 = (
            interior.items.isEmpty || interior.items
                .contains(where: { $0.isParachain() })
        ) ? 1 : 0

        let multilocation = XcmV1MultiLocation(
            parents: parents,
            interior: interior
        )

        let asset = XcmV1MultiAsset(
            multilocation: multilocation,
            amount: amount
        )

        switch version {
        case .V1:
            return XcmVersionedMultiAsset.V1(asset)
        case .V3:
            return XcmVersionedMultiAsset.V3(asset)
        }
    }

    private func generateV3Junctions(from junctions: [XcmJunction]) -> [XcmJunction] {
        junctions.map {
            guard case let .generalKey(key) = $0 else {
                return $0
            }
            var v3Key = key
            while v3Key.count < 64 {
                v3Key.append(Data("0".utf8))
            }
            let keyV3 = GeneralKeyV3(
                lengh: 2,
                data: v3Key
            )
            return .generalKeyV3(keyV3)
        }
    }

    private func createRemoteVersionedMultiassets(
        with remote: AssetMultilocation,
        version: XcmCallFactoryVersion,
        amount: BigUInt
    ) -> XcmVersionedMultiAssets {
        let interior: XcmV1MultilocationJunctions = .init(items: remote.interiors)
        let parents: UInt8 = (
            interior.items.isEmpty || interior.items
                .contains(where: { $0.isParachain() })
        ) ? 1 : 0

        let multilocation = XcmV1MultiLocation(
            parents: parents,
            interior: interior
        )

        let asset = XcmV1MultiAsset(
            multilocation: multilocation,
            amount: amount
        )

        switch version {
        case .V1:
            return XcmVersionedMultiAssets.V1([asset])
        case .V3:
            return XcmVersionedMultiAssets.V3([asset])
        }
    }

    // MARK: - Weight

    private func createWeight(
        version: XcmCallFactoryVersion,
        weightLimit: BigUInt?
    ) -> XcmWeightLimit? {
        switch version {
        case .V1:
            guard let weightLimit = weightLimit else {
                return nil
            }
            return XcmWeightLimit.limited(weight: weightLimit)
        case .V3:
            guard let weightLimit = weightLimit else {
                return nil
            }
            let proofSize = BigUInt(128 * 1024)
            let weight = SpWeightsWeightV3Weight(refTime: weightLimit, proofSize: proofSize)
            return XcmWeightLimit.limitedV3(weight: weight)
        }
    }
}
