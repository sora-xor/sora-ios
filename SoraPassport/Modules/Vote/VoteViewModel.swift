/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit

protocol VoteViewModelProtocol: class {
    var projectId: String { get }
    var amount: Float { get}
    var description: String { get }
    var formattedAmount: String { get }
    var minimumVoteAmount: Float { get }
    var maximumVoteAmount: Float { get }
    var canVote: Bool { get }

    func updateAmount(with newAmount: Float)
    func updateAmount(with inputString: String)
}

enum VoteViewModelError: Error {
    case emptyAmount
    case tooSmallAmount
    case tooBigAmount
}

final class VoteViewModel {
    private(set) var minimumVoteAmount: Float
    private(set) var maximumVoteAmount: Float
    private(set) var projectId: String

    var amountFormatter: NumberFormatter = NumberFormatter()
    var errorDisplayMapping: [VoteViewModelError: String] = [:]

    private(set) var error: VoteViewModelError?

    private(set) var amount: Float
    private(set) var formattedAmount: String

    init(projectId: String, amount: Float, minimumVoteAmount: Float, maximumVoteAmount: Float) {
        self.projectId = projectId
        self.amount = amount
        self.minimumVoteAmount = minimumVoteAmount
        self.maximumVoteAmount = maximumVoteAmount

        formattedAmount = amountFormatter.string(from: NSNumber(value: amount)) ?? ""
    }
}

extension VoteViewModel: VoteViewModelProtocol {
    var canVote: Bool {
        return error == nil
    }

    var description: String {
        if let error = error {
            return errorDisplayMapping[error] ?? ""
        } else {
            return R.string.localizable.voteDescriptionMessage()
        }
    }

    func updateAmount(with newAmount: Float) {
        if newAmount < minimumVoteAmount {
            amount = minimumVoteAmount

            if error != .tooSmallAmount {
                error = .tooSmallAmount
                formattedAmount = amountFormatter
                    .string(from: NSNumber(value: newAmount)) ?? formattedAmount
            }

            return
        }

        if newAmount > maximumVoteAmount {
            amount = maximumVoteAmount

            if error != .tooBigAmount {
                error = .tooBigAmount
                formattedAmount = amountFormatter
                    .string(from: NSNumber(value: newAmount)) ?? formattedAmount
            }

            return
        }

        error = nil

        amount = newAmount
        formattedAmount = amountFormatter
            .string(from: NSNumber(value: newAmount)) ?? formattedAmount
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

        guard let value = number?.floatValue else {
            return
        }

        updateAmount(with: value)
    }
}
