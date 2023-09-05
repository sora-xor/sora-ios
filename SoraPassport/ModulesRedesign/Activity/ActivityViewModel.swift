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
import CommonWallet
import SoraFoundation

protocol ActivityViewModelProtocol: SoramitsuTableViewPaginationHandlerProtocol {
    var title: String { get set }
    var isNeedCloseButton: Bool { get }
    var appendItems: (([SoramitsuTableViewItemProtocol]) -> Void)? { get set }
    var setupEmptyLabel: (() -> Void)? { get set }
    var setupErrorContent: (() -> Void)? { get set }
    var hideErrorContent: (() -> Void)? { get set }
}

final class ActivityViewModel {
    var appendItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var setupEmptyLabel: (() -> Void)?
    var setupErrorContent: (() -> Void)?
    var hideErrorContent: (() -> Void)?
    
    weak var view: ActivityViewProtocol?
    var items: [SoramitsuTableViewItemProtocol] = []
    let historyService: HistoryServiceProtocol
    var viewModelFactory: ActivityViewModelFactoryProtocol
    let eventCenter: EventCenterProtocol
    let wireframe: ActivityWireframeProtocol
    let assetManager: AssetManagerProtocol
    var assetId: String?
    var title: String = ""
    var isNeedCloseButton: Bool = false
    
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
}

extension ActivityViewModel: SoramitsuTableViewPaginationHandlerProtocol {
    
    public var paginationType: PaginationType { return .bottom }
    
    public func didRequestNewPage(with pageNumber: Int, completion: @escaping (NextPageLoadResult) -> Void) {
        if pageNumber == 0 {
            viewModelFactory.currentDate = nil
        }

        historyService.getPageHistory(count: 50, page: pageNumber + 1, assetId: assetId) { [weak self] result in
            guard let self = self else { return }
            if pageNumber == 0 {
                self.items = []
            }
            
            self.view?.stopAnimating()
            switch result {
            case .success(let page):
                if pageNumber == 0 && page.transactions.isEmpty && page.errorMessage == nil {
                    self.setupEmptyLabel?()
                    return
                }

                if pageNumber == 0 && page.errorMessage != nil && page.transactions.isEmpty {
                    self.setupErrorContent?()
                    return
                }
                
                self.hideErrorContent?()
                
                var items = self.viewModelFactory.createActivityViewModels(with: page.transactions) { [weak self] model in
                    guard let self = self, let view = self.view else { return }
                    self.wireframe.showActivityDetails(on: view.controller, model: model, assetManager: self.assetManager)
                }

                if page.errorMessage != nil {
                    let errorItem = ActivityErrorItem()
                    errorItem.handler = { [weak self] in
                        self?.view?.resetPagination()
                    }
                    items.insert(errorItem, at: 0)
                    self.items += items
                    
                    let activityItemCount = self.items.filter { $0 is ActivityItem }.count
                    let dateItemCount = self.items.filter { $0 is ActivityDateItem }.count
                    let tabBarSize = 30
                    let visibleHeight = Int(UIScreen.main.bounds.height) - tabBarSize - (activityItemCount * 56 + dateItemCount * 32)
                    items.append(SoramitsuTableViewSpacerItem(space: visibleHeight > 30 ? CGFloat(visibleHeight) : 30, color: .bgSurface))
                    completion(.loadingSuccessWithItems(items, hasNextPage: !page.endReached))
                    return
                }
                
                if pageNumber == 0, let firstSectionItem = items.first as? ActivityDateItem {
                    firstSectionItem.isFirstSection = true
                    items[0] = firstSectionItem
                }
                self.items += items

                if page.endReached, !self.items.isEmpty {
                    let activityItemCount = self.items.filter { $0 is ActivityItem }.count
                    let dateItemCount = self.items.filter { $0 is ActivityDateItem }.count
                    let tabBarSize = 30
                    let visibleHeight = Int(UIScreen.main.bounds.height) - tabBarSize - (activityItemCount * 56 + dateItemCount * 32)
                    items.append(SoramitsuTableViewSpacerItem(space: visibleHeight > 30 ? CGFloat(visibleHeight) : 30, color: .bgSurface))
                }
                completion(.loadingSuccessWithItems(items, hasNextPage: !page.endReached))
                
            case .failure:
                guard pageNumber == 0 else { return }
                self.setupErrorContent?()
            }
        }
    }
    
    func possibleToMakePullToRefresh() -> Bool {
        return assetId == nil
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
