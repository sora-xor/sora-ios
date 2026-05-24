enum ExchangeOnboarding {

    struct Data {
        let volume: ExchangeOnboarding.ExpectedVolume
        let reasons: [ExchangeOnboarding.OpeningReason]
        let sources: [ExchangeOnboarding.SourceOfFunds]
    }

    enum ExpectedVolume: Int, Codable, CaseIterable {
        case k10 = 1
        case k25 = 2
        case k50 = 3
        case k100 = 4
        case more = 5
    }

    enum OpeningReason: Int, Codable, CaseIterable {
        case trading = 1
        case sending = 2
        case purchasing = 3
        case holding = 4
        case mining = 5
    }

    enum SourceOfFunds: Int, Codable, CaseIterable {
        case salary = 1
        case savings = 2
        case trading = 3
        case other = 4
    }
}
