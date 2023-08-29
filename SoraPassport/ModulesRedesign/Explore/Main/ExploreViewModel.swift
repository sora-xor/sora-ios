import UIKit
import SoraUIKit
import CommonWallet
import RobinHood
import BigInt
import IrohaCrypto

protocol DiscoverViewModelProtocol {
    var snapshotPublisher: Published<ExploreSnapshot>.Publisher { get }
    func setup()
}

class ExploreSection {
    var id = UUID()
    var items: [ExploreSectionItem]
    
    init(items: [ExploreSectionItem]) {
        self.items = items
    }
}

enum ExploreSectionItem: Hashable {
    case assets(ExploreAssetsItem)
    case pools(ExplorePoolsItem)
}

extension ExploreSection: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ExploreSection, rhs: ExploreSection) -> Bool {
        lhs.id == rhs.id
    }
}


typealias ExploreDataSource = UITableViewDiffableDataSource<ExploreSection, ExploreSectionItem>
typealias ExploreSnapshot = NSDiffableDataSourceSnapshot<ExploreSection, ExploreSectionItem>

final class ExploreViewModel {
    @Published var snapshot: ExploreSnapshot = ExploreSnapshot()
    var snapshotPublisher: Published<ExploreSnapshot>.Publisher { $snapshot }
    
    var wireframe: ExploreWireframeProtocol
    var view: ControllerBackedProtocol?
    
    weak var accountPoolsService: AccountPoolsService?
    var assetViewModelsService: ExploreAssetViewModelService
    var poolViewModelsService: ExplorePoolViewModelService

    init(wireframe: ExploreWireframeProtocol,
         accountPoolsService: AccountPoolsService,
         assetViewModelsService: ExploreAssetViewModelService,
         poolViewModelsService: ExplorePoolViewModelService) {
        self.wireframe = wireframe
        self.accountPoolsService = accountPoolsService
        self.assetViewModelsService = assetViewModelsService
        self.poolViewModelsService = poolViewModelsService
    }
    
    private func createSnapshot() -> ExploreSnapshot {
        var snapshot = ExploreSnapshot()

        let assetsItem = ExploreAssetsItem(title: R.string.localizable .commonCurrencies(preferredLanguages: .currentLocale),
                                           subTitle: R.string.localizable.exploreSwapTokensOnSora(preferredLanguages: .currentLocale),
                                           viewModelService: assetViewModelsService)
        assetsItem.assetHandler = { [weak self] assetId in
            self?.wireframe.showAssetDetails(on: self?.view?.controller, assetId: assetId)
        }
        
        assetsItem.expandHandler = { [weak self] in
            guard let self = self else { return }
            self.wireframe.showAssetList(on: self.view?.controller, viewModelService: self.assetViewModelsService)
        }
        
        let poolItem = ExplorePoolsItem(title: R.string.localizable.discoveryPolkaswapPools(preferredLanguages: .currentLocale),
                                        subTitle: R.string.localizable.exploreProvideAndEarn(preferredLanguages: .currentLocale),
                                        viewModelService: poolViewModelsService)

        poolItem.poolHandler = { [weak self] pool in
            let poolId = pool.poolId ?? ""
            let baseAssetId = pool.baseAssetId ?? ""
            let targetAssetId = pool.targetAssetId ?? ""
            let account = SelectedWalletSettings.shared.currentAccount
            let accountId = (try? SS58AddressFactory().accountId(fromAddress: account?.address ?? "",
                                                                type: account?.networkType ?? 0).toHex(includePrefix: true)) ?? ""
            
            guard let poolInfo = self?.accountPoolsService?.getPool(by: poolId) else {
                
                let poolInfo = PoolInfo(baseAssetId: baseAssetId, targetAssetId: targetAssetId, poolId: poolId, accountId: accountId)
                self?.wireframe.showAccountPoolDetails(on: self?.view?.controller, poolInfo: poolInfo)
                return
            }
            self?.wireframe.showAccountPoolDetails(on: self?.view?.controller, poolInfo: poolInfo)
        }

        poolItem.expandHandler = { [weak self] in
            guard let self = self else { return }
            self.wireframe.showPoolList(on: self.view?.controller, viewModelService: self.poolViewModelsService)
        }

        let sections = [ ExploreSection(items: [ .assets(assetsItem), .pools(poolItem) ]) ]
        snapshot.appendSections(sections)
        sections.forEach { snapshot.appendItems($0.items, toSection: $0) }
        
        return snapshot
    }
}

extension ExploreViewModel: DiscoverViewModelProtocol {
    func setup() {
        snapshot = createSnapshot()
        assetViewModelsService.setup()
        poolViewModelsService.setup()
    }
}
