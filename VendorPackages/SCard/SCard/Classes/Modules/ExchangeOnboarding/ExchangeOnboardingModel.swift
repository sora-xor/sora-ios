final class ExchangeOnboardingModel {
    var volume: ExchangeOnboarding.ExpectedVolume
    var reasons: [ExchangeOnboarding.OpeningReason : Bool]
    var sources: [ExchangeOnboarding.SourceOfFunds : Bool]

    init() {
        self.volume = .k10
        self.reasons = ExchangeOnboarding.OpeningReason.allCases
            .reduce(into: [ExchangeOnboarding.OpeningReason : Bool]()) {
                $0[$1] = false
            }
        self.sources = ExchangeOnboarding.SourceOfFunds.allCases
            .reduce(into: [ExchangeOnboarding.SourceOfFunds : Bool]()) {
                $0[$1] = false
            }
    }
}
