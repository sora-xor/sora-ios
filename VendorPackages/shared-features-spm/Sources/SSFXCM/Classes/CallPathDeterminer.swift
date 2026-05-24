import Foundation
import SSFChainRegistry
import SSFRuntimeCodingService

// sourcery: AutoMockable
protocol CallPathDeterminer {
    func determineCallPath(
        from: XcmChainType,
        dest: XcmChainType
    ) async throws -> XcmCallPath
}

final class CallPathDeterminerImpl: CallPathDeterminer {
    private enum Pallet: String {
        case xTokens
        case polkadotXcm
    }

    private let chainRegistry: ChainRegistryProtocol
    private let fromChainData: XcmAssembly.FromChainData

    init(
        chainRegistry: ChainRegistryProtocol,
        fromChainData: XcmAssembly.FromChainData
    ) {
        self.chainRegistry = chainRegistry
        self.fromChainData = fromChainData
    }

    // MARK: - Public methods

    func determineCallPath(
        from: XcmChainType,
        dest: XcmChainType
    ) async throws -> XcmCallPath {
        switch (from, dest) {
        case (.relaychain, .nativeParachain):
            return .xcmPalletLimitedTeleportAssets
        case (.relaychain, .parachain):
            return .xcmPalletLimitedReserveTransferAssets
        case (.nativeParachain, .relaychain):
            return .polkadotXcmLimitedTeleportAssets
        case (.nativeParachain, .nativeParachain):
            return .polkadotXcmLimitedTeleportAssets
        case (.nativeParachain, .parachain):
            return .polkadotXcmLimitedReserveTransferAssets
        case (.parachain, .relaychain):
            return try await determineForParachain(dest: dest)
        case (.parachain, .nativeParachain):
            return try await determineForParachain(dest: dest)
        case (.parachain, .parachain):
            return try await determineForParachain(dest: dest)
        case (.soraMainnet, .relaychain): // considers this case as Sora mainnet bridge
            return .bridgeProxyBurn
        case (.relaychain, .soraMainnet): // considers this case as to Sora mainnet bridge
            return .xcmPalletLimitedReserveTransferAssets
        default:
            throw XcmError.directionNotSupported
        }
    }

    // MARK: - Private methods

    private func determineForParachain(
        dest: XcmChainType
    ) async throws -> XcmCallPath {
        let pallet = try await getPallet()
        switch (pallet, dest) {
        case (.xTokens, .relaychain):
            return .xTokensTransferMultiasset
        case (.xTokens, .nativeParachain):
            return .xTokensTransferMultiasset
        case (.xTokens, .parachain):
            return .xTokensTransferMultiasset

        case (.polkadotXcm, .relaychain):
            return .polkadotXcmLimitedReserveWithdrawAssets
        case (.polkadotXcm, .nativeParachain):
            return .polkadotXcmLimitedTeleportAssets
        case (.polkadotXcm, .parachain):
            return .polkadotXcmLimitedReserveTransferAssets
        default:
            throw XcmError.directionNotSupported
        }
    }

    private func getPallet() async throws -> Pallet {
        let metadata = try await getRuntimeSnapshot().metadata
        if metadata.getModuleIndex(Pallet.xTokens.rawValue) != nil {
            return Pallet.xTokens
        } else if metadata.getModuleIndex(Pallet.polkadotXcm.rawValue) != nil {
            return Pallet.polkadotXcm
        }
        throw XcmError.noXcmPallet(chainId: fromChainData.chainId)
    }

    private func getRuntimeSnapshot() async throws -> RuntimeSnapshot {
        try await chainRegistry.getReadySnapshot(
            chainId: fromChainData.chainId,
            usedRuntimePaths: XcmCallPath.usedRuntimePaths,
            runtimeItem: fromChainData.chainMetadata
        )
    }
}
