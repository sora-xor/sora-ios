import Foundation
import CommonWallet

extension HistoryViewStyle {
    static var sora: HistoryViewStyleProtocol { //Header
        let borderStyle = WalletStrokeStyle(color: .clear, lineWidth: 0)
        let cornerRadius: CGFloat = 10.0
        let titleStyle = WalletTextStyle(font: UIFont.styled(for: .paragraph2, isBold: true),
                                         color: R.color.baseContentTertiary()!)
        let shadow = WalletShadowStyle(offset: CGSize(width: 0.0, height: 1.0),
                                   color: UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.35),
                                   opacity: 1.0,
                                   blurRadius: 4.0)

        return HistoryViewStyle(fillColor: R.color.neumorphism.base()!,
                                borderStyle: borderStyle,
                                cornerRadius: cornerRadius,
                                titleStyle: titleStyle,
                                filterIcon: nil,
                                closeIcon: nil,
                                panIndicatorStyle: UIColor(white: 221.0 / 255.0, alpha: 1.0),
                                shouldInsertFullscreenShadow: true,
                                shadow: shadow,
                                separatorStyle: UIColor(white: 221.0 / 255.0, alpha: 0.5),
                                pageLoadingIndicatorColor: UIColor(white: 221.0 / 255.0, alpha: 1.0))
    }
}

extension TransactionCellStyle {
    static var sora: TransactionCellStyle {
        let text = WalletTextStyle(font: UIFont.styled(for: .paragraph1, isBold: true),
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
                                    separatorColor: R.color.neumorphism.separator()!)
    }
}

extension TransactionHeaderStyle {
    static var sora: TransactionHeaderStyle { // date section
        let text = WalletTextStyle(font: UIFont.styled(for: .paragraph2, isBold: false),
                                   color: R.color.baseContentTertiary()!)
        return TransactionHeaderStyle(background: R.color.neumorphism.base()!,
                                      title: text,
                                      separatorColor: R.color.neumorphism.separator()!)
    }
}
