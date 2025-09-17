import SwiftUI

final class EmploymentStatusViewModel {
    var onContinue: ((ExchangeOnboarding.EmploymentStatus) -> Void)?

    var employmentStatus: ExchangeOnboarding.EmploymentStatus

    init(employmentStatus: ExchangeOnboarding.EmploymentStatus) {
        self.employmentStatus = employmentStatus
    }

    func next() {
        onContinue?(employmentStatus)
    }
}
