import Foundation

enum TransactionType: String, CaseIterable {
    case incoming = "INCOMING"
    case outgoing = "OUTGOING"
    case reward = "REWARD"
    case slash = "SLASH"
    case swap = "SWAP"
    case extrinsic = "EXTRINSIC"
    case liquidityAdd = "Deposit"
    case liquidityRemoval = "Removal"
}

extension TransactionLiquidityType {
    var transactionType: TransactionType {
        switch self {
        case .deposit:
            return .liquidityAdd
        case .removal:
            return .liquidityRemoval
        }
    }
}

import SoraFoundation
extension TransactionType {
    var localizedName: String {
       let locale = LocalizationManager.shared.selectedLocale
       switch self {
       case .incoming:
           return R.string.localizable.historyReceive(preferredLanguages: locale.rLanguages).uppercased()
       case .outgoing:
           return R.string.localizable.historySend(preferredLanguages: locale.rLanguages).uppercased()
       case .swap:
           return R.string.localizable.historySwap(preferredLanguages: locale.rLanguages).uppercased()
       case .liquidityAdd:
           return R.string.localizable.commonDeposit(preferredLanguages: locale.rLanguages).uppercased()
       case .liquidityRemoval:
           return R.string.localizable.commonRemove(preferredLanguages: locale.rLanguages).uppercased()
       case .reward, .slash, .extrinsic:
           return self.rawValue
       }
    }
}
