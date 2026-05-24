import Foundation
import SSFModels

public enum TransactionHistorySupportedCodingPath: Equatable, CaseIterable,
    StorageCodingPathProtocol
{
    case transfer
    case adarTransfer
    case transferKeepAlive
    case swap
    case migration
    case depositLiquidity
    case withdrawLiquidity
    case setReferral
    case bondReferralBalance
    case unbondReferralBalance
    case batchUtility
    case batchAllUtility
    case getRewards
    case farmDeposit
    case farmWithdraw

    public var moduleName: String {
        path.moduleName
    }

    public var itemName: String {
        path.itemName
    }

    public var path: (moduleName: String, itemName: String) {
        switch self {
        case .transfer:
            return (moduleName: "assets", itemName: "transfer")
        case .adarTransfer:
            return (moduleName: "assets", itemName: "Transfer")
        case .transferKeepAlive:
            return (moduleName: "assets", itemName: "transferKeepAlive")
        case .swap:
            return (moduleName: "liquidityProxy", itemName: "swap")
        case .migration:
            return (moduleName: "irohaMigration", itemName: "migrate")
        case .depositLiquidity:
            return (moduleName: "poolXYK", itemName: "depositLiquidity")
        case .withdrawLiquidity:
            return (moduleName: "poolXYK", itemName: "withdrawLiquidity")
        case .setReferral:
            return (moduleName: "referrals", itemName: "setReferrer")
        case .bondReferralBalance:
            return (moduleName: "referrals", itemName: "reserve")
        case .unbondReferralBalance:
            return (moduleName: "referrals", itemName: "unreserve")
        case .batchUtility:
            return (moduleName: "utility", itemName: "batch")
        case .batchAllUtility:
            return (moduleName: "utility", itemName: "batchAll")
        case .getRewards:
            return (moduleName: "demeterFarmingPlatform", itemName: "getRewards")
        case .farmDeposit:
            return (moduleName: "demeterFarmingPlatform", itemName: "deposit")
        case .farmWithdraw:
            return (moduleName: "demeterFarmingPlatform", itemName: "withdraw")
        }
    }

    init?(path: (moduleName: String, itemName: String)) {
        switch path {
        case (moduleName: "assets", itemName: "transfer"):
            self = .transfer
        case (moduleName: "assets", itemName: "Transfer"):
            self = .adarTransfer
        case (moduleName: "assets", itemName: "transferKeepAlive"):
            self = .transferKeepAlive
        case (moduleName: "liquidityProxy", itemName: "swap"):
            self = .swap
        case (moduleName: "irohaMigration", itemName: "migrate"):
            self = .migration
        case (moduleName: "poolXYK", itemName: "depositLiquidity"):
            self = .depositLiquidity
        case (moduleName: "poolXYK", itemName: "withdrawLiquidity"):
            self = .withdrawLiquidity
        case (moduleName: "referrals", itemName: "setReferrer"):
            self = .setReferral
        case (moduleName: "referrals", itemName: "reserve"):
            self = .bondReferralBalance
        case (moduleName: "referrals", itemName: "unreserve"):
            self = .unbondReferralBalance
        case (moduleName: "utility", itemName: "batch"):
            self = .batchUtility
        case (moduleName: "utility", itemName: "batchAll"):
            self = .batchAllUtility
        case (moduleName: "demeterFarmingPlatform", itemName: "getRewards"):
            self = .getRewards
        case (moduleName: "demeterFarmingPlatform", itemName: "deposit"):
            self = .farmDeposit
        case (moduleName: "demeterFarmingPlatform", itemName: "withdraw"):
            self = .farmWithdraw
        default:
            return nil
        }
    }
}
