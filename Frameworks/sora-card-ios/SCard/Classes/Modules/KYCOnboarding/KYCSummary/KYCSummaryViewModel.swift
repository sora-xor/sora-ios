import Foundation

final class KYCSummaryViewModel {

    var onLogout: (() -> Void)?
    var onClose: (() -> Void)?
    var onContinue: (() -> Void)?
    var onAttempts: ((Int64, String) -> Void)?

    private let service: KYCService

    init(service: KYCService) {
        self.service = service
    }

    func getKYCAttempts() async {
        await service.updateFees()
        switch await service.kycAttempts() {
        case .success(let kycAttempts):
            onAttempts?(kycAttempts.totalFreeAttempts, service.retryFeeCache)
        case .failure(let error):
            print("SCKYCSummaryViewModel failure:\(error)")
        }
    }
}
