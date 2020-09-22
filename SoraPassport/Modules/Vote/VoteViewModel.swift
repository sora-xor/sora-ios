import UIKit

enum VotingTarget {
    case project(identifier: String)
    case referendum(identifier: String, option: ReferendumVotingCase)
}

protocol VoteViewModelProtocol: class {
    var target: VotingTarget { get }
    var amount: Decimal { get}
    var description: String { get }
    var formattedAmount: String { get }
    var minimumVoteAmount: Decimal { get }
    var maximumVoteAmount: Decimal { get }
    var canVote: Bool { get }
    var locale: Locale { get }

    func updateAmount(with newAmount: Decimal)
    func updateAmount(with inputString: String)
}

enum VoteViewModelError: Error {
    case emptyAmount
    case tooSmallAmount(amount: Decimal)
    case tooBigAmount(amount: Decimal)
    case adjustedMax(amount: Decimal)
}

final class VoteViewModel {
    enum BoundBreakPolicy {
        case notify
        case adjust
    }

    private(set) var minimumVoteAmount: Decimal
    private(set) var maximumVoteAmount: Decimal
    private(set) var target: VotingTarget

    var amountFormatter: NumberFormatter = NumberFormatter()
    var errorDisplayMapping: ((VoteViewModelError) -> String)?

    var rightBoundBreakPolicy: BoundBreakPolicy = .notify

    var locale: Locale

    private(set) var error: VoteViewModelError?

    private(set) var amount: Decimal
    private(set) var formattedAmount: String

    init(target: VotingTarget,
         amount: Decimal,
         minimumVoteAmount: Decimal,
         maximumVoteAmount: Decimal,
         locale: Locale = Locale.current) {
        self.target = target
        self.amount = amount
        self.minimumVoteAmount = minimumVoteAmount
        self.maximumVoteAmount = maximumVoteAmount
        self.locale = locale

        formattedAmount = amountFormatter.string(from: amount as NSNumber) ?? ""
    }
}

extension VoteViewModel: VoteViewModelProtocol {
    var canVote: Bool {
        if let error = error {
            switch error {
            case .emptyAmount, .tooBigAmount, .tooSmallAmount:
                return false
            case .adjustedMax:
                return true
            }
        } else {
            return true
        }
    }

    var description: String {
        if let error = error {
            return errorDisplayMapping?(error) ?? ""
        } else {
            return ""
        }
    }

    func updateAmount(with newAmount: Decimal) {
        let roundedAmount = newAmount.rounded(mode: .plain)

        if roundedAmount < minimumVoteAmount {
            amount = minimumVoteAmount

            if let currentError = error, case .tooSmallAmount = currentError {
                return
            }

            error = .tooSmallAmount(amount: roundedAmount)
            formattedAmount = amountFormatter.string(from: roundedAmount as NSNumber) ?? formattedAmount

            return
        }

        if roundedAmount > maximumVoteAmount {
            amount = maximumVoteAmount

            if let currentError = error {
                switch currentError {
                case .tooBigAmount, .adjustedMax:
                    return
                default:
                    break
                }
            }

            switch rightBoundBreakPolicy {
            case .notify:
                error = .tooBigAmount(amount: roundedAmount)
                formattedAmount = amountFormatter.string(from: roundedAmount as NSNumber) ?? formattedAmount
            case .adjust:
                error = .adjustedMax(amount: roundedAmount)
                formattedAmount = amountFormatter.string(from: amount as NSNumber) ?? formattedAmount
            }

            return
        }

        error = nil

        amount = roundedAmount

        formattedAmount = amountFormatter.string(from: roundedAmount as NSNumber) ?? formattedAmount
    }

    func updateAmount(with inputString: String) {
        let numberString = inputString
            .replacingOccurrences(of: amountFormatter.groupingSeparator, with: "")
            .replacingOccurrences(of: amountFormatter.decimalSeparator, with: "")

        if inputString.isEmpty {
            amount = minimumVoteAmount
            formattedAmount = ""
            error = .emptyAmount
            return
        }

        let number = amountFormatter.number(from: numberString)

        guard let value = number?.decimalValue else {
            return
        }

        updateAmount(with: value)
    }
}
