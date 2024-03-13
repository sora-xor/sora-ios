// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import UIKit
import SoraUIKit

import SoraFoundation

final class ActivityViewModel {
    @Published var snapshot: ActivitySnapshot = ActivitySnapshot()
    var snapshotPublisher: Published<ActivitySnapshot>.Publisher { $snapshot }

    var setupEmptyLabel: (() -> Void)?
    var setupErrorContent: (() -> Void)?
    var hideErrorContent: (() -> Void)?

    weak var view: ActivityViewProtocol?
    var sections: [ActivitySection] = []
    let historyService: HistoryServiceProtocol
    var viewModelFactory: ActivityViewModelFactoryProtocol
    let eventCenter: EventCenterProtocol
    let wireframe: ActivityWireframeProtocol
    let assetManager: AssetManagerProtocol
    var assetId: String?
    var title: String = ""
    var isNeedCloseButton: Bool = false
    var pageNumber = 0
    private var task: Task<Void, Swift.Error>?

    init(historyService: HistoryServiceProtocol,
         viewModelFactory: ActivityViewModelFactoryProtocol,
         wireframe: ActivityWireframeProtocol,
         assetManager: AssetManagerProtocol,
         eventCenter: EventCenterProtocol,
         assetId: String? = nil) {
        self.historyService = historyService
        self.viewModelFactory = viewModelFactory
        self.eventCenter = eventCenter
        self.wireframe = wireframe
        self.assetManager = assetManager
        self.assetId = assetId
        self.eventCenter.add(observer: self)
    }
}

extension ActivityViewModel: ActivityViewModelProtocol {
    func viewDidLoad() {
        guard sections.isEmpty else { return }

        sections = viewModelFactory.createActivityShimmerModels()
        snapshot = createSnapshot()
        Task { [weak self] in
            await self?.loadContent()
        }
    }

    func updateContent() {
        if !sections.isEmpty {
            view?.startPaginationLoader()
        }

        if pageNumber > 0 {
            Task { [weak self] in
                await self?.loadContent()
            }
        }
    }

    private func incrementPage() {
        pageNumber += 1
    }

    private func reload() {
        incrementPage()
        view?.stopPaginationLoader()
        snapshot = createSnapshot()
    }

    private func createSnapshot() -> ActivitySnapshot {
        var snapshot = ActivitySnapshot()
        snapshot.appendSections(sections)
        sections.forEach { snapshot.appendItems($0.items, toSection: $0) }

        return snapshot
    }

    private func contentSection(with items: [ActivitySectionItem]) -> [ActivitySection] {
        return [ActivitySection(items: items)]
    }

    private func loadContent() async {
        do {
            let page = try await historyService.getPageHistory(count: 50, page: pageNumber + 1, assetId: assetId)

            if pageNumber == 0 {
                sections = []
            }
            
            view?.stopAnimating()
            
            if pageNumber == 0 && page.transactions.isEmpty && page.errorMessage == nil {
                sections = []
                snapshot = createSnapshot()
                setupEmptyLabel?()
                return
            }

            if pageNumber == 0 && page.errorMessage != nil && page.transactions.isEmpty {
                sections = []
                snapshot = createSnapshot()
                setupErrorContent?()
                return
            }

            hideErrorContent?()

            var sections: [ActivitySection] = self.viewModelFactory.createActivityViewModels(with: page.transactions) { [weak self] model in
                guard let self = self, let view = self.view else { return }
                self.wireframe.showActivityDetails(on: view.controller, model: model, assetManager: self.assetManager)
            }

            if page.errorMessage != nil {
                let errorItem = ActivityErrorItem()
                errorItem.handler = { [weak self] in
                    self?.view?.resetPagination()
                }

                sections.insert(contentsOf: contentSection(with: [.error(errorItem)]), at: 0)
                
                let activityItemCount = self.sections.reduce(0) { partialResult, section in
                    partialResult + section.items.filter { $0.isActivity }.count
                }

                let dateItemCount = self.sections.compactMap { $0.date }.count

                let tabBarSize = 30
                let visibleHeight = await Int(UIScreen.main.bounds.height) - tabBarSize - (activityItemCount * 56 + dateItemCount * 32)
                let spacerItem: ActivitySectionItem = .space(SoramitsuTableViewSpacerItem(space: visibleHeight > 30 ? CGFloat(visibleHeight) : 30))
                sections.append(contentsOf: contentSection(with: [spacerItem]))
            }

            updateSections(with: sections)
            
            let updateSections = Set(sections)
            let currentSectionsSet = Set(self.sections)
            if !updateSections.intersection(currentSectionsSet).isEmpty {
                reload()
            }
        } catch {
            guard pageNumber == 0 else { return }
            setupErrorContent?()
        }
    }

    private func updateSections(with sections: [ActivitySection]) {
        sections.forEach { [weak self] section in
            guard let date = section.date else {
                self?.sections.append(section)
                return
            }

            if let index = self?.sections.firstIndex(where: { $0.date == date }) {
                self?.sections[index].items.append(contentsOf: section.items)
                return
            }

            self?.sections.append(section)
        }
    }

    func didSelect(with item: ActivitySectionItem) {
        switch item {
        case .activity(let activityItem):
            activityItem.handler?()
        case .error(let errorItem):
            errorItem.handler?()
        default:
            return
        }
    }

    func headerText(for section: Int) -> String? {
        guard sections.count > section, let date = sections[section].date else { return nil }
        return date.uppercased()
    }

    func isNeedHeader(for section: Int) -> Bool {
        guard sections.count > section else { return false }
        return sections[section].date != nil
    }

    func resetPagination() {
        viewModelFactory.currentDate = nil
        pageNumber = 0
        sections = []

        task?.cancel()
        task = Task { [weak self] in
            await self?.loadContent()
        }
    }
}

extension ActivityViewModel: EventVisitorProtocol {

    func processNewTransactionCreated(event: NewTransactionCreatedEvent) {
        DispatchQueue.main.async {
            self.view?.resetPagination()
        }
    }

    func processNewTransaction(event: WalletNewTransactionInserted) {
        DispatchQueue.main.async {
            self.view?.resetPagination()
        }
    }
}

extension ActivityViewModel: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    func applyLocalization() {
        self.view?.resetPagination()
    }
}
