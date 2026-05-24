import BigInt
import Foundation
import RobinHood
import SSFChainRegistry
import SSFCrypto
import SSFExtrinsicKit
import SSFModels
import SSFRuntimeCodingService
import SSFSigner
import SSFUtils

public protocol XcmExtrinsicServiceProtocol {
    func transfer(
        fromChainId: String,
        assetSymbol: String,
        destChainId: String,
        destAccountId: AccountId,
        amount: BigUInt
    ) async -> SubmitExtrinsicResult

    func estimateOriginalFee(
        fromChainId: String,
        assetSymbol: String,
        destChainId: String,
        destAccountId: AccountId,
        amount: BigUInt
    ) async -> FeeExtrinsicResult
}

final class XcmExtrinsicService: XcmExtrinsicServiceProtocol {
    private let extrinsicBuilder: XcmExtrinsicBuilderProtocol
    private let signingWrapper: TransactionSignerProtocol
    private let xcmVersionFetcher: XcmVersionFetching
    private let chainRegistry: ChainRegistryProtocol
    private let depsContainer: XcmDependencyContainerProtocol
    private let callPathDeterminer: CallPathDeterminer
    private let xcmFeeFetcher: XcmDestinationFeeFetching

    init(
        signingWrapper: TransactionSignerProtocol,
        extrinsicBuilder: XcmExtrinsicBuilderProtocol,
        xcmVersionFetcher: XcmVersionFetching,
        chainRegistry: ChainRegistryProtocol,
        depsContainer: XcmDependencyContainerProtocol,
        callPathDeterminer: CallPathDeterminer,
        xcmFeeFetcher: XcmDestinationFeeFetching
    ) {
        self.signingWrapper = signingWrapper
        self.extrinsicBuilder = extrinsicBuilder
        self.xcmVersionFetcher = xcmVersionFetcher
        self.chainRegistry = chainRegistry
        self.depsContainer = depsContainer
        self.callPathDeterminer = callPathDeterminer
        self.xcmFeeFetcher = xcmFeeFetcher
    }

    // MARK: - Public methods

    func estimateOriginalFee(
        fromChainId: String,
        assetSymbol: String,
        destChainId: String,
        destAccountId: AccountId,
        amount: BigUInt
    ) async -> FeeExtrinsicResult {
        do {
            let fromChainModel = try await chainRegistry.getChain(for: fromChainId)
            var destChainModel = try await chainRegistry.getChain(for: destChainId)
            let fromChainType = try XcmChainType.determineChainType(for: fromChainModel)
            let destChainType = try XcmChainType.determineChainType(for: destChainModel)
            let callPath = try await callPathDeterminer.determineCallPath(
                from: fromChainType,
                dest: destChainType
            )
            let xcmWeight = try await xcmFeeFetcher.estimateWeight(for: destChainId)

            switch callPath {
            case .xcmPalletLimitedTeleportAssets:
                return try await estimateNativeTokenTransferFee(
                    with: callPath,
                    fromChainModel: fromChainModel,
                    destChainModel: destChainModel,
                    destAccountId: destAccountId,
                    amount: amount,
                    weightLimit: xcmWeight
                )
            case
                .xcmPalletLimitedReserveTransferAssets,
                .polkadotXcmLimitedTeleportAssets:
                if destChainType == .soraMainnet {
                    guard let bridgeParachainId = fromChainModel.xcm?.availableDestinations
                        .first(where: { $0.chainId == destChainId })?.bridgeParachainId else
                    {
                        throw XcmError.convenience(error: "missing bridgeParachainId")
                    }
                    let soraParachainModel = try await chainRegistry
                        .getChain(for: bridgeParachainId)
                    destChainModel = soraParachainModel
                }
                return try await estimateNativeTokenTransferFee(
                    with: callPath,
                    fromChainModel: fromChainModel,
                    destChainModel: destChainModel,
                    destAccountId: destAccountId,
                    amount: amount,
                    weightLimit: xcmWeight
                )
            case .xTokensTransferMultiasset:
                return try await estimateXTokensTransferMultiassetFee(
                    fromChainModel: fromChainModel,
                    assetSymbol: assetSymbol.dropXcPrefix(chain: fromChainModel),
                    accountId: destAccountId,
                    destChainModel: destChainModel,
                    amount: amount,
                    weightLimit: xcmWeight,
                    path: callPath
                )
            case
                .polkadotXcmLimitedReserveTransferAssets,
                .polkadotXcmLimitedReserveWithdrawAssets:
                return try await estimatePolkadotXcmLimitedReserveTransferAssetsFee(
                    fromChainModel: fromChainModel,
                    assetSymbol: assetSymbol.dropXcPrefix(chain: fromChainModel),
                    accountId: destAccountId,
                    destChainModel: destChainModel,
                    amount: amount,
                    weightLimit: xcmWeight,
                    path: callPath
                )
            case .bridgeProxyBurn:
                return try await estimateBridgeProxyBurn(
                    fromChainModel: fromChainModel,
                    currencyId: "",
                    destChainModel: destChainModel,
                    accountId: destAccountId,
                    amount: amount,
                    path: callPath
                )
            default:
                throw XcmError.caseNotProcessed
            }
        } catch {
            return .failure(error)
        }
    }

    public func transfer(
        fromChainId: String,
        assetSymbol: String,
        destChainId: String,
        destAccountId: AccountId,
        amount: BigUInt
    ) async -> SubmitExtrinsicResult {
        do {
            let fromChainModel = try await chainRegistry.getChain(for: fromChainId)
            var destChainModel = try await chainRegistry.getChain(for: destChainId)
            let fromChainType = try XcmChainType.determineChainType(for: fromChainModel)
            let destChainType = try XcmChainType.determineChainType(for: destChainModel)
            let callPath = try await callPathDeterminer.determineCallPath(
                from: fromChainType,
                dest: destChainType
            )
            let xcmWeight = try await xcmFeeFetcher.estimateWeight(for: destChainId)

            switch callPath {
            case .xcmPalletLimitedTeleportAssets:
                return try await submitNativeTokenTransfer(
                    with: callPath,
                    fromChainModel: fromChainModel,
                    destChainModel: destChainModel,
                    destAccountId: destAccountId,
                    amount: amount,
                    weightLimit: xcmWeight
                )
            case
                .xcmPalletLimitedReserveTransferAssets,
                .polkadotXcmLimitedTeleportAssets:
                if destChainType == .soraMainnet {
                    guard let bridgeParachainId = fromChainModel.xcm?.availableDestinations
                        .first(where: { $0.chainId == destChainId })?.bridgeParachainId else
                    {
                        throw XcmError.convenience(error: "missing bridgeParachainId")
                    }
                    let soraParachainModel = try await chainRegistry
                        .getChain(for: bridgeParachainId)
                    destChainModel = soraParachainModel
                }
                return try await submitNativeTokenTransfer(
                    with: callPath,
                    fromChainModel: fromChainModel,
                    destChainModel: destChainModel,
                    destAccountId: destAccountId,
                    amount: amount,
                    weightLimit: xcmWeight
                )
            case .xTokensTransferMultiasset:
                return try await submitXTokensTransferMultiasset(
                    fromChainModel: fromChainModel,
                    assetSymbol: assetSymbol.dropXcPrefix(chain: fromChainModel),
                    accountId: destAccountId,
                    destChainModel: destChainModel,
                    amount: amount,
                    weightLimit: xcmWeight,
                    path: callPath
                )
            case
                .polkadotXcmLimitedReserveTransferAssets,
                .polkadotXcmLimitedReserveWithdrawAssets:
                return try await submitPolkadotXcmLimitedReserveTransferAssetsExtrinsic(
                    fromChainModel: fromChainModel,
                    assetSymbol: assetSymbol.dropXcPrefix(chain: fromChainModel),
                    accountId: destAccountId,
                    destChainModel: destChainModel,
                    amount: amount,
                    weightLimit: xcmWeight,
                    path: callPath
                )
            case .bridgeProxyBurn:
                return try await submitBridgeProxyBurn(
                    fromChainModel: fromChainModel,
                    currencyId: "",
                    destChainModel: destChainModel,
                    accountId: destAccountId,
                    amount: amount,
                    path: callPath
                )
            default:
                throw XcmError.caseNotProcessed
            }
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Private methods

    // MARK: - Extrinsic building

    private func makeNativeTokenTransferExtrinsic(
        with path: XcmCallPath,
        fromChainModel: ChainModel,
        destChainModel: ChainModel,
        destAccountId: AccountId,
        amount: BigUInt,
        weightLimit: BigUInt?
    ) async throws -> ExtrinsicBuilderClosure {
        let version = try await xcmVersionFetcher.getVersion(for: fromChainModel.chainId)
        return extrinsicBuilder.buildReserveNativeTokenExtrinsicBuilderClosure(
            version: version,
            fromChainModel: fromChainModel,
            destChainModel: destChainModel,
            destAccountId: destAccountId,
            amount: amount,
            weightLimit: weightLimit,
            path: path
        )
    }

    private func makeXTokensTransferExtrinsic(
        fromChainModelId: ChainModel.Id,
        accountId: AccountId?,
        currencyId: CurrencyId,
        destChainModel: ChainModel,
        amount: BigUInt,
        weightLimit: BigUInt,
        path: XcmCallPath
    ) async throws -> ExtrinsicBuilderClosure {
        let version = try await xcmVersionFetcher.getVersion(for: fromChainModelId)
        return extrinsicBuilder
            .buildXTokensTransferExtrinsicBuilderClosure(
                version: version,
                accountId: accountId,
                currencyId: currencyId,
                destChainModel: destChainModel,
                amount: amount,
                weightLimit: weightLimit,
                path: path
            )
    }

    private func makeXTokensTransferMultiassetExtrinsic(
        fromChainModel: ChainModel,
        assetSymbol: String,
        accountId: AccountId?,
        destChainModel: ChainModel,
        amount: BigUInt,
        weightLimit: BigUInt,
        path: XcmCallPath
    ) async throws -> ExtrinsicBuilderClosure {
        let version = try await xcmVersionFetcher.getVersion(for: fromChainModel.chainId)
        return try await extrinsicBuilder
            .buildXTokensTransferMultiassetExtrinsicBuilderClosure(
                assetSymbol: assetSymbol,
                version: version,
                accountId: accountId,
                fromChainModel: fromChainModel,
                destChainModel: destChainModel,
                amount: amount,
                weightLimit: weightLimit,
                path: path,
                destWeightIsPrimitive: fromChainModel.xcm?.destWeightIsPrimitive
            )
    }

    private func makePolkadotXcmLimitedReserveTransferAssetsExtrinsic(
        fromChainModel: ChainModel,
        assetSymbol: String,
        accountId: AccountId?,
        destChainModel: ChainModel,
        amount: BigUInt,
        weightLimit: BigUInt,
        path: XcmCallPath
    ) async throws -> ExtrinsicBuilderClosure {
        let version = try await xcmVersionFetcher.getVersion(for: fromChainModel.chainId)
        return try await extrinsicBuilder
            .buildPolkadotXcmLimitedReserveTransferAssetsExtrinsicBuilderClosure(
                fromChainModel: fromChainModel,
                version: version,
                assetSymbol: assetSymbol,
                accountId: accountId,
                destChainModel: destChainModel,
                amount: amount,
                weightLimit: weightLimit,
                path: path
            )
    }

    private func makeBridgeProxyBurnExtrinsic(
        fromChainModel: ChainModel,
        currencyId: String,
        destChainModel: ChainModel,
        accountId: AccountId?,
        amount: BigUInt,
        path: XcmCallPath
    ) throws -> ExtrinsicBuilderClosure {
        try extrinsicBuilder.buildBridgeProxyBurn(
            fromChainModel: fromChainModel,
            currencyId: currencyId,
            destChainModel: destChainModel,
            accountId: accountId,
            amount: amount,
            path: path
        )
    }

    // MARK: - Submits

    private func submitNativeTokenTransfer(
        with path: XcmCallPath,
        fromChainModel: ChainModel,
        destChainModel: ChainModel,
        destAccountId: AccountId,
        amount: BigUInt,
        weightLimit: BigUInt?
    ) async throws -> SubmitExtrinsicResult {
        let extrinsic = try await makeNativeTokenTransferExtrinsic(
            with: path,
            fromChainModel: fromChainModel,
            destChainModel: destChainModel,
            destAccountId: destAccountId,
            amount: amount,
            weightLimit: weightLimit
        )

        let extrinsicService = try await depsContainer.prepareDeps().extrinsicService

        return await withCheckedContinuation { continuation in
            extrinsicService.submit(
                extrinsic,
                signer: signingWrapper,
                runningIn: .global()
            ) { result in
                continuation.resume(returning: result)
            }
        }
    }

    private func submitXTokensTransfer(
        fromChainModelId: ChainModel.Id,
        accountId: AccountId?,
        currencyId: CurrencyId,
        destChainModel: ChainModel,
        amount: BigUInt,
        weightLimit: BigUInt,
        path: XcmCallPath
    ) async throws -> SubmitExtrinsicResult {
        let extrinsic = try await makeXTokensTransferExtrinsic(
            fromChainModelId: fromChainModelId,
            accountId: accountId,
            currencyId: currencyId,
            destChainModel: destChainModel,
            amount: amount,
            weightLimit: weightLimit,
            path: path
        )

        let extrinsicService = try await depsContainer.prepareDeps().extrinsicService

        return await withCheckedContinuation { continuation in
            extrinsicService.submit(
                extrinsic,
                signer: signingWrapper,
                runningIn: .global()
            ) { result in
                continuation.resume(returning: result)
            }
        }
    }

    private func submitXTokensTransferMultiasset(
        fromChainModel: ChainModel,
        assetSymbol: String,
        accountId: AccountId?,
        destChainModel: ChainModel,
        amount: BigUInt,
        weightLimit: BigUInt,
        path: XcmCallPath
    ) async throws -> SubmitExtrinsicResult {
        let extrinsicCall = try await makeXTokensTransferMultiassetExtrinsic(
            fromChainModel: fromChainModel,
            assetSymbol: assetSymbol,
            accountId: accountId,
            destChainModel: destChainModel,
            amount: amount,
            weightLimit: weightLimit,
            path: path
        )

        let extrinsicService = try await depsContainer.prepareDeps().extrinsicService

        return await withCheckedContinuation { continuation in
            extrinsicService.submit(
                extrinsicCall,
                signer: signingWrapper,
                runningIn: .main
            ) { result in
                continuation.resume(returning: result)
            }
        }
    }

    private func submitPolkadotXcmLimitedReserveTransferAssetsExtrinsic(
        fromChainModel: ChainModel,
        assetSymbol: String,
        accountId: AccountId?,
        destChainModel: ChainModel,
        amount: BigUInt,
        weightLimit: BigUInt,
        path: XcmCallPath
    ) async throws -> SubmitExtrinsicResult {
        let extrinsicCall = try await makePolkadotXcmLimitedReserveTransferAssetsExtrinsic(
            fromChainModel: fromChainModel,
            assetSymbol: assetSymbol,
            accountId: accountId,
            destChainModel: destChainModel,
            amount: amount,
            weightLimit: weightLimit,
            path: path
        )

        let extrinsicService = try await depsContainer.prepareDeps().extrinsicService

        return await withCheckedContinuation { continuation in
            extrinsicService.submit(
                extrinsicCall,
                signer: signingWrapper,
                runningIn: .main
            ) { result in
                continuation.resume(returning: result)
            }
        }
    }

    private func submitBridgeProxyBurn(
        fromChainModel: ChainModel,
        currencyId: String,
        destChainModel: ChainModel,
        accountId: AccountId?,
        amount: BigUInt,
        path: XcmCallPath
    ) async throws -> SubmitExtrinsicResult {
        let extrinsicCall = try makeBridgeProxyBurnExtrinsic(
            fromChainModel: fromChainModel,
            currencyId: currencyId,
            destChainModel: destChainModel,
            accountId: accountId,
            amount: amount,
            path: path
        )

        let extrinsicService = try await depsContainer.prepareDeps().extrinsicService

        return await withCheckedContinuation { continuation in
            extrinsicService.submit(
                extrinsicCall,
                signer: signingWrapper,
                runningIn: .main
            ) { result in
                continuation.resume(returning: result)
            }
        }
    }

    // MARK: - Fees

    private func estimateNativeTokenTransferFee(
        with path: XcmCallPath,
        fromChainModel: ChainModel,
        destChainModel: ChainModel,
        destAccountId: AccountId,
        amount: BigUInt,
        weightLimit: BigUInt?
    ) async throws -> FeeExtrinsicResult {
        let extrinsic = try await makeNativeTokenTransferExtrinsic(
            with: path,
            fromChainModel: fromChainModel,
            destChainModel: destChainModel,
            destAccountId: destAccountId,
            amount: amount,
            weightLimit: weightLimit
        )

        let extrinsicService = try await depsContainer.prepareDeps().extrinsicService

        return await withCheckedContinuation { continuation in
            extrinsicService.estimateFee(extrinsic, runningIn: .global()) { result in
                continuation.resume(returning: result)
            }
        }
    }

    private func estimateXTokensTransferFee(
        fromChainModelId: ChainModel.Id,
        accountId: AccountId?,
        currencyId: CurrencyId,
        destChainModel: ChainModel,
        amount: BigUInt,
        weightLimit: BigUInt,
        path: XcmCallPath
    ) async throws -> FeeExtrinsicResult {
        let extrinsic = try await makeXTokensTransferExtrinsic(
            fromChainModelId: fromChainModelId,
            accountId: accountId,
            currencyId: currencyId,
            destChainModel: destChainModel,
            amount: amount,
            weightLimit: weightLimit,
            path: path
        )

        let extrinsicService = try await depsContainer.prepareDeps().extrinsicService

        return await withCheckedContinuation { continuation in
            extrinsicService.estimateFee(extrinsic, runningIn: .global()) { result in
                continuation.resume(returning: result)
            }
        }
    }

    private func estimateXTokensTransferMultiassetFee(
        fromChainModel: ChainModel,
        assetSymbol: String,
        accountId: AccountId?,
        destChainModel: ChainModel,
        amount: BigUInt,
        weightLimit: BigUInt,
        path: XcmCallPath
    ) async throws -> FeeExtrinsicResult {
        let extrinsicCall = try await makeXTokensTransferMultiassetExtrinsic(
            fromChainModel: fromChainModel,
            assetSymbol: assetSymbol,
            accountId: accountId,
            destChainModel: destChainModel,
            amount: amount,
            weightLimit: weightLimit,
            path: path
        )

        let extrinsicService = try await depsContainer.prepareDeps().extrinsicService

        return await withCheckedContinuation { continuation in
            extrinsicService.estimateFee(extrinsicCall, runningIn: .global()) { result in
                continuation.resume(returning: result)
            }
        }
    }

    private func estimatePolkadotXcmLimitedReserveTransferAssetsFee(
        fromChainModel: ChainModel,
        assetSymbol: String,
        accountId: AccountId?,
        destChainModel: ChainModel,
        amount: BigUInt,
        weightLimit: BigUInt,
        path: XcmCallPath
    ) async throws -> FeeExtrinsicResult {
        let extrinsicCall = try await makePolkadotXcmLimitedReserveTransferAssetsExtrinsic(
            fromChainModel: fromChainModel,
            assetSymbol: assetSymbol,
            accountId: accountId,
            destChainModel: destChainModel,
            amount: amount,
            weightLimit: weightLimit,
            path: path
        )

        let extrinsicService = try await depsContainer.prepareDeps().extrinsicService

        return await withCheckedContinuation { continuation in
            extrinsicService.estimateFee(extrinsicCall, runningIn: .global()) { result in
                continuation.resume(returning: result)
            }
        }
    }

    // MARK: - Sora Mainnet

    private func estimateBridgeProxyBurn(
        fromChainModel: ChainModel,
        currencyId: String,
        destChainModel: ChainModel,
        accountId: AccountId?,
        amount: BigUInt,
        path: XcmCallPath
    ) async throws -> FeeExtrinsicResult {
        let extrinsicCall = try makeBridgeProxyBurnExtrinsic(
            fromChainModel: fromChainModel,
            currencyId: currencyId,
            destChainModel: destChainModel,
            accountId: accountId,
            amount: amount,
            path: path
        )

        let extrinsicService = try await depsContainer.prepareDeps().extrinsicService

        return await withCheckedContinuation { continuation in
            extrinsicService.estimateFee(extrinsicCall, runningIn: .global()) { result in
                continuation.resume(returning: result)
            }
        }
    }
}

private extension String {
    func dropXcPrefix(chain: ChainModel) -> String {
        guard chain.hasXcAssetPrefix else {
            return self
        }
        guard lowercased().hasPrefix("xc") else {
            return self
        }
        let modifySymbol = String(dropFirst(2))
        return modifySymbol
    }
}
