import UIKit
import SoraUIKit
import CommonWallet
import RobinHood

enum GenerateQRMode {
    case receive
    case request
}

protocol GenerateQRViewModelProtocol {
    var setupSwicherView: ((SwitcherViewModel) -> Void)? { get set }
    var setupReceiveView: ((ReceiveQRViewModel) -> Void)? { get set }
    var setupRequestView: ((InputSendInfoViewModel) -> Void)? { get set }
    var updateContent: ((GenerateQRMode) -> Void)? { get set }
    var showShareContent: (([Any]) -> Void)? { get set }
    func viewDidLoad()
}

final class GenerateQRViewModel {
    var setupReceiveView: ((ReceiveQRViewModel) -> Void)?
    var setupSwicherView: ((SwitcherViewModel) -> Void)?
    var setupRequestView: ((InputSendInfoViewModel) -> Void)?
    var updateContent: ((GenerateQRMode) -> Void)?
    var showShareContent: (([Any]) -> Void)?
    
    weak var view: GenerateQRViewProtocol?
    var wireframe: GenerateQRWireframeProtocol?
    private var qrService: WalletQRServiceProtocol
    private var sharingFactory: AccountShareFactoryProtocol
    private var accountId: String
    private var address: String
    private let accountRepository: AnyDataProviderRepository<AccountItem>
    private let qrEncoder: WalletQREncoderProtocol
    private var appEventService = AppEventService()
    
    private var mode: GenerateQRMode = .receive {
        didSet(oldValue) {
            guard oldValue != mode else { return }
            requestModel.isSelected = mode == .request
            reveiveModel.isSelected = mode == .receive
            setupSwicherView?(swicherViewModel)
            updateContent?(mode)
        }
    }
    
    private lazy var reveiveModel: SwitcherButtonViewModel = {
        var reveiveModel = SwitcherButtonViewModel(title: R.string.localizable.commonReceive(preferredLanguages: .currentLocale),
                                                   isSelected: true)
        reveiveModel.actionBlock = { [weak self] in
            self?.mode = .receive
        }
        return reveiveModel
    }()
    
    private lazy var requestModel: SwitcherButtonViewModel = {
        var requestModel = SwitcherButtonViewModel(title: R.string.localizable.commonRequest(preferredLanguages: .currentLocale),
                                                isSelected: false)
        requestModel.actionBlock = { [weak self] in
            self?.mode = .request
        }
        return requestModel
    }()
    
    private lazy var swicherViewModel = SwitcherViewModel(buttonViewModels: [ reveiveModel, requestModel ])
    
    private lazy var requestViewModel = InputSendInfoViewModel(address: address,
                                                               accountId: accountId,
                                                               fiatService: fiatService,
                                                               assetManager: assetManager,
                                                               assetsProvider: assetsProvider,
                                                               wireframe: wireframe,
                                                               qrEncoder: qrEncoder,
                                                               sharingFactory: sharingFactory)

    private var currentImage: UIImage?
    private let fiatService: FiatServiceProtocol?
    private let assetManager: AssetManagerProtocol?
    private let assetsProvider: AssetProviderProtocol?
    
    init(
        qrService: WalletQRServiceProtocol,
        sharingFactory: AccountShareFactoryProtocol,
        accountId: String,
        address: String,
        fiatService: FiatServiceProtocol?,
        assetManager: AssetManagerProtocol?,
        assetsProvider: AssetProviderProtocol?,
        qrEncoder: WalletQREncoderProtocol
    ) {
        self.qrService = qrService
        self.sharingFactory = sharingFactory
        self.accountId = accountId
        self.address = address
        self.fiatService = fiatService
        self.assetManager = assetManager
        self.assetsProvider = assetsProvider
        self.qrEncoder = qrEncoder

        self.accountRepository = AnyDataProviderRepository(
            UserDataStorageFacade.shared
            .createRepository(filter: nil,
                              sortDescriptors: [],
                              mapper: AnyCoreDataMapper(AccountItemMapper()))
        )

    }
}

extension GenerateQRViewModel: GenerateQRViewModelProtocol {
    func viewDidLoad() {
        requestViewModel.viewDidLoad()
        generateQR()
        setupSwicherView?(swicherViewModel)
        setupRequestView?(requestViewModel)
    }
}

private extension GenerateQRViewModel {
    func generateQR() {
        guard let receiveInfo = createGenerateQRInfo() else { return }
        
        let size = UIScreen.main.bounds.width - 112
        let qrSize = CGSize(width: size, height: size)
        try? qrService.generate(from: receiveInfo, qrSize: qrSize, runIn: .main) { [weak self] operationResult in
            guard case .success(let image) = operationResult else { return }
            self?.currentImage = image
            self?.processOperation()
        }
    }
    
    func processOperation() {
        let persistentOperation = self.accountRepository.fetchAllOperation(with: RepositoryFetchOptions())
        
        persistentOperation.completionBlock = { [weak self] in
            guard let accounts = try? persistentOperation.extractNoCancellableResultData() else { return }
            
            let selectedAccountAddress = SelectedWalletSettings.shared.currentAccount?.address ?? ""
            let selectedAccount = accounts.first { $0.address == selectedAccountAddress }
            
            var viewModel = ReceiveQRViewModel(name: selectedAccount?.username ?? "",
                                               address: selectedAccountAddress,
                                               qrImage: self?.currentImage)
            viewModel.shareHandler = { [weak self] in
                self?.share()
            }
            viewModel.accountTapHandler = {
                let title = NSAttributedString(string: R.string.localizable.commonCopied(preferredLanguages: .currentLocale))
                let viewModel = AppEventViewController.ViewModel(title: title)
                let appEventController = AppEventViewController(style: .custom(viewModel))
                self?.appEventService.showToasterIfNeeded(viewController: appEventController)
                UIPasteboard.general.string = selectedAccountAddress
            }
            self?.setupReceiveView?(viewModel)
        }

        OperationManagerFacade.runtimeBuildingQueue.addOperation(persistentOperation)
    }
    
    func createGenerateQRInfo() -> ReceiveInfo? {
        return ReceiveInfo(accountId: accountId,
                           assetId: WalletAssetId.xor.rawValue,
                           amount: nil,
                           details: "")
    }

    func share() {
        guard let qrImage = currentImage, let receiveInfo = createGenerateQRInfo() else { return }
        let sources = sharingFactory.createSources(for: receiveInfo, qrImage: qrImage)
        showShareContent?(sources)
    }
}
