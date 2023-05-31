import Foundation
import UIKit
import XNetworking
import SoraUIKit

protocol Transaction {
    var base: TransactionBase { get set }
}

struct TransactionBase {
    enum Status: Int16, Codable {
        case pending
        case success
        case failed
        
        var title: String {
            switch self {
            case .failed: return R.string.localizable.commonFailed(preferredLanguages: .currentLocale)
            case .pending: return R.string.localizable.walletTxDetailsPending(preferredLanguages: .currentLocale)
            case .success: return R.string.localizable.statusSuccessful(preferredLanguages: .currentLocale)
            }
        }
        
        var color: SoramitsuColor {
            switch self {
            case .failed: return .statusError
            case .pending: return .fgSecondary
            case .success: return .statusSuccess
            }
        }
        
        var image: UIImage? {
            switch self {
            case .failed: return R.image.wallet.failStatus()
            case .pending: return R.image.wallet.pendingStatus()
            case .success: return nil
            }
        }
    }
    
    let txHash: String
    let blockHash: String
    let fee: Amount
    var status: Status
    let timestamp: String
}

struct TransferTransaction: Transaction {

    enum TransferType {
        case incoming
        case outcoming
        
        var title: String {
            switch self {
            case .incoming: return R.string.localizable.commonReceived(preferredLanguages: .currentLocale)
            case .outcoming: return R.string.localizable.commonSent(preferredLanguages: .currentLocale)
            }
        }
        
        var image: UIImage? {
            switch self {
            case .incoming: return R.image.wallet.receive()
            case .outcoming: return R.image.wallet.send()
            }
        }
        
        var detailsTitle: String {
            switch self {
            case .incoming: return R.string.localizable.commonReceived(preferredLanguages: .currentLocale)
            case .outcoming: return R.string.localizable.commonSent(preferredLanguages: .currentLocale)
            }
        }
    }
    
    var base: TransactionBase
    let amount: Amount
    let peer: String
    let transferType: TransferType
    let tokenId: String
}

struct ReferralBondTransaction: Transaction {

    enum ReferralTransactionType {
        case bond
        case unbond
        
        var title: String {
            switch self {
            case .bond: return R.string.localizable.activityBondTitle(preferredLanguages: .currentLocale)
            case .unbond: return R.string.localizable.activityUnbondTitle(preferredLanguages: .currentLocale)
            }
        }
        
        var detailsTitle: String {
            switch self {
            case .bond: return R.string.localizable.walletBonded(preferredLanguages: .currentLocale)
            case .unbond: return R.string.localizable.walletUnbonded(preferredLanguages: .currentLocale)
            }
        }
        
        var image: UIImage? {
            switch self {
            case .bond: return R.image.wallet.send()
            case .unbond: return  R.image.wallet.receive()
            }
        }
    }
    
    var base: TransactionBase
    let amount: Amount
    let tokenId: String
    let type: ReferralTransactionType
}

struct SetReferrerTransaction: Transaction {
    var base: TransactionBase
    let who: String
    let isMyReferrer: Bool
    let tokenId: String
}

struct Swap: Transaction {
    var base: TransactionBase
    let fromTokenId: String
    let toTokenId: String
    let fromAmount: Amount
    let toAmount: Amount
    let market: LiquiditySourceType
    let lpFee: Amount
}

struct Liquidity: Transaction {
    enum TransactionLiquidityType {
        case add
        case withdraw
        
        var subtitle: String {
            switch self {
            case .add: return R.string.localizable.activityAddLiquidityTitle(preferredLanguages: .currentLocale)
            case .withdraw: return R.string.localizable.commonWithdraw(preferredLanguages: .currentLocale)
            }
        }
        
        var image: UIImage? {
            switch self {
            case .add: return R.image.wallet.send()
            case .withdraw: return R.image.wallet.receive()
            }
        }
    }
    var base: TransactionBase
    let firstTokenId: String
    let secondTokenId: String
    let firstAmount: Amount
    let secondAmount: Amount
    let type: TransactionLiquidityType
}

struct TransferData {
    let to: String
    let from: String
    let amount: String
    let assetId: String
}

struct ReferralData {
    let amount: String
}

struct SetReferrerData {
    let address: String
    let my: Bool
}

struct SwapData {
    let selectedMarket: String
    let liquidityProviderFee: String
    let baseTokenId: String
    let targetTokenId: String
    let baseTokenAmount: String
    let targetTokenAmount: String
}

struct LiquidityData {
    let baseTokenId: String
    let targetTokenId: String
    let baseTokenAmount: String
    let targetTokenAmount: String
}

extension Array where Element == TxHistoryItemParam {
    func toTransferData() -> TransferData {
        return TransferData(to: self.first { $0.paramName == "to" }?.paramValue ?? "",
                            from: self.first { $0.paramName == "from" }?.paramValue ?? "",
                            amount: self.first { $0.paramName == "amount" }?.paramValue ?? "",
                            assetId: self.first { $0.paramName == "assetId" }?.paramValue ?? "")
    }
    
    func toReferralData() -> ReferralData {
        return ReferralData(amount: self.first { $0.paramName == "amount" }?.paramValue ?? "")
    }
    
    func toSetReferrerData(with myAddress: String) -> SetReferrerData {
        let to = self.first { $0.paramName == "to" }?.paramValue ?? ""
        let from = self.first { $0.paramName == "from" }?.paramValue ?? ""
        let isMyReferrer = from == myAddress
        
        return SetReferrerData(address: isMyReferrer ? to : from, my: isMyReferrer)
    }
    
    func toSwapData() -> SwapData {
        return SwapData(selectedMarket: self.first { $0.paramName == "selectedMarket" }?.paramValue ?? "" ,
                        liquidityProviderFee: self.first { $0.paramName == "liquidityProviderFee" }?.paramValue ?? "" ,
                        baseTokenId: self.first { $0.paramName == "baseAssetId" }?.paramValue ?? "" ,
                        targetTokenId: self.first { $0.paramName == "targetAssetId" }?.paramValue ?? "" ,
                        baseTokenAmount: self.first { $0.paramName == "baseAssetAmount" }?.paramValue ?? "" ,
                        targetTokenAmount: self.first { $0.paramName == "targetAssetAmount" }?.paramValue ?? "")
    }
    
    func toLiquidityData() -> LiquidityData {
        return LiquidityData(baseTokenId: self.first { $0.paramName == "targetAssetId" }?.paramValue ?? "" ,
                             targetTokenId: self.first { $0.paramName == "baseAssetId" }?.paramValue ?? "" ,
                             baseTokenAmount: self.first { $0.paramName == "baseAssetAmount" }?.paramValue ?? "" ,
                             targetTokenAmount: self.first { $0.paramName == "targetAssetAmount" }?.paramValue ?? "" )
    }
    
    func toLiquidityBatchData() -> LiquidityData {
        return LiquidityData(baseTokenId: self.first { $0.paramName == "input_asset_a" }?.paramValue ?? "" ,
                             targetTokenId: self.first { $0.paramName == "input_asset_b" }?.paramValue ?? "" ,
                             baseTokenAmount: self.first { $0.paramName == "input_a_desired" }?.paramValue ?? "" ,
                             targetTokenAmount: self.first { $0.paramName == "input_b_desired" }?.paramValue ?? "" )
    }
}