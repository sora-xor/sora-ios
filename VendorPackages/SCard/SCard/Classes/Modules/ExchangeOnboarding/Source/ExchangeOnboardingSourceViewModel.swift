final class ExchangeOnboardingSourceViewModel {
    var onContinue: (() -> Void)?
    var onError: ((String) -> Void)?
    var onAlreadyOnboarded: (() -> Void)?
    var onOnboardingAlreadyStarted: (() -> Void)?

    private let service: ExchangeService
    private let model: ExchangeOnboardingModel

    var sources: [ExchangeOnboarding.SourceOfFunds : Bool] {
        model.sources
    }

    init(service: ExchangeService, model: ExchangeOnboardingModel) {
        self.service = service
        self.model = model
    }

    func handleSource(_ source: ExchangeOnboarding.SourceOfFunds) {
        model.sources[source]?.toggle()
    }

    func processOnboarding() {

        Task {
            switch await service.onboardUser(data: model) {
            case .success(let response):

                //TODO: tmd fix, backend fix needed for users with no PW push
                //onError?(response?.statusDescription ?? "")
                if response?.statusCode == 0 {
                    onError?("")
                    onContinue?()
                } else if response?.statusCode == -4 {
                    onAlreadyOnboarded?()
                } else if response?.statusCode == -10 {
                    onOnboardingAlreadyStarted?()
                } else {
                    onError?(response?.statusDescription ?? R.string.soraCard.errorOccured(preferredLanguages: .currentLocale))
                }

            case .failure(let error):
                onError?(error.localizedDescription)
            }
        }
    }
}
