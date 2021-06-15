import Foundation

struct VerificationState: Codable, Equatable, Withable {
    private(set) var resendDelay: TimeInterval = 0.0
    private(set) var lastAttempted: Date?

    var canResendVerificationCode: Bool {
        guard let lastAttempted = lastAttempted else {
            return true
        }

        return Date().timeIntervalSince(lastAttempted) >= resendDelay
    }

    var remainedDelay: TimeInterval {
        guard let lastAttempted = lastAttempted else {
            return 0.0
        }

        let remainedDelay = resendDelay - Date().timeIntervalSince(lastAttempted)

        return remainedDelay > 0.0 ? remainedDelay : 0.0
    }

    mutating func didPerformAttempt(with resendDelay: TimeInterval) {
        self.resendDelay = resendDelay
        self.lastAttempted = Date()
    }
}
