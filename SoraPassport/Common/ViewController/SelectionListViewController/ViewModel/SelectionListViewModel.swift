/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

protocol SelectionListViewModelObserver: class {
    func didChangeSelection()
}

protocol SelectionListViewModelProtocol: class {
    var title: String { get }
    var isSelected: Bool { get }

    func addObserver(_ observer: SelectionListViewModelObserver)
    func removeObserver(_ observer: SelectionListViewModelObserver)
}

final class SelectionListViewModel: SelectionListViewModelProtocol {
    private struct Observation {
        weak var observer: SelectionListViewModelObserver?
    }

    var title: String
    var isSelected: Bool {
        didSet {
            if isSelected != oldValue {
                observers.forEach { $0.observer?.didChangeSelection() }
            }
        }
    }

    private var observers = [Observation]()

    init(title: String, isSelected: Bool = false) {
        self.title = title
        self.isSelected = isSelected
    }

    func addObserver(_ observer: SelectionListViewModelObserver) {
        if !observers.contains(where: { $0.observer === observer }) {
            observers.append(Observation(observer: observer))
        }

        clearObservers()
    }

    func removeObserver(_ observer: SelectionListViewModelObserver) {
        observers = observers.filter { $0.observer !== observer && $0.observer != nil }
    }

    private func clearObservers() {
        observers = observers.filter { $0.observer != nil }
    }
}
