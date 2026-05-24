import Foundation
import SoraUIKit
import AVFoundation
import PayWingsOAuthSDK
import PayWingsKycSDK

final class KYCOnboardingViewModel {
    var onContinue: ((KYCUserDataModel) -> Void)?
    weak var viewController: UIViewController?
    
    private var result = VerificationResult()
    private var kycSuccess: PayWingsKycSDK.SuccessEvent?
    private let data: KYCUserDataModel
    private let service: KYCService
    private let storage: SCStorage

    init(data: KYCUserDataModel, service: KYCService, storage: SCStorage) {
        self.data = data
        self.service = service
        self.storage = storage
        self.result.delegate = self
    }

    func set(kycId: String) {
        data.kycId = kycId
        storage.add(kycId: kycId)
    }

    func startKYC() {
        Task {
            guard await checkCameraPermission() else {
                await showPhoneSettings(type: PermissionType.Camera.rawValue)
                return
            }
            guard await checkMicrophonePermission() else { 
                await showPhoneSettings(type: PermissionType.Microphone.rawValue)
                return
            }
            guard let kycSettings = await initializeKycSettings() else { return }
            await initializeKyc()

            await MainActor.run {
                viewController?.startLoader(indicatorColor: SoramitsuUI.shared.theme.palette.color(.accentSecondary))
                PayWingsKyc.startKyc(settings: kycSettings)
            }
        }
    }

    private func fetchReferenceNumber() async -> Bool {
        if !service.currentUserState.userReferenceNumber.isEmpty,
           !service.currentUserState.referenceId.isEmpty,
           service.currentUserState.kycStatus != .rejected
        {
            data.referenceNumber = service.currentUserState.userReferenceNumber
            data.referenceId = service.currentUserState.referenceId
            return true
        }

        if data.phoneNumber.isEmpty || data.email.isEmpty {
            let userData = await service.getUserData()
            data.phoneNumber = userData.phoneNumber ?? ""
            data.email = userData.email ?? ""
        }

        guard !data.phoneNumber.isEmpty, !data.email.isEmpty else {
            showErrorAlert(title: "Error", message: "No phone number or email")
            return false
        }

        let result = await service.referenceNumber(
            phone: data.phoneNumber,
            email: data.email
        )

        switch result {
        case .success(let respons):
            data.referenceNumber = respons.referenceNumber
            data.referenceId = respons.referenceID
            return true
        case .failure(let error):
            print(error)
            showErrorAlert(title: "Error", message: error.errorDescription ?? error.localizedDescription)
            return false
        }
    }

    private func initializeKycSettings() async -> KycSettings? {
        guard await fetchReferenceNumber() else { return nil }
        let referenceNumber = data.referenceNumber
        let referenceId = data.referenceId
        let language = UserDefaults.standard.string(forKey: "selectedLocalization") ?? "en"

        return KycSettings(referenceID: referenceId, referenceNumber: referenceNumber, language: language)
    }

    private func initializeKyc() async {
        
        guard let viewController = viewController else {
            error(message: "KYC initialization went wrong!")
            return
        }

        let credentials = KycCredentials(
            username: service.config.kycUsername,
            password: service.config.kycPassword,
            endpointUrl: service.config.kycUrl + "/"
        )

        let isCameraAuthorized = (AVCaptureDevice.authorizationStatus(for: .video) == .authorized) ? true : false
        let isMicAuthorized = (AVCaptureDevice.authorizationStatus(for: .audio) == .authorized) ? true : false

        guard isCameraAuthorized else {
            await showPhoneSettings(type: PermissionType.Camera.rawValue)
            return
        }

        guard isMicAuthorized else {
            await showPhoneSettings(type: PermissionType.Microphone.rawValue)
            return
        }

        await MainActor.run {
            PayWingsKyc.initialize(
                vc: viewController,
                credentials: credentials,
                result: self.result
            )
        }

        PayWingsKyc.tokenRefreshHandler { (methodUrl, onComplete) in
            PayWingsOAuthClient.instance()?.getNewAuthorizationData(
                methodUrl: methodUrl, httpRequestMethod: .POST, completion: { authData in
                    onComplete(authData.accessTokenData?.accessToken, authData.dpop)
                    if authData.userSignInRequired ?? false {
                        print("PayWingsKyc userSignInRequired")
                    }
            })
        }
    }

    private func checkCameraPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                continuation.resume(returning: true)

            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { isGranted in
                    continuation.resume(returning: isGranted)
                }

            case .denied:
                continuation.resume(returning: false)

            case .restricted:
                continuation.resume(returning: false)

            default:
                continuation.resume(returning: false)
            }
        }
    }

    private func checkMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            switch AVAudioSession.sharedInstance().recordPermission {
            case .granted:
                continuation.resume(returning: true)

            case .undetermined:
                AVAudioSession.sharedInstance().requestRecordPermission { isGranted in
                    continuation.resume(returning: isGranted)
                }

            case .denied:
                continuation.resume(returning: false)

            default:
                continuation.resume(returning: false)
            }
        }
    }

    @MainActor
    private func showPhoneSettings(type: String) {
        let alertController = UIAlertController(
            title: "Permission Error",
            message: "Permission for \(type) access denied, please allow our app permission through Settings in your phone if you want to use our service.",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "Cancel", style: .default) { [weak self] _ in
            guard let self = self else { return }
            self.onContinue?(self.data)
        })
        alertController.addAction(UIAlertAction(title: "Settings", style: .cancel) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url, options: [:], completionHandler: { _ in })
            }
        })
        viewController?.present(alertController, animated: true)
    }

    private func showErrorAlert(title: String, message: String) {
        let alertController = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(
            title: R.string.soraCard.commonCancel(preferredLanguages: .currentLocale),
            style: .default)
        )
        DispatchQueue.main.async {
            self.viewController?.present(alertController, animated: true)
        }
    }

    private func error(message: String) {

        let alertController = UIAlertController(
            title: R.string.soraCard.commonErrorGeneralTitle(preferredLanguages: .currentLocale),
            message: message,
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(
            title: R.string.soraCard.commonClose(preferredLanguages: .currentLocale),
            style: .cancel, handler: { [weak self] action in
                guard let self = self else { return }
                self.onContinue?(self.data)
            })
        )
        DispatchQueue.main.async {
            self.viewController?.present(alertController, animated: true)
        }
    }
}

extension KYCOnboardingViewModel: VerificationResultDelegate {
    func onSuccess(result: PayWingsKycSDK.SuccessEvent) {
        kycSuccess = result
        set(kycId: result.KycID ?? "")
        self.viewController?.stopLoader()
        onContinue?(data)
    }

    func onError(result: PayWingsKycSDK.ErrorEvent) {
        self.viewController?.stopLoader()
        guard result.ErrorData.code != .ABORTED_BY_USER else {
            self.onContinue?(self.data)
            return
        }
        error(message: "\(result.ErrorData.message)\n\(result.ErrorData.code.description)")
    }
}

private enum PermissionType : String {
    case Camera
    case Microphone
}
