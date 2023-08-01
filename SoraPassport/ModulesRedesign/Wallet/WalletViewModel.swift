import UIKit
import SoraUIKit
import CommonWallet
import RobinHood
import SCard
import SoraFoundation
import SoraKeystore

protocol RedesignWalletViewModelProtocol: AnyObject {
    var reloadItem: (([SoramitsuTableViewItemProtocol]) -> Void)? { get set }
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)? { get set }
    func fetchAssets(completion: @escaping ([SoramitsuTableViewItemProtocol]) -> Void)
    func closeSC()
    func closeReferralProgram()
    func updateItems()
    func updateAssets()
    func showFullListAssets()
    func showFullListPools()
    func showAssetDetails(with assetInfo: AssetInfo)
    func showPoolDetails(with pool: PoolInfo)
    func showSoraCardDetails()
    func showInternerConnectionAlert()
    func showReferralProgram(assetManager: AssetManagerProtocol)
}

final class RedesignWalletViewModel {
    
    var reloadItem: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    
    var providerFactory: BalanceProviderFactory
    var assetManager: AssetManagerProtocol
    let fiatService: FiatServiceProtocol
    
    var walletItems: [SoramitsuTableViewItemProtocol] = []
    
    var isReferralProgramHidden: Bool = false
    
    weak var view: RedesignWalletViewProtocol?
    var wireframe: RedesignWalletWireframeProtocol?
    var itemFactory: WalletItemFactoryProtocol
    let networkFacade: WalletNetworkOperationFactoryProtocol
    let polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol
    let poolService: PoolsServiceInputProtocol
    let accountId: String
    let address: String
    let qrEncoder: WalletQREncoderProtocol
    let sharingFactory: AccountShareFactoryProtocol
    private let accountRepository: AnyDataProviderRepository<AccountItem>
    var referralFactory: ReferralsOperationFactoryProtocol
    var assetsProvider: AssetProviderProtocol
    var walletContext: CommonWalletContextProtocol
    let feeProvider = FeeProvider()
    
    init(wireframe: RedesignWalletWireframeProtocol?,
         providerFactory: BalanceProviderFactory,
         assetManager: AssetManagerProtocol,
         fiatService: FiatServiceProtocol,
         itemFactory: WalletItemFactoryProtocol,
         networkFacade: WalletNetworkOperationFactoryProtocol,
         accountId: String,
         address: String,
         polkaswapNetworkFacade: PolkaswapNetworkOperationFactoryProtocol,
         qrEncoder: WalletQREncoderProtocol,
         sharingFactory: AccountShareFactoryProtocol,
         poolsService: PoolsServiceInputProtocol,
         referralFactory: ReferralsOperationFactoryProtocol,
         assetsProvider: AssetProviderProtocol,
         walletContext: CommonWalletContextProtocol) {
        self.wireframe = wireframe
        self.accountId = accountId
        self.address = address
        self.providerFactory = providerFactory
        self.assetManager = assetManager
        self.fiatService = fiatService
        self.itemFactory = itemFactory
        self.networkFacade = networkFacade
        self.polkaswapNetworkFacade = polkaswapNetworkFacade
        self.qrEncoder = qrEncoder
        self.sharingFactory = sharingFactory
        self.referralFactory = referralFactory
        self.assetsProvider = assetsProvider
        self.accountRepository = AnyDataProviderRepository(
            UserDataStorageFacade.shared
            .createRepository(filter: nil,
                              sortDescriptors: [],
                              mapper: AnyCoreDataMapper(AccountItemMapper()))
        )
        self.poolService = poolsService
        self.walletContext = walletContext
    }

    @SCStream private var xorBalanceStream = SCStream<Decimal>(wrappedValue: Decimal(0))
}

extension RedesignWalletViewModel: RedesignWalletViewModelProtocol {

    func closeSC() {
        SCard.shared?.isSCBannerHidden = true
    }
    
    func closeReferralProgram() {
        isReferralProgramHidden = true
    }
    
    func updateItems() {
        walletItems = buildItems()
        setupItems?(walletItems)
    }

    func updateAssets() {
        if let assetItem = walletItems.first(where: { $0 is AssetsItem }) as? AssetsItem {
            assetItem.updateContent()
        }

        if let poolItem = walletItems.first(where: { $0 is PoolsItem }) as? PoolsItem {
            poolItem.poolsService?.loadPools(isNeedForceUpdate: false)
        }
    }
    

    func fetchAssets(completion: @escaping ([SoramitsuTableViewItemProtocol]) -> Void) {
        walletItems = buildItems()
        completion(walletItems)
    }

    func showSoraCardDetails() {
        let assets = assetManager.getAssetList()?.filter { $0.assetId == WalletAssetId.xor.rawValue } ?? []
        let balanceProvider = try? providerFactory.createBalanceDataProvider(for: assets, onlyVisible: false)
        wireframe?.showSoraCard(on: view?.controller, address: address, balanceProvider: balanceProvider)
    }

    private func buildItems() -> [SoramitsuTableViewItemProtocol] {
        
        var items: [SoramitsuTableViewItemProtocol] = []
        
        let accountItem = itemFactory.createAccountItem(with: self ,
                                                        view: view,
                                                        wireframe: wireframe,
                                                        feeProvider: feeProvider,
                                                        assetManager: assetManager,
                                                        assetsProvider: assetsProvider,
                                                        fiatService: fiatService,
                                                        networkFacade: networkFacade,
                                                        providerFactory: providerFactory,
                                                        qrEncoder: qrEncoder,
                                                        sharingFactory: sharingFactory,
                                                        accountRepository: accountRepository,
                                                        reloadItem: reloadItem)
        
        items.append(accountItem)

        let soraCard = initSoraCard()
        if !soraCard.isSCBannerHidden && ConfigService.shared.config.isSoraCardEnabled {
            let soraCardItem: SoramitsuTableViewItemProtocol = itemFactory.createSoraCardItem(with: self,
                                                                                              service: soraCard)
            items.append(soraCardItem)
        }
       
        if !isReferralProgramHidden {
            let friendsItem: SoramitsuTableViewItemProtocol = itemFactory.createInviteFriendsItem(with: self,
                                                    assetManager: assetManager)
            items.append(friendsItem)
        }
      
        let assetItem: SoramitsuTableViewItemProtocol = itemFactory.createAssetsItem(with: self,
                                                                                     assetManager: assetManager,
                                                                                     assetsProvider: assetsProvider,
                                                                                     fiatService: fiatService)
        items.append(assetItem)
        
        let poolItem: SoramitsuTableViewItemProtocol = itemFactory.createPoolsItem(with: self,
                                                                                   poolService: poolService,
                                                                                   networkFacade: networkFacade,
                                                                                   polkaswapNetworkFacade: polkaswapNetworkFacade,
                                                                                   assetManager: assetManager,
                                                                                   fiatService: fiatService)
        items.append(poolItem)
        
        let editViewItem: SoramitsuTableViewItemProtocol = itemFactory.createEditViewItem(with: self)
        items.append(editViewItem)
        
        return items
    }

    private func initSoraCard() -> SCard {
        guard SCard.shared == nil else { return SCard.shared! }

        let balanceProvider = try? providerFactory.createBalanceDataProvider(for: [.xor], onlyVisible: false)
        let changesBlock = { [weak self] (changes: [DataProviderChange<[BalanceData]>]) -> Void in
            guard let change = changes.first else { return }
            switch change {
            case .insert(let items), .update(let items):
                guard let balane = items.first?.balance.decimalValue else { return }
                self?.xorBalanceStream.wrappedValue = balane
                return
            case .delete(_):
                break
            }
        }

        balanceProvider?.addObserver(
            self,
            deliverOn: .main,
            executing: changesBlock,
            failing: { (error: Error) in },
            options: DataProviderObserverOptions(alwaysNotifyOnRefresh: true)
        )

        var refreshBalanceTimer = Timer()
        refreshBalanceTimer.invalidate()
        refreshBalanceTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [refreshBalanceTimer] _ in
            balanceProvider?.refresh()
        }

        let scConfig = SCard.Config(
            backendUrl: SoraCardCIKeys.backendDevUrl,
            pwAuthDomain: SoraCardCIKeys.domain,
            pwApiKey: SoraCardCIKeys.apiKey,
            kycUrl: SoraCardCIKeys.endpoint,
            kycUsername: SoraCardCIKeys.username,
            kycPassword: SoraCardCIKeys.password,
            xOneEndpoint: "",
            xOneId: "",
            environmentType: .test,
            themeMode: SoramitsuUI.shared.themeMode
        )

        let soraCard = SCard(
            addressProvider: { [weak self] in SelectedWalletSettings.shared.currentAccount?.address ?? ""
            },
            config: scConfig,
            balanceStream: xorBalanceStream,
            onSwapController: { [weak self] vc in
                self?.showSwapController(in: vc)
            }
        )

        SCard.shared = soraCard

        LocalizationManager.shared.addObserver(with: soraCard) { [weak soraCard] (_, newLocalization) in
            soraCard?.selectedLocalization = newLocalization
        }

        return soraCard
    }

    private func showSwapController(in vc: UIViewController) {
        guard let swapController = createSwapController(presenter: vc) else { return }
        vc.present(swapController, animated: true)
    }

    private func createSwapController(
        presenter: UIViewController,
        localizationManager: LocalizationManagerProtocol = LocalizationManager.shared
    ) -> UIViewController? {

        guard
            let connection = ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash()),
            let walletContext = try? WalletContextFactory().createContext(connection: connection)
        else {
            return nil
        }

        let assetManager = ChainRegistryFacade.sharedRegistry.getAssetManager(for: Chain.sora.genesisHash())
        assetManager.setup(for: SelectedWalletSettings.shared)


        guard let connection = ChainRegistryFacade.sharedRegistry.getConnection(for: Chain.sora.genesisHash()) else {
            return nil
        }

        let polkaswapContext = PolkaswapNetworkOperationFactory(engine: connection)

        guard let swapController = SwapViewFactory.createView(selectedTokenId: "",
                                                              selectedSecondTokenId: WalletAssetId.xor.rawValue,
                                                              assetManager: assetManager,
                                                              fiatService: FiatService.shared,
                                                              networkFacade: walletContext.networkOperationFactory,
                                                              polkaswapNetworkFacade: polkaswapContext,
                                                              assetsProvider: assetsProvider) else { return nil }

        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.commonAssets(preferredLanguages: locale.rLanguages)
        }

        localizationManager.addObserver(with: swapController) { [weak swapController] (_, _) in
            let currentTitle = localizableTitle.value(for: localizationManager.selectedLocale)
            swapController?.tabBarItem.title = currentTitle
        }

        return swapController
    }
    
    func showInternerConnectionAlert() {
        wireframe?.present(message: nil,
                           title: R.string.localizable.connectionErrorMessage(preferredLanguages: .currentLocale),
                           closeAction: R.string.localizable.commonOk(preferredLanguages: .currentLocale),
                           from: view)
    }

    func showFullListAssets() {
        let assets = assetManager.getAssetList() ?? []
        let factory = AssetViewModelFactory(walletAssets: assets,
                                            assetManager: assetManager,
                                            fiatService: fiatService)
        
        wireframe?.showFullListAssets(on: view?.controller,
                                      assetManager: assetManager,
                                      fiatService: fiatService,
                                      assetViewModelFactory: factory,
                                      providerFactory: providerFactory,
                                      poolService: poolService,
                                      networkFacade: networkFacade,
                                      accountId: accountId,
                                      address: address,
                                      polkaswapNetworkFacade: polkaswapNetworkFacade,
                                      qrEncoder: qrEncoder,
                                      sharingFactory: sharingFactory,
                                      referralFactory: referralFactory,
                                      assetsProvider: assetsProvider,
                                      updateHandler: updateAssets)
    }
    
    func showFullListPools() {
        let factory = PoolViewModelFactory(walletAssets: assetManager.getAssetList() ?? [],
                                            assetManager: assetManager,
                                           fiatService: fiatService)
        
        wireframe?.showFullListPools(on: view?.controller,
                                     poolService: poolService,
                                     networkFacade: networkFacade,
                                     polkaswapNetworkFacade: polkaswapNetworkFacade,
                                     assetManager: assetManager,
                                     fiatService: fiatService,
                                     poolViewModelFactory: factory,
                                     providerFactory: providerFactory,
                                     operationFactory: networkFacade,
                                     assetsProvider: assetsProvider)
    }
    
    func showAssetDetails(with assetInfo: AssetInfo) {
        let factory = AssetViewModelFactory(walletAssets: [assetInfo],
                                            assetManager: assetManager,
                                            fiatService: fiatService)
        
        let poolFactory = PoolViewModelFactory(walletAssets: assetManager.getAssetList() ?? [],
                                            assetManager: assetManager,
                                               fiatService: fiatService)
        
        wireframe?.showAssetDetails(on: view?.controller,
                                    assetInfo: assetInfo,
                                    assetManager: assetManager,
                                    fiatService: fiatService,
                                    assetViewModelFactory: factory,
                                    poolsService: poolService,
                                    poolViewModelsFactory: poolFactory,
                                    providerFactory: providerFactory,
                                    networkFacade: networkFacade,
                                    accountId: accountId,
                                    address: address,
                                    polkaswapNetworkFacade: polkaswapNetworkFacade,
                                    qrEncoder: qrEncoder,
                                    sharingFactory: sharingFactory,
                                    referralFactory: referralFactory,
                                    assetsProvider: assetsProvider)
    }
    
    func showPoolDetails(with pool: PoolInfo) {
        wireframe?.showPoolDetails(on: view?.controller,
                                   poolInfo: pool,
                                   assetManager: assetManager,
                                   fiatService: fiatService,
                                   poolsService: poolService,
                                   providerFactory: providerFactory,
                                   operationFactory: networkFacade,
                                   assetsProvider: assetsProvider)
    }
    
    func showReferralProgram(assetManager: AssetManagerProtocol) {
        wireframe?.showReferralProgram(from: view,
                                       walletContext: walletContext,
                                       assetManager: assetManager)
    }
}
