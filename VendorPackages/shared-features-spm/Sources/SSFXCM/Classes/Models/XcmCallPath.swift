import Foundation
import SSFModels

enum XcmCallPath: StorageCodingPathProtocol {
    var moduleName: String {
        path.moduleName
    }

    var itemName: String {
        path.itemName
    }

    var path: (moduleName: String, itemName: String) {
        switch self {
        case .parachainId:
            return (moduleName: "parachainInfo", itemName: "parachainId")

        case .xcmPalletLimitedTeleportAssets:
            return (moduleName: "xcmPallet", itemName: "limited_teleport_assets")
        case .xcmPalletLimitedReserveTransferAssets:
            return (moduleName: "xcmPallet", itemName: "limited_reserve_transfer_assets")

        case .polkadotXcmTeleportAssets:
            return (moduleName: "polkadotXcm", itemName: "teleport_assets")
        case .polkadotXcmLimitedTeleportAssets:
            return (moduleName: "polkadotXcm", itemName: "limited_teleport_assets")
        case .polkadotXcmLimitedReserveTransferAssets:
            return (moduleName: "polkadotXcm", itemName: "limited_reserve_transfer_assets")
        case .polkadotXcmLimitedReserveWithdrawAssets:
            return (moduleName: "polkadotXcm", itemName: "limited_reserve_withdraw_assets")

        case .xTokensTransfer:
            return (moduleName: "xTokens", itemName: "transfer")
        case .xTokensTransferMultiasset:
            return (moduleName: "xTokens", itemName: "transfer_multiasset")

        case .bridgeProxyBurn:
            return (moduleName: "bridgeProxy", itemName: "burn")
        case .bridgeProxyTransactions:
            return (moduleName: "BridgeProxy", itemName: "Transactions")
        }
    }

    case parachainId

    case xcmPalletLimitedTeleportAssets
    case xcmPalletLimitedReserveTransferAssets

    case polkadotXcmTeleportAssets
    case polkadotXcmLimitedTeleportAssets
    case polkadotXcmLimitedReserveTransferAssets
    case polkadotXcmLimitedReserveWithdrawAssets

    case xTokensTransfer
    case xTokensTransferMultiasset

    case bridgeProxyBurn
    case bridgeProxyTransactions
}

extension XcmCallPath {
    static var usedRuntimePaths: [String: [String]] {
        var usedRuntimePaths = [String: [String]]()
        for cas in XcmCallPath.allCases {
            usedRuntimePaths[cas.moduleName] = [cas.itemName]
        }
        return usedRuntimePaths
    }
}
