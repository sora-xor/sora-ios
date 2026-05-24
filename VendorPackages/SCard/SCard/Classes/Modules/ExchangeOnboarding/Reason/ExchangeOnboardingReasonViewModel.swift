final class ExchangeOnboardingReasonViewModel {
    var onContinue: (() -> Void)?

    var reasons: [ExchangeOnboarding.OpeningReason : Bool] {
        model.reasons
    }

    private let model: ExchangeOnboardingModel

    private let service: ExchangeService

    init(service: ExchangeService, model: ExchangeOnboardingModel) {
        self.service = service
        self.model = model
    }

    func handleReason(_ reason: ExchangeOnboarding.OpeningReason) {
        model.reasons[reason]?.toggle()
    }

    func next() {
        onContinue?()
    }
}
