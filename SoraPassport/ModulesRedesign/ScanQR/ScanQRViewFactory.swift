import SoraFoundation
import CommonWallet

final class ScanQRViewFactory {
    static func createView(assetManager: AssetManagerProtocol,
                           currentUser: AccountItem,
                           networkFacade: WalletNetworkOperationFactoryProtocol,
                           qrEncoder: WalletQREncoderProtocol,
                           sharingFactory: AccountShareFactoryProtocol,
                           assetsProvider: AssetProviderProtocol?,
                           isGeneratedQRCodeScreenShown: Bool = false,
                           providerFactory: BalanceProviderFactory,
                           feeProvider: FeeProviderProtocol,
                           completion: ((ScanQRResult) -> Void)?) -> ScanQRViewProtocol {
        let qrScanServiceFactory = WalletQRCaptureServiceFactory()
        let assets = assetManager.getAssetList()?.map { asset in
            return WalletAsset(identifier: asset.assetId,
                               name: LocalizableResource<String> { _ in asset.symbol },
                               platform: LocalizableResource<String> { _ in asset.name },
                               symbol: asset.symbol,
                               precision: Int16(asset.precision),
                               modes: .all)
        } ?? []
        let localSearchEngine = InvoiceScanLocalSearchEngine(networkType: currentUser.networkType)
        
        let qrCoderFactory = WalletQRCoderFactory(networkType: currentUser.networkType,
                                                  publicKey: currentUser.publicKeyData,
                                                  username: currentUser.username,
                                                  assets: assets)
        
        let viewModel = ScanQRViewModel(networkService: WalletService(operationFactory: networkFacade),
                                        localSearchEngine: localSearchEngine,
                                        qrScanServiceFactory: qrScanServiceFactory,
                                        qrCoderFactory: qrCoderFactory,
                                        qrEncoder: qrEncoder,
                                        sharingFactory: sharingFactory,
                                        assetManager: assetManager,
                                        assetsProvider: assetsProvider,
                                        networkFacade: networkFacade,
                                        isGeneratedQRCodeScreenShown: isGeneratedQRCodeScreenShown,
                                        providerFactory: providerFactory,
                                        feeProvider: feeProvider,
                                        completion: completion)
        
        let scanView = ScanQRViewController(viewModel: viewModel)
        viewModel.view = scanView
        
        return scanView

    }
}
