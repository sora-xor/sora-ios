import UIKit
import SoraUIKit
import CommonWallet
import RobinHood
import XNetworking

protocol ReceiveViewModelProtocol {
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)? { get set }
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)? { get set }
    func viewDidLoad()
}

final class ReceiveViewModel {
    
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    
    weak var view: ReceiveViewProtocol?
    private var qrService: WalletQRServiceProtocol
    private var sharingFactory: AccountShareFactoryProtocol
    private var accountId: String
    private var address: String
    private var selectedAsset: AssetInfo
    private let accountRepository: AnyDataProviderRepository<AccountItem>
    private var appEventService = AppEventService()

    private var currentImage: UIImage?
    private var amount: AmountDecimal?
    private var qrOperation: Operation?
    private var fiatData: [FiatData] = []
    private weak var fiatService: FiatServiceProtocol?
    private weak var assetProvider: AssetProviderProtocol?
    private weak var assetManager: AssetManagerProtocol?
    
    init(
        qrService: WalletQRServiceProtocol,
        sharingFactory: AccountShareFactoryProtocol,
        accountId: String,
        address: String,
        selectedAsset: AssetInfo,
        amount: AmountDecimal? = nil,
        fiatService: FiatServiceProtocol?,
        assetProvider: AssetProviderProtocol?,
        assetManager: AssetManagerProtocol?
    ) {
        self.qrService = qrService
        self.sharingFactory = sharingFactory
        self.accountId = accountId
        self.address = address
        self.selectedAsset = selectedAsset
        self.amount = amount
        self.fiatService = fiatService
        self.assetProvider = assetProvider
        self.assetManager = assetManager
        
        self.accountRepository = AnyDataProviderRepository(
            UserDataStorageFacade.shared
            .createRepository(filter: nil,
                              sortDescriptors: [],
                              mapper: AnyCoreDataMapper(AccountItemMapper()))
        )

    }
    
    deinit {
        cancelQRGeneration()
    }
}

extension ReceiveViewModel: ReceiveViewModelProtocol {
    func viewDidLoad() {
        fiatService?.getFiat(completion: { [weak self] fiatData in
            self?.fiatData = fiatData
            let size = UIScreen.main.bounds.width - 112
            self?.generateQR(with: CGSize(width: size, height: size) )
        })
    }
}

private extension ReceiveViewModel {
    func generateQR(with size: CGSize) {
        cancelQRGeneration()

        currentImage = nil

        do {
            guard let receiveInfo = createReceiveInfo() else {
                return
            }

            qrOperation = try qrService.generate(from: receiveInfo, qrSize: size,
                                                 runIn: .main) { [weak self] (operationResult) in
                                                    if let result = operationResult {
                                                        self?.qrOperation = nil
                                                        self?.processOperation(result: result)
                                                    }
            }
        } catch {
            processOperation(result: .failure(error))
        }
    }
    
    func processOperation(result: Result<UIImage, Swift.Error>) {
        let persistentOperation = self.accountRepository.fetchAllOperation(with: RepositoryFetchOptions())
        
        persistentOperation.completionBlock = { [weak self] in
            guard let accounts = try? persistentOperation.extractNoCancellableResultData(),
                  let receiveItem = self?.setupReceiveItem(with: accounts, generationResult: result) else { return }
            self?.setupItems?([ receiveItem ])
        }
        OperationManagerFacade.runtimeBuildingQueue.addOperation(persistentOperation)
    }
    
    func createReceiveInfo() -> ReceiveInfo? {
        return ReceiveInfo(accountId: accountId,
                           assetId: selectedAsset.identifier,
                           amount: amount,
                           details: "")
    }
    
    func cancelQRGeneration() {
        qrOperation?.cancel()
        qrOperation = nil
    }
    
    
    func share() {
        guard let qrImage = currentImage, let receiveInfo = createReceiveInfo() else { return }
        let sources = sharingFactory.createSources(for: receiveInfo, qrImage: qrImage)
        
        let activityController = UIActivityViewController(activityItems: sources, applicationActivities: nil)
        view?.controller.present(activityController, animated: true, completion: nil)
    }
}

private extension ReceiveViewModel {
    func setupReceiveItem(with accounts: [AccountItem], generationResult: Result<UIImage, Swift.Error>) -> ReceiveItem? {
        let selectedAccountAddress = SelectedWalletSettings.shared.currentAccount?.address ?? ""
        let selectedAccount = accounts.first { $0.address == selectedAccountAddress }
        
        switch generationResult {
        case .success(let image):
            
            currentImage = image
            
            let receiveItem = ReceiveItem(name: selectedAccount?.username ?? "",
                                          address: selectedAccountAddress,
                                          qrImage: image,
                                          sendAssetViewModel: setupSendAsset())
            receiveItem.shareHandler = { [weak self] in
                self?.share()
            }
            receiveItem.accountTapHandler = { [weak self] in
                let title = NSAttributedString(string: R.string.localizable.commonCopied(preferredLanguages: .currentLocale))
                let viewModel = AppEventViewController.ViewModel(title: title)
                let appEventController = AppEventViewController(style: .custom(viewModel))
                self?.appEventService.showToasterIfNeeded(viewController: appEventController)
                UIPasteboard.general.string = selectedAccountAddress
            }
            return receiveItem
        case .failure: break
        }
        
        return nil
    }
    
    func setupSendAsset() -> SendAssetViewModel? {
        guard let amount = amount, let balance = assetProvider?.getBalances(with: [selectedAsset.assetId]).first else { return nil }
       
        return SendAssetViewModel(symbol: selectedAsset.symbol,
                                  amount: amount.stringValue,
                                  balance: setupFullBalanceText(from: balance, fiatData: fiatData),
                                  fiat: setupFiatText(from: amount.decimalValue, assetId: selectedAsset.assetId, fiatData: fiatData),
                                  svgString: selectedAsset.icon)
    }
    
    func setupFullBalanceText(from balanceData: BalanceData, fiatData: [FiatData]) -> String {
        let balance = NumberFormatter.polkaswapBalance.stringFromDecimal(balanceData.balance.decimalValue) ?? ""
        var fiatBalanceText = ""
        
        if let usdPrice = fiatData.first(where: { $0.id == balanceData.identifier })?.priceUsd?.decimalValue {
            let fiatDecimal = balanceData.balance.decimalValue * usdPrice
            fiatBalanceText = "$" + (NumberFormatter.fiat.stringFromDecimal(fiatDecimal) ?? "")
        }

        return fiatBalanceText.isEmpty ? "\(balance)" : "\(balance) (\(fiatBalanceText))"
    }
    
    func setupFiatText(from amount: Decimal, assetId: String, fiatData: [FiatData]) -> String {
        guard let asset = assetManager?.assetInfo(for: assetId) else { return "" }
        
        var fiatText = ""
        
        if let usdPrice = fiatData.first(where: { $0.id == asset.assetId })?.priceUsd?.decimalValue {
            let fiatDecimal = amount * usdPrice
            fiatText = "$" + (NumberFormatter.fiat.stringFromDecimal(fiatDecimal) ?? "")
        }
        
        return fiatText
    }
}