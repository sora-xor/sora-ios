/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation
import RobinHood

final class HelpInteractor {
	weak var presenter: HelpInteractorOutputProtocol?

    private(set) var helpDataProvider: SingleValueProvider<HelpData, CDSingleValue>

    init(helpDataProvider: SingleValueProvider<HelpData, CDSingleValue>) {
        self.helpDataProvider = helpDataProvider
    }

    private func setupHelpDataProvider() {
        let changesBlock = { [weak self] (changes: [DataProviderChange<HelpData>]) -> Void in
            if let change = changes.first {
                switch change {
                case .insert(let helpData), .update(let helpData):
                    self?.handle(optionalHelpData: helpData)
                case .delete:
                    self?.handle(optionalHelpData: nil)
                }
            } else {
                self?.handle(optionalHelpData: nil)
            }
        }

        let failBlock = { [weak self] (error: Error) -> Void in
            self?.presenter?.didReceiveHelpDataProvider(error: error)
        }

        helpDataProvider.addCacheObserver(self,
                                          deliverOn: .main,
                                          executing: changesBlock,
                                          failing: failBlock)
    }

    private func handle(optionalHelpData: HelpData?) {
        guard let helpData = optionalHelpData else {
            presenter?.didReceive(helpItems: [])
            return
        }

        let helpItems = helpData.topics.enumerated().sorted(by: { (firstItem, secondItem) in
            let firstIndex = Int(firstItem.element.key) ?? 0
            let secondIndex = Int(secondItem.element.key) ?? 0

            return firstIndex < secondIndex
        })
            .map({ $0.element.value })

        presenter?.didReceive(helpItems: helpItems)
    }
}

extension HelpInteractor: HelpInteractorInputProtocol {
    func setup() {
        setupHelpDataProvider()
    }
}
