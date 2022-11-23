import Foundation
import SoraKeystore

enum FailureAuthCount: Int {
    case zero = 0
    case first
    case second
    case third
    case fourth
    case fifth
    case sixth
    case seventh
    case eighth
    case ninth
    case unknown

    init(value: Int) {
        if let count = FailureAuthCount(rawValue: value) {
            self = count
        } else {
            self = .unknown
        }
    }

    var cooldownMinutes: Int {
        switch self {
        case .third: return 1
        case .fourth: return 5
        case .fifth: return 15
        case .sixth, .seventh, .eighth, .ninth, .unknown: return 30
        case .zero, .first, .second: return 0
        }
    }

    var isLastTry: Bool {
        return self == .second
    }

    var isBlockedTry: Bool {
        return self.rawValue >= FailureAuthCount.third.rawValue
    }
}

class LocalAuthInteractor {

    enum LocalAuthState {
        case waitingPincode
        case checkingPincode
        case checkingBiometry
        case completed
        case unexpectedFail
    }

    weak var presenter: LocalAuthInteractorOutputProtocol?
    private(set) var secretManager: SecretStoreManagerProtocol
    private(set) var settingsManager: SettingsManagerProtocol
    private(set) var biometryAuth: BiometryAuthProtocol
    private(set) var locale: Locale
    private var failCounter: Int = 0 {
        didSet {
            settingsManager.failInputPinCount = failCounter

            let failCount = FailureAuthCount(rawValue: failCounter) ?? .unknown

            guard !failCount.isLastTry else {
                presenter?.reachedLastChancePinInput()
                return
            }

            guard failCount.isBlockedTry else {
                return
            }
            
            let blockTimeInterval = TimeInterval(60 * failCount.cooldownMinutes)
            let date = Date().addingTimeInterval(blockTimeInterval)
            
            settingsManager.inputBlockTimeInterval = Int(date.timeIntervalSince1970)
            presenter?.blockUserInputUntil(date: date)
        }
    }

    init(secretManager: SecretStoreManagerProtocol,
         settingsManager: SettingsManagerProtocol,
         biometryAuth: BiometryAuthProtocol,
         locale: Locale) {
        self.secretManager = secretManager
        self.settingsManager = settingsManager
        self.biometryAuth = biometryAuth
        self.locale = locale
        self.failCounter = settingsManager.failInputPinCount ?? 0
    }

    private(set) var state = LocalAuthState.waitingPincode {
        didSet(oldValue) {
            if oldValue != state {
                presenter?.didChangeState(from: oldValue)
            }
        }
    }

    private(set) var pincode: String?

    private func performBiometryAuth() {
        guard state == .checkingBiometry else { return }

        let biometryUsageOptional = settingsManager.biometryEnabled

        guard let biometryUsage = biometryUsageOptional, biometryUsage else {
            state = .waitingPincode
            return
        }

        guard biometryAuth.availableBiometryType != .none else {
            state = .waitingPincode
            return
        }

        biometryAuth.authenticate(
            localizedReason: R.string.localizable.askBiometryReason(preferredLanguages: locale.rLanguages),
            completionQueue: DispatchQueue.main) { [weak self] (result: Bool) -> Void in

            self?.processBiometryAuth(result: result)
        }
    }

    private func processBiometryAuth(result: Bool) {
        guard state == .checkingBiometry else {
            return
        }

        if result {
           state = .completed
            presenter?.didCompleteAuth()
            failCounter = 0
            return
        }

        state = .waitingPincode
    }

    private func processStored(pin: String?) {
        guard state == .checkingPincode else {
            return
        }

        if pincode == pin {
            state = .completed
            pincode = nil
            presenter?.didCompleteAuth()
            failCounter = 0
        } else {
            state = .waitingPincode
            pincode = nil
            presenter?.didEnterWrongPincode()
            failCounter += 1
        }
    }
}

extension LocalAuthInteractor: LocalAuthInteractorInputProtocol {
    func getInputBlockDate() -> Date? {
        guard let timeInterval = settingsManager.inputBlockTimeInterval else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(timeInterval))
    }

    var allowManualBiometryAuth: Bool {
        return settingsManager.biometryEnabled == true
    }
    
    func getPinCodeCount() {
        secretManager.loadSecret(for: KeystoreTag.pincode.rawValue,
                                 completionQueue: DispatchQueue.main
        ) { [weak self] (secret: SecretDataRepresentable?) -> Void in
            self?.presenter?.setupPinCodeSymbols(with: secret?.toUTF8String()?.count ?? 6) 
        }
    }

    func startAuth() {
        guard state == .waitingPincode else { return }

        state = .checkingBiometry
        performBiometryAuth()
    }

    func process(pin: String) {
        guard state == .waitingPincode || state == .checkingBiometry else { return }

        self.pincode = pin

        state = .checkingPincode

        secretManager.loadSecret(for: KeystoreTag.pincode.rawValue,
                                 completionQueue: DispatchQueue.main
        ) { [weak self] (secret: SecretDataRepresentable?) -> Void in
            self?.processStored(pin: secret?.toUTF8String())
        }
    }
}
