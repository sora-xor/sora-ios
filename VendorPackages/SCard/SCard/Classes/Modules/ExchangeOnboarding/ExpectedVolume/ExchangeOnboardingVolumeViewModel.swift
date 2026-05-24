import SwiftUI

final class ExchangeOnboardingVolumeViewModel {
    var onContinue: ((ExchangeOnboarding.ExpectedVolume) -> Void)?

    var volume: ExchangeOnboarding.ExpectedVolume

    private let service: ExchangeService

    init(service: ExchangeService, volume: ExchangeOnboarding.ExpectedVolume) {
        self.service = service
        self.volume = volume
    }

    func next() {
        onContinue?(volume)
    }
}
