import Foundation
import SoraKeystore
import SoraFoundation

final class SecurityLayerInteractor {
    var presenter: SecurityLayerInteractorOutputProtocol!
    var settings: SettingsManagerProtocol
    var keystore: KeystoreProtocol

    private(set) var applicationHandler: ApplicationHandlerProtocol

    private var backgroundEnterDate: Date?

    let pincodeDelay: TimeInterval

    private var canEnterPincode: Bool {
        do {
            let hasPincode = try keystore.checkKey(for: KeystoreTag.pincode.rawValue)
            let isRegistered = settings.isRegistered

            return isRegistered && hasPincode
        } catch {
            return false
        }
    }

    init(applicationHandler: ApplicationHandlerProtocol,
         settings: SettingsManagerProtocol,
         keystore: KeystoreProtocol,
         pincodeDelay: TimeInterval) {
        self.applicationHandler = applicationHandler
        self.settings = settings
        self.keystore = keystore
        self.pincodeDelay = pincodeDelay
    }

    private func checkAuthorizationRequirement() {
        guard let backgroundEnterDate = backgroundEnterDate else {
            return
        }

        self.backgroundEnterDate = nil

        if canEnterPincode {
            let pincodeDelayReached = Date().timeIntervalSince(backgroundEnterDate) >= pincodeDelay

            if pincodeDelayReached {
                presenter.didDecideRequestAuthorization()
            }
        }
    }
}

extension SecurityLayerInteractor: SecurityLayerInteractorInputProtocol {
    func setup() {
        applicationHandler.delegate = self
    }
}

extension SecurityLayerInteractor: ApplicationHandlerDelegate {
    func didReceiveWillEnterForeground(notification: Notification) {
        checkAuthorizationRequirement()
    }

    func didReceiveDidBecomeActive(notification: Notification) {
        presenter.didDecideUnsecurePresentation()
        checkAuthorizationRequirement()
    }

    func didReceiveWillResignActive(notification: Notification) {
        presenter.didDecideSecurePresentation()

        backgroundEnterDate = Date()
    }
}
