/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import RobinHood

protocol SynchronizableRewardCalculatorDelegate: class {
    func didSynchronize(calculator: SynchronizableRewardCalculatorProtocol)
    func didFail(synchronizer: SynchronizableRewardCalculatorProtocol, with error: Error)
}

enum SynchronizableRewardCalculatorError: Error {
    case setupNotCompleted
    case selectedCurrencyNotFound
    case brokenCurrencyRatio
    case brokenRewardFormatter
}

protocol SynchronizableRewardCalculatorProtocol {
    var delegate: SynchronizableRewardCalculatorDelegate? { get set }

    func setup()
    func calculate(for value: Double) throws -> Double
    func formatedCalculation(for value: Double) throws -> String
}

final class CurrencyBasedRewardCalculator {
    enum State {
        case initialized
        case setupInProgress
        case setupCompleted
        case setupFailed
    }

    weak var delegate: SynchronizableRewardCalculatorDelegate?

    private(set) var selectedCurrency: CurrencyItemData?
    private(set) var state: State = .initialized

    private let selectedCurrencyDataProvider: SelectedCurrencyDataProvider
    private let rewardPercentage: Double
    private let rewardFormatter: NumberFormatter

    init(selectedCurrencyDataProvider: SelectedCurrencyDataProvider,
         rewardFormatter: NumberFormatter,
         rewardPercentage: Double) {
        self.selectedCurrencyDataProvider = selectedCurrencyDataProvider
        self.rewardFormatter = rewardFormatter
        self.rewardPercentage = rewardPercentage
    }

    private func handleUpdateSelected(currency: CurrencyItemData) {
        selectedCurrency = currency
        state = .setupCompleted

        rewardFormatter.currencyCode = currency.code
        rewardFormatter.currencySymbol = currency.symbol

        delegate?.didSynchronize(calculator: self)
    }

    private func handleFail(with error: Error) {
        state = .setupFailed

        delegate?.didFail(synchronizer: self, with: error)
    }
}

extension CurrencyBasedRewardCalculator: SynchronizableRewardCalculatorProtocol {
    func setup() {
        guard state != .setupInProgress, state != .setupCompleted else {
            return
        }

        state = .setupInProgress

        let changesBlock = { [weak self] (changes: [DataProviderChange<CurrencyItemData>]) -> Void in
            if let change = changes.first {
                switch change {
                case .insert(let currency), .update(let currency):
                    self?.handleUpdateSelected(currency: currency)

                case .delete:
                    break
                }
            }
        }

        let failBlock = { [weak self] (error: Error) -> Void in
            self?.handleFail(with: error)
        }

        selectedCurrencyDataProvider.addCacheObserver(self,
                                                      deliverOn: .main,
                                                      executing: changesBlock,
                                                      failing: failBlock)
    }

    func calculate(for value: Double) throws -> Double {
        guard state == .setupCompleted else {
            throw SynchronizableRewardCalculatorError.setupNotCompleted
        }

        guard let selectedCurrency = selectedCurrency else {
            throw SynchronizableRewardCalculatorError.selectedCurrencyNotFound
        }

        guard let currencyRatio = Double(selectedCurrency.ratio) else {
            throw SynchronizableRewardCalculatorError.brokenCurrencyRatio
        }

        return value * rewardPercentage * currencyRatio
    }

    func formatedCalculation(for value: Double) throws -> String {
        let reward = try calculate(for: value)

        guard let formattedReward = rewardFormatter.string(from: reward as NSNumber) else {
            throw SynchronizableRewardCalculatorError.brokenRewardFormatter
        }

        return formattedReward
    }
}
