import Foundation
import RobinHood
import SoraFoundation
import CommonWallet
import SoraUIKit
import AVFoundation
import Photos
import IrohaCrypto

protocol ImageGalleryPresentable: AnyObject {
    func presentImageGallery(from view: ControllerBackedProtocol?, delegate: ImageGalleryDelegate)
}

protocol ImageGalleryDelegate: AnyObject {
    func didCompleteImageSelection(from gallery: ImageGalleryPresentable, with selectedImages: [UIImage])
    func didFail(in gallery: ImageGalleryPresentable, with error: Error)
}

enum ImageGalleryError: Error {
    case accessDeniedPreviously
    case accessDeniedNow
    case accessRestricted
    case unknownAuthorizationStatus
}

protocol ScanQRViewModelProtocol {
    func prepareAppearance()
    func handleAppearance()
    func prepareDismiss()
    func handleDismiss()
    func activateImport()
    func showMyQrCode()
}

struct ScanQRResult {
    let firstName: String
    var receiverInfo: ReceiveInfo?
}

final class ScanQRViewModel: NSObject {
    enum ScanState {
        case initializing(accessRequested: Bool)
        case inactive
        case active
        case processing(receiverInfo: ReceiveInfo, operation: CancellableCall)
        case failed(code: String)
    }
    
    weak var view: ScanQRViewProtocol?

    private(set) var networkService: WalletServiceProtocol

    private let qrScanService: WalletQRCaptureServiceProtocol
    private let qrCoderFactory: WalletQRCoderFactoryProtocol
    private let qrScanMatcher: InvoiceScanMatcher
    private let localSearchEngine: InvoiceLocalSearchEngineProtocol?
    private(set) var scanState: ScanState = .initializing(accessRequested: false)
    private let completion: ((ScanQRResult) -> Void)?
    private let wireframe: ScanQRWireframeProtocol
    private let qrEncoder: WalletQREncoderProtocol
    private let sharingFactory: AccountShareFactoryProtocol
    private let assetManager: AssetManagerProtocol?
    private let assetsProvider: AssetProviderProtocol?

    var qrExtractionService: WalletQRExtractionServiceProtocol?

    init(networkService: WalletServiceProtocol,
         localSearchEngine: InvoiceLocalSearchEngineProtocol?,
         qrScanServiceFactory: WalletQRCaptureServiceFactoryProtocol,
         qrCoderFactory: WalletQRCoderFactoryProtocol,
         wireframe: ScanQRWireframe = ScanQRWireframe(),
         qrEncoder: WalletQREncoderProtocol,
         sharingFactory: AccountShareFactoryProtocol,
         assetManager: AssetManagerProtocol?,
         assetsProvider: AssetProviderProtocol?,
         completion: ((ScanQRResult) -> Void)?) {
        self.networkService = networkService
        self.localSearchEngine = localSearchEngine
        self.qrExtractionService = WalletQRExtractionService(processingQueue: .global())
        self.completion = completion
        self.qrCoderFactory = qrCoderFactory
        self.wireframe = wireframe
        self.qrEncoder = qrEncoder
        self.sharingFactory = sharingFactory
        self.assetManager = assetManager
        self.assetsProvider = assetsProvider

        let qrDecoder = qrCoderFactory.createDecoder()
        self.qrScanMatcher = InvoiceScanMatcher(decoder: qrDecoder)

        self.qrScanService = qrScanServiceFactory.createService(with: qrScanMatcher,
                                                                delegate: nil,
                                                                delegateQueue: nil)

        super.init()
        self.qrScanService.delegate = self
    }
    
    private func handleQRService(error: Error) {
        if let captureError = error as? WalletQRCaptureServiceError {
            handleQRCaptureService(error: captureError)
            return
        }

        if let extractionError = error as? WalletQRExtractionServiceError {
            handleQRExtractionService(error: extractionError)
            return
        }

        if let imageGalleryError = error as? ImageGalleryError {
            handleImageGallery(error: imageGalleryError)
        }
    }

    private func handleQRCaptureService(error: WalletQRCaptureServiceError) {
        guard case .initializing(let alreadyAskedAccess) = scanState, !alreadyAskedAccess else {
            return
        }

        scanState = .initializing(accessRequested: true)

        switch error {
        case .deviceAccessRestricted: break
        case .deviceAccessDeniedPreviously:
            let message = L10n.InvoiceScan.Error.cameraRestrictedPreviously
            let title = L10n.InvoiceScan.Error.cameraTitle
            view?.askOpenApplicationSettings(with: message, title: title, from: view, locale: Locale.current)
        default:
            break
        }
    }

    private func handleQRExtractionService(error: WalletQRExtractionServiceError) {
        switch error {
        case .noFeatures: break
        case .detectorUnavailable, .invalidImage: break
        }
    }

    private func handleImageGallery(error: ImageGalleryError) {
        switch error {
        case .accessRestricted: break
        case .accessDeniedPreviously:
            let message = L10n.InvoiceScan.Error.galleryRestrictedPreviously
            let title = L10n.InvoiceScan.Error.galleryTitle
            view?.askOpenApplicationSettings(with: message, title: title, from: view, locale: Locale.current)
        default:
            break
        }
    }

    private func handleReceived(captureSession: AVCaptureSession) {
        if case .initializing = scanState {
            scanState = .active

            view?.didReceive(session: captureSession)
        }
    }

    private func handleMatched(receiverInfo: ReceiveInfo) {
        if receiverInfo.accountId == SelectedWalletSettings.shared.currentAccount?.identifier {
            let message = L10n.InvoiceScan.Error.match
            view?.presentAlert(title: message)
            return
        }

        switch scanState {
        case .processing(let oldReceiverInfo, let oldOperation) where oldReceiverInfo != receiverInfo:
            oldOperation.cancel()

            performProcessing(of: receiverInfo)
        case .active:
            performProcessing(of: receiverInfo)
        default:
            break
        }
    }

    private func handleFailedMatching(for code: String) {
        let message = L10n.InvoiceScan.Error.extractFail
        view?.presentAlert(title: message)
    }

    private func performProcessing(of receiverInfo: ReceiveInfo) {
        if let searchData = localSearchEngine?.searchByAccountId(receiverInfo.accountId) {
            guard searchData.firstName != SelectedWalletSettings.shared.currentAccount?.identifier else {
                let message = L10n.InvoiceScan.Error.match
                view?.presentAlert(title: message)
                return
            }
            scanState = .active

            completeTransferFoundAccount(searchData, receiverInfo: receiverInfo)
        } else {
            let operation = networkService.search(for: receiverInfo.accountId,
                                                  runCompletionIn: .main) { [weak self] (optionalResult) in
                                                    if let result = optionalResult {
                                                        switch result {
                                                        case .success(let searchResult):
                                                            let loadedResult = searchResult ?? []
                                                            self?.handleProccessing(searchResult: loadedResult)
                                                        case .failure(let error):
                                                            self?.handleProcessing(error: error)
                                                        }
                                                    }
            }

            scanState = .processing(receiverInfo: receiverInfo, operation: operation)
        }
    }

    private func handleProccessing(searchResult: [SearchData]) {
        guard case .processing(let receiverInfo, _) = scanState else {
            return
        }

        scanState = .active

        guard let foundAccount = searchResult.first else {
            let message = L10n.InvoiceScan.Error.userNotFound
            view?.presentAlert(title: message)
            return
        }
        
        guard foundAccount.firstName != SelectedWalletSettings.shared.currentAccount?.identifier else {
            let message = L10n.InvoiceScan.Error.match
            view?.presentAlert(title: message)
            return
        }

        completeTransferFoundAccount(foundAccount, receiverInfo: receiverInfo)
    }

    private func completeTransferFoundAccount(_ foundAccount: SearchData, receiverInfo: ReceiveInfo) {
        view?.controller.dismiss(animated: true, completion: { [weak self] in
            self?.completion?(ScanQRResult(firstName: foundAccount.firstName, receiverInfo: receiverInfo))
        })
    }

    private func handleProcessing(error: Error) {
        guard case .processing = scanState else {
            return
        }

        scanState = .active

        if let contentConvertible = error as? WalletErrorContentConvertible {
            view?.presentAlert(title: contentConvertible.toErrorContent(for: .current).title)
        } else {
            let message = L10n.InvoiceScan.Error.noInternet
            view?.presentAlert(title: message)
        }

    }
    
    func presentImageGallery(from view: ControllerBackedProtocol?) {
        let photoAuthorizationStatus = PHPhotoLibrary.authorizationStatus()
        switch photoAuthorizationStatus {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization({ [weak self] (newStatus) in
                DispatchQueue.main.async {
                    if newStatus ==  PHAuthorizationStatus.authorized {
                        self?.presentGallery(from: view)
                    } else {
                        self?.didFail(with: ImageGalleryError.accessDeniedNow)
                    }
                }
            })
        case .restricted:
            didFail(with: ImageGalleryError.accessRestricted)
        case .denied:
            didFail(with: ImageGalleryError.accessDeniedPreviously)
        default:
            presentGallery(from: view)
        }
    }
    
    private func presentGallery(from view: ControllerBackedProtocol?) {
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = .photoLibrary
        imagePicker.delegate = self

        view?.controller.present(imagePicker,
                                 animated: true,
                                 completion: nil)
    }
    
    private func didCompleteImageSelection(with selectedImages: [UIImage]) {
        if let image = selectedImages.first {
            let qrDecoder = qrCoderFactory.createDecoder()
            let matcher = InvoiceScanMatcher(decoder: qrDecoder)

            qrExtractionService?.extract(from: image,
                                         using: matcher,
                                         dispatchCompletionIn: .main) { [weak self] result in
                switch result {
                case .success:
                    if let recieverInfo = matcher.receiverInfo {
                        self?.handleMatched(receiverInfo: recieverInfo)
                    }
                case .failure(let error):
                    self?.handleQRService(error: error)
                }
            }
        }
    }

    private func didFail(with error: Error) {
        handleQRService(error: error)
    }
}

extension ScanQRViewModel: WalletQRCaptureServiceDelegate {
    func qrCapture(service: WalletQRCaptureServiceProtocol, didSetup captureSession: AVCaptureSession) {
        DispatchQueue.main.async {
            self.handleReceived(captureSession: captureSession)
        }
    }

    func qrCapture(service: WalletQRCaptureServiceProtocol, didMatch code: String) {
        guard let receiverInfo = qrScanMatcher.receiverInfo else {
            return
        }

        DispatchQueue.main.async {
            self.handleMatched(receiverInfo: receiverInfo)
        }
    }

    func qrCapture(service: WalletQRCaptureServiceProtocol, didFailMatching code: String) {
        DispatchQueue.main.async {
            self.handleFailedMatching(for: code)
        }
    }

    func qrCapture(service: WalletQRCaptureServiceProtocol, didReceive error: Error) {
        DispatchQueue.main.async {
            self.handleQRService(error: error)
        }
    }
}

extension ScanQRViewModel: ScanQRViewModelProtocol {
    func prepareAppearance() {
        qrScanService.start()
    }

    func handleAppearance() {
        if case .inactive = scanState {
            scanState = .active
        }
    }

    func prepareDismiss() {
        if case .initializing = scanState {
            return
        }

        if case .processing(_, let operation) = scanState {
            operation.cancel()
        }

        scanState = .inactive
    }

    func handleDismiss() {
        qrScanService.stop()
    }

    func activateImport() {
        if qrExtractionService != nil {
            presentImageGallery(from: view)
        }
    }
    
    func showMyQrCode() {
        guard let currentAccount = SelectedWalletSettings.shared.currentAccount else { return }
        let accountId = try? SS58AddressFactory().accountId(fromAddress: currentAccount.identifier,
                                                            type: currentAccount.addressType).toHex(includePrefix: true)
        wireframe.showGenerateQR(
            on: view?.controller,
            accountId: accountId ?? "",
            address: currentAccount.address,
            qrEncoder: qrEncoder,
            sharingFactory: sharingFactory,
            assetManager: assetManager,
            assetsProvider: assetsProvider
        ) { [weak self] in
            self?.qrScanService.start()
        }
    }
}

extension ScanQRViewModel: UIImagePickerControllerDelegate & UINavigationControllerDelegate {
    @objc func imagePickerController(_ picker: UIImagePickerController,
                                     didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {

        if let originalImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            didCompleteImageSelection(with: [originalImage])
        } else {
            didCompleteImageSelection(with: [])
        }

        picker.presentingViewController?.dismiss(animated: true, completion: nil)
    }

    @objc func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        didCompleteImageSelection(with: [])
        picker.presentingViewController?.dismiss(animated: true, completion: nil)
    }
}
