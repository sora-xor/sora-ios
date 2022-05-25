import Foundation
import CommonWallet

@objc public protocol PolkaswapAmountInputViewModelObserver: AnyObject {
    func amountInputDidChange()
}

public protocol PolkaswapAmountInputViewModelProtocol: AnyObject {
    var symbol: String { get }
    var displayAmount: String { get }
    var decimalAmount: Decimal? { get }
    var isValid: Bool { get }
    var observable: PolkaswapWalletViewModelObserverContainer<AmountInputViewModelObserver> { get }

    func didReceiveReplacement(_ string: String, for range: NSRange, isNotificationEnabled: Bool) -> Bool
    func didUpdateAmount(to newAmount: Decimal, isNotificationEnabled: Bool)
}

extension PolkaswapAmountInputViewModelProtocol {
    func didUpdateAmount(to newAmount: Decimal, isNotificationEnabled: Bool) { }
}

public final class PolkaswapAmountInputViewModel: PolkaswapAmountInputViewModelProtocol, PolkaswapMoneyPresentable {
    
    static let zero: String = "0"

    public var displayAmount: String {
        return formattedAmount ?? PolkaswapAmountInputViewModel.zero
    }

    public var decimalAmount: Decimal? {
        if innerAmount.isEmpty {
            return nil
        }

        return Decimal(string: innerAmount, locale: formatter.locale)
    }

    public var isValid: Bool {
        if let value = Decimal(string: innerAmount, locale: formatter.locale), value > 0 {
            return true
        } else {
            return false
        }
    }

    var precision: Int16

    private(set) var innerAmount: String = ""
    
    private func setAmount(_ newAmount: String, isNotificationEnabled: Bool = true) {
        if innerAmount != newAmount {
            innerAmount = newAmount
            if isNotificationEnabled {
                observable.observers.forEach { $0.observer?.amountInputDidChange() }
            }
        }
    }

    public let symbol: String

    let formatter: NumberFormatter

    let inputLocale: Locale

    let limit: Decimal

    public var observable: PolkaswapWalletViewModelObserverContainer<AmountInputViewModelObserver>

    public init(symbol: String,
                amount: Decimal?,
                limit: Decimal,
                formatter: NumberFormatter,
                inputLocale: Locale = Locale.current,
                precision: Int16 = 2) {
        self.symbol = symbol
        self.limit = limit
        self.formatter = formatter
        self.inputLocale = inputLocale
        self.precision = precision

        observable = PolkaswapWalletViewModelObserverContainer()

        if let amount = amount, amount <= limit,
            let inputAmount = formatter.string(from: amount as NSNumber) {
            setAmount(set(inputAmount))
//            self.amount = set(inputAmount)
        }
    }

    public func didReceiveReplacement(_ string: String, for range: NSRange, isNotificationEnabled: Bool) -> Bool {
        let replacement = transform(input: string, from: inputLocale)

        var newAmount = displayAmount

        if range.location == newAmount.count {
            newAmount = add(replacement)
        } else {
            newAmount = (newAmount as NSString).replacingCharacters(in: range, with: replacement)
            newAmount = set(newAmount)
        }

        let optionalAmountDecimal = !newAmount.isEmpty ?
            Decimal(string: newAmount, locale: formatter.locale) :
            Decimal.zero

        guard
            let receivedAmountDecimal = optionalAmountDecimal,
            receivedAmountDecimal <= limit else {
            return false
        }

        setAmount(newAmount, isNotificationEnabled: isNotificationEnabled)
//        amount = newAmount

        return false
    }

    public func didUpdateAmount(to newAmount: Decimal, isNotificationEnabled: Bool) {
        guard newAmount <= limit,
              let inputAmount = formatter.string(from: newAmount as NSNumber)
        else { return }

        let replacement = transform(input: inputAmount, from: inputLocale)
        setAmount(replacement, isNotificationEnabled: isNotificationEnabled)
//        amount = inputAmount
    }
}
