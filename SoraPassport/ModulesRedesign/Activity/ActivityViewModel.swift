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
