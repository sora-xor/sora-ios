import BigInt
import Foundation
import SSFExtrinsicKit
import SSFModels

// sourcery: AutoMockable
protocol XcmExtrinsicBuilderProtocol {
    func buildReserveNativeTokenExtrinsicBuilderClosure(
        version: XcmCallFactoryVersion,
        fromChainModel: ChainModel,
        destChainModel: ChainModel,
        destAccountId: AccountId,
        amount: BigUInt,
        weightLimit: BigUInt?,
        path: XcmCallPath
    ) -> ExtrinsicBuilderClosure

    func buildXTokensTransferExtrinsicBuilderClosure(
        version: XcmCallFactoryVersion,
        accountId: AccountId?,
        currencyId: CurrencyId,
        destChainModel: ChainModel,
        amount: BigUInt,
        weightLimit: BigUInt,
        path: XcmCallPath
    ) -> ExtrinsicBuilderClosure

    func buildXTokensTransferMultiassetExtrinsicBuilderClosure(
        assetSymbol: String,
        version: XcmCallFactoryVersion,
        accountId: AccountId?,
        fromChainModel: ChainModel,
        destChainModel: ChainModel,
        amount: BigUInt,
        weightLimit: BigUInt,
        path: XcmCallPath,
        destWeightIsPrimitive: Bool?
    ) async throws -> ExtrinsicBuilderClosure

    func buildPolkadotXcmLimitedReserveTransferAssetsExtrinsicBuilderClosure(
        fromChainModel: ChainModel,
        version: XcmCallFactoryVersion,
        assetSymbol: String,
        accountId: AccountId?,
        destChainModel: ChainModel,
        amount: BigUInt,
        weightLimit: BigUInt,
        path: XcmCallPath
    ) async throws -> ExtrinsicBuilderClosure

    func buildBridgeProxyBurn(
        fromChainModel: ChainModel,
        currencyId: String,
        destChainModel: ChainModel,
        accountId: AccountId?,
        amount: BigUInt,
        path: XcmCallPath
    ) throws -> ExtrinsicBuilderClosure
}

final class XcmExtrinsicBuilder: XcmExtrinsicBuilderProtocol {
    private var callFactory: XcmCallFactoryProtocol

    public init(callFactory: XcmCallFactoryProtocol? = nil) {
        self.callFactory = callFactory ?? XcmCallFactory()
    }

    // MARK: - Public methods

    func buildReserveNativeTokenExtrinsicBuilderClosure(
        version: XcmCallFactoryVersion,
        fromChainModel: ChainModel,
        destChainModel: ChainModel,
        destAccountId: AccountId,
        amount: BigUInt,
        weightLimit: BigUInt?,
        path: XcmCallPath
    ) -> ExtrinsicBuilderClosure {
        let call = callFactory.reserveNativeToken(
            version: version,
            fromChainModel: fromChainModel,
            destChainModel: destChainModel,
            destAccountId: destAccountId,
            amount: amount,
            weightLimit: weightLimit,
            path: path
        )

        return { builder in
            try builder.adding(call: call)
        }
    }

    func buildXTokensTransferExtrinsicBuilderClosure(
        version: XcmCallFactoryVersion,
        accountId: AccountId?,
        currencyId: CurrencyId,
        destChainModel: ChainModel,
        amount: BigUInt,
        weightLimit: BigUInt,
        path: XcmCallPath
    ) -> ExtrinsicBuilderClosure {
        let call = callFactory.xTokensTransfer(
            version: version,
            accountId: accountId,
            currencyId: currencyId,
            destChainModel: destChainModel,
            amount: amount,
            weightLimit: weightLimit,
            path: path
        )

        return { builder in
            try builder.adding(call: call)
        }
    }

    func buildXTokensTransferMultiassetExtrinsicBuilderClosure(
        assetSymbol: String,
        version: XcmCallFactoryVersion,
        accountId: AccountId?,
        fromChainModel: ChainModel,
        destChainModel: ChainModel,
        amount: BigUInt,
        weightLimit: BigUInt,
        path: XcmCallPath,
        destWeightIsPrimitive: Bool?
    ) async throws -> ExtrinsicBuilderClosure {
        let call = try await callFactory.xTokensTransferMultiasset(
            version: version,
            assetSymbol: assetSymbol,
            accountId: accountId,
            fromChainModel: fromChainModel,
            destChainModel: destChainModel,
            amount: amount,
            weightLimit: weightLimit,
            path: path,
            destWeightIsPrimitive: destWeightIsPrimitive
        )

        return { builder in
            try builder.adding(call: call)
        }
    }

    func buildPolkadotXcmLimitedReserveTransferAssetsExtrinsicBuilderClosure(
        fromChainModel: ChainModel,
        version: XcmCallFactoryVersion,
        assetSymbol: String,
        accountId: AccountId?,
        destChainModel: ChainModel,
        amount: BigUInt,
        weightLimit: BigUInt,
        path: XcmCallPath
    ) async throws -> ExtrinsicBuilderClosure {
        let call = try await callFactory.polkadotXcmLimitedReserveTransferAssets(
            fromChainModel: fromChainModel,
            version: version,
            assetSymbol: assetSymbol,
            accountId: accountId,
            destChainModel: destChainModel,
            amount: amount,
            weightLimit: weightLimit,
            path: path
        )

        return { builder in
            try builder.adding(call: call)
        }
    }

    func buildBridgeProxyBurn(
        fromChainModel: ChainModel,
        currencyId: String,
        destChainModel: ChainModel,
        accountId: AccountId?,
        amount: BigUInt,
        path: XcmCallPath
    ) throws -> ExtrinsicBuilderClosure {
        let call = callFactory.bridgeProxyBurn(
            fromChainModel: fromChainModel,
            currencyId: currencyId,
            destChainModel: destChainModel,
            accountId: accountId,
            amount: amount,
            path: path
        )

        return { builder in
            try builder.adding(call: call)
        }
    }
}
