import Foundation
import CommonWallet

extension HistoryViewStyle {
    static var sora: HistoryViewStyleProtocol {
        let borderStyle = WalletStrokeStyle(color: .clear, lineWidth: 0.0)
        let cornerRadius: CGFloat = 10.0
        let titleStyle = WalletTextStyle(font: R.font.soraRc0040417SemiBold(size: 15.0)!,
                                         color: UIColor(white: 44.0 / 255.0, alpha: 1.0))

        return HistoryViewStyle(fillColor: .white,
                                borderStyle: borderStyle,
                                cornerRadius: cornerRadius,
                                titleStyle: titleStyle,
                                filterIcon: nil,
                                closeIcon: nil,
                                panIndicatorStyle: UIColor(white: 221.0 / 255.0, alpha: 1.0))
    }
}

extension TransactionCellStyle {
    static var sora: TransactionCellStyle {
        let text = WalletTextStyle(font: R.font.soraRc0040417SemiBold(size: 15.0)!,
                                   color: UIColor(white: 44.0 / 255.0, alpha: 1.0))
        let transactionStatusStyle = WalletTransactionStatusStyle(icon: nil, color: .white)
        let container = WalletTransactionStatusStyleContainer(approved: transactionStatusStyle,
                                                              pending: transactionStatusStyle,
                                                              rejected: transactionStatusStyle)
        return TransactionCellStyle(backgroundColor: .clear,
                                    title: text,
                                    amount: text,
                                    statusStyleContainer: container,
                                    increaseAmountIcon: nil,
                                    decreaseAmountIcon: nil,
                                    separatorColor: .clear)
    }
}

extension TransactionHeaderStyle {
    static var sora: TransactionHeaderStyle {
        let text = WalletTextStyle(font: R.font.soraRc0040417Regular(size: 14)!,
                                   color: UIColor(white: 120.0 / 255.0, alpha: 1.0))
        return TransactionHeaderStyle(background: .clear,
                                      title: text,
                                      separatorColor: .clear)
    }
}
