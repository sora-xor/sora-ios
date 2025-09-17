import Foundation
import PayWingsOAuthSDK

final class KYCStatusViewModel {
    @MainActor var onStatus: ((KYCUserStatus, Int, String) -> Void)?
    @MainActor var onError: ((String) -> Void)?
    var onClose: (() -> Void)?
    var onRetry: (() -> Void)?
    var onLogout: (() -> Void)?
    var onSupport: (() -> Void)?

    private let service: KYCService
    private var freeAttemptsLeft: Int?

    init(data: KYCUserDataModel, service: KYCService) {
        self.data = data
        self.service = service
    }

    let data: KYCUserDataModel

    func getKYCStatus() async {
        guard service.isUserSignIn() else {
            await onError?("PayWings Login required!")
            return
        }

        await getKYCAttempts()
        _ = await service.userStatus()
        await service.updateFees()

        for await status in service.userStatusStream {

            if freeAttemptsLeft == nil {
                await getKYCAttempts()
            }
            guard let freeAttemptsLeft = self.freeAttemptsLeft else { return }
            await onStatus?(status, freeAttemptsLeft, service.retryFeeCache)
        }
    }

    private func getKYCAttempts() async {
        switch await service.kycAttempts() {
        case .failure(let error):
            await onError?(error.errorDescription ?? "error")
        case .success(let kycAttempts):
            self.freeAttemptsLeft = Int(kycAttempts.freeAttemptsLeft)
        }
    }
}
