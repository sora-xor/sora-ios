import SoraUI
import IrohaCrypto
import SoraKeystore
import CoreGraphics
import CommonWallet

protocol ReferralViewFactoryProtocol {
    static func createReferrerView(with referrer: String) -> UIViewController
    static func createInputLinkView(with delegate: InputLinkPresenterOutput) -> UIViewController?
    static func createInputRewardAmountView(with fee: Decimal,
                                            bondedAmount: Decimal,
                                            type: InputRewardAmountType,
                                            walletContext: CommonWalletContextProtocol,
                                            delegate: InputRewardAmountPresenterOutput) -> UIViewController?
    static func createActivityDetailsView(assetManager: AssetManagerProtocol, model: Transaction, completion: (() -> Void)?) -> UIViewController?
}

final class ReferralViewFactory: ReferralViewFactoryProtocol {
    static func createReferrerView(with referrer: String) -> UIViewController {
        let titleText = R.string.localizable.referralYourReferrer(preferredLanguages: .currentLocale)
        let descriptionText = R.string.localizable.referralReferrerDescription(preferredLanguages: .currentLocale)

        let view = ReferrerView(frame: .zero)
        view.titleLabel.text = titleText
        view.descriptionLabel.text = descriptionText
        view.referrersTitleLabel.text = R.string.localizable.referralReferrerAddress(preferredLanguages: .currentLocale)
        view.referrersAddressLabel.text = referrer

        let preferredTitleSize = CGSize(width: UIScreen.main.bounds.width - 24 * 2, height: .greatestFiniteMagnitude)

        let topHeaderOffset: CGFloat = 20

        let headerHeight: CGFloat = titleText.drawingSize(for: preferredTitleSize,
                                                          font: UIFont.styled(for: .title4).withSize(11.0),
                                                          options: .usesLineFragmentOrigin).height

        let bottomHeaderOffset: CGFloat = 16

        let descriptionHeight = descriptionText.drawingSize(for: preferredTitleSize,
                                                            font: UIFont.styled(for: .paragraph1),
                                                            options: .usesLineFragmentOrigin).height

        let descriptionBottomOffset: CGFloat = 24

        let titleHeight: CGFloat = 16

        let titleBottomOffset: CGFloat = 4

        let addressHeight: CGFloat = 16

        let addressBottomOffset: CGFloat = 52

        let height = [topHeaderOffset,
                      headerHeight,
                      bottomHeaderOffset,
                      descriptionHeight,
                      descriptionBottomOffset,
                      titleHeight,
                      titleBottomOffset,
                      addressHeight,
                      addressBottomOffset].reduce(0, +)

        let viewController = UIViewController()
        viewController.view = view
        viewController.preferredContentSize = CGSize(width: 0.0, height: height)

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.neu)
        viewController.modalTransitioningFactory = factory
        viewController.modalPresentationStyle = .custom

        return viewController
    }

    static func createInputLinkView(with delegate: InputLinkPresenterOutput) -> UIViewController? {
        let settings = SettingsManager.shared
        let keychain = Keychain()
        let chainId = Chain.sora.genesisHash()
        guard let engine = ChainRegistryFacade.sharedRegistry.getConnection(for: chainId),
              let runtimeRegistry = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: chainId),
              let selectedAccount = SelectedWalletSettings.shared.currentAccount else { return nil }


        let operationFactory = ReferralsOperationFactory(settings: settings,
                                                         keychain: keychain,
                                                         engine: engine, runtimeRegistry: runtimeRegistry,
                                                         selectedAccount: selectedAccount)

        let interactor = InputLinkInteractor(operationManager: OperationManagerFacade.sharedManager,
                                             operationFactory: operationFactory,
                                             addressFactory: SS58AddressFactory(),
                                             selectedAccountAddress: selectedAccount.address)

        let presenter = InputLinkPresenter()
        presenter.interactor = interactor
        presenter.output = delegate

        interactor.presenter = presenter

        let view = InputLinkViewController(presenter: presenter)
        presenter.view = view

        return view
    }

    static func createInputRewardAmountView(with fee: Decimal,
                                            bondedAmount: Decimal,
                                            type: InputRewardAmountType,
                                            walletContext: CommonWalletContextProtocol,
                                            delegate: InputRewardAmountPresenterOutput) -> UIViewController? {
        let settings = SettingsManager.shared
        let keychain = Keychain()
        let chainId = Chain.sora.genesisHash()
        let assetManager = ChainRegistryFacade.sharedRegistry.getAssetManager(for: chainId)

        guard let engine = ChainRegistryFacade.sharedRegistry.getConnection(for: chainId),
              let runtimeRegistry = ChainRegistryFacade.sharedRegistry.getRuntimeProvider(for: chainId),
              let selectedAccount =  SelectedWalletSettings.shared.currentAccount,
              let feeAsset = assetManager.getAssetList()?.first(where: { $0.isFeeAsset }) else { return nil }
        let operationFactory = ReferralsOperationFactory(settings: settings,
                                                         keychain: keychain,
                                                         engine: engine, runtimeRegistry: runtimeRegistry,
                                                         selectedAccount: selectedAccount)

        let interactor = InputRewardAmountInteractor(networkFacade: walletContext.networkOperationFactory,
                                                     operationFactory: operationFactory,
                                                     feeAsset: feeAsset)

        let presenter = InputRewardAmountPresenter(fee: fee,
                                                   previousBondedAmount: bondedAmount,
                                                   type: type,
                                                   interactor: interactor,
                                                   feeAsset: feeAsset)
        presenter.output = delegate
        interactor.presenter = presenter

        let view = InputRewardAmountViewController(presenter: presenter)
        presenter.view = view
        
        return view
    }
    
    static func createActivityDetailsView(assetManager: AssetManagerProtocol, model: Transaction, completion: (() -> Void)?) -> UIViewController? {
        guard let selectedAccount = SelectedWalletSettings.shared.currentAccount,
              let assetList = assetManager.getAssetList()
        else { return nil }
        
        let historyService = HistoryService(operationManager: OperationManagerFacade.sharedManager,
                                            address: selectedAccount.address,
                                            assets: assetList)
        
        let factory = ActivityDetailsViewModelFactory(assetManager: assetManager)
        let viewModel = ActivityDetailsViewModel(model: model,
                                                 wireframe: ActivityDetailsWireframe(),
                                                 assetManager: assetManager,
                                                 detailsFactory: factory,
                                                 historyService: historyService,
                                                 lpServiceFee: LPFeeService())
        viewModel.completion = completion
        
        let view = ActivityDetailsViewController(viewModel: viewModel)
        viewModel.view = view
        
        return view
    }
}
