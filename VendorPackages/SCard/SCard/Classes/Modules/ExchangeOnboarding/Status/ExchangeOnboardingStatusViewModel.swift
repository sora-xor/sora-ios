final class ExchangeOnboardingStatusViewModel {
    var onClose: (() -> Void)?
    var onSupport: (() -> Void)?
    var onExchange: (() -> Void)?

    internal var onUpdateUI: ((ExchangeOnboardingStatusView.Data) -> Void)?

    private let service: ExchangeService
    private let model: ExchangeOnboardingModel

    init(service: ExchangeService, model: ExchangeOnboardingModel) {
        self.service = service
        self.model = model

        checkExchangeStatus()
    }

    private func checkExchangeStatus() {
        Task {
            switch await service.onboarded() {
            case .success(let response):
                guard let response else {
                    onUpdateUI?(.error(message: "sdf"))
                    return
                }
                switch response.verificationStatus {
                case .pending:
                    onUpdateUI?(.pending)
                case .rejected:
                    let message = "\(response.verificationMessage)\n\(response.verificationDescription))"
                    onUpdateUI?(.error(message: message))
                case .accepted:
                    onExchange?()
                }

            case .failure(let error):
                onUpdateUI?(.error(message: error.localizedDescription))
            }
        }
    }
}
