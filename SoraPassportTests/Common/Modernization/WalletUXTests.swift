// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import UIKit
import XCTest
import SoraUIKit
import SoraKeystore
import SoraFoundation
import CoreData
import Darwin
@testable import SoraPassport

final class WalletUXTests: XCTestCase {

    @MainActor
    func testAuthenticatedWalletOpeningRetriesLateServicesAndLeavesPIN() async throws {
        let previousWindow = UIApplication.shared.keyWindow
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        defer { window.isHidden = true; window.rootViewController = nil; previousWindow?.makeKeyAndVisible() }
        let wallet = UIViewController()
        var attempts = 0
        var refreshes = 0
        var opened = 0
        let opening = WalletOpeningViewController(makeWallet: {
            attempts += 1
            if attempts < 3 { throw WalletOpeningError.assetsNotReady }
            return wallet
        }, refresh: { refreshes += 1 }, makeNodes: { nil }, recheckWallet: { XCTFail("No storage recovery required") }, opened: {
            opened += 1
            window.rootViewController = $0
        }, retryInterval: 0.01, maximumAttempts: 5)
        window.rootViewController = UINavigationController(rootViewController: opening)
        window.makeKeyAndVisible()
        try await waitForWalletOpening { window.rootViewController === wallet }
        XCTAssertTrue(window.rootViewController === wallet)
        XCTAssertEqual(attempts, 3)
        XCTAssertEqual(refreshes, 1)
        XCTAssertEqual(opened, 1)
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(opened, 1, "Successful opening cancels pending retries")
    }

    @MainActor
    func testWalletOpeningStopsWaitingAndOffersRetryAndNodes() async throws {
        let previousWindow = UIApplication.shared.keyWindow
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        defer { window.isHidden = true; window.rootViewController = nil; previousWindow?.makeKeyAndVisible() }
        var attempts = 0
        var ready = false
        var nodeRequests = 0
        let wallet = UIViewController()
        let nodes = UIViewController()
        let opening = WalletOpeningViewController(makeWallet: {
            attempts += 1
            if !ready { throw WalletOpeningError.connectionNotReady }
            return wallet
        }, refresh: {}, makeNodes: {
            nodeRequests += 1
            return nodeRequests == 1 ? nil : nodes
        }, recheckWallet: { XCTFail("A node failure is not a storage failure") }, opened: {
            window.rootViewController = $0
        }, retryInterval: 0.01, maximumAttempts: 2)
        let navigation = UINavigationController(rootViewController: opening)
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        try await waitForWalletOpening { attempts == 2 }
        XCTAssertEqual(attempts, 2)
        let buttons = descendants(opening.view).compactMap { $0 as? UIButton }
        let retry = try XCTUnwrap(buttons.first { $0.accessibilityIdentifier == "wallet-opening-retry" })
        let changeNode = try XCTUnwrap(buttons.first { $0.accessibilityIdentifier == "wallet-opening-nodes" })
        let status = try XCTUnwrap(descendants(opening.view).compactMap { $0 as? UILabel }
            .first { $0.accessibilityIdentifier == "wallet-opening-status" })
        XCTAssertTrue(retry.isEnabled && !retry.isHidden)
        XCTAssertTrue(changeNode.isEnabled && !changeNode.isHidden)
        XCTAssertTrue(descendants(opening.view).compactMap { $0 as? UIActivityIndicatorView }.allSatisfy { !$0.isAnimating })
        XCTAssertEqual(status.text, WalletUX.text("Wallet services are not ready. Try again or choose another node."))
        retry.sendActions(for: .touchUpInside)
        try await waitForWalletOpening { attempts == 4 }
        XCTAssertEqual(attempts, 4)
        changeNode.sendActions(for: .touchUpInside)
        XCTAssertEqual(status.text, WalletUX.text("Node settings are still loading. Try again."))
        XCTAssertTrue(retry.isEnabled)
        changeNode.sendActions(for: .touchUpInside)
        XCTAssertTrue(navigation.topViewController === nodes)
        try await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertEqual(attempts, 4, "Do not replace a node picker with a background retry")
        ready = true
        navigation.popViewController(animated: false)
        try await waitForWalletOpening { window.rootViewController === wallet }
        XCTAssertTrue(window.rootViewController === wallet)
        XCTAssertEqual(attempts, 5)
    }

    @MainActor
    func testWalletOpeningNeverBypassesRetainedRecoveryForANodeError() async throws {
        let settings = InMemorySettingsManager()
        settings.setWalletMigrationRecovery(reason: "Retained fixture")
        let marker = WalletMigrationRecoveryMarker.capture(settings)
        let keys = InMemoryKeychain()
        try keys.addKey(Data([1, 2, 3]), with: "retained-fixture-key")
        let identifiers = try keys.allKeyIdentifiers()
        var attempts = 0
        var rechecks = 0
        let controller = WalletOpeningViewController(makeWallet: {
            attempts += 1
            throw WalletOpeningError.recoveryRequired
        }, refresh: {}, makeNodes: { XCTFail("Recovery cannot expose node settings"); return nil },
           recheckWallet: { rechecks += 1 }, opened: { _ in XCTFail("Recovery cannot open the wallet") },
           retryInterval: 0.01, maximumAttempts: 2)
        controller.loadViewIfNeeded()
        controller.viewDidAppear(false)
        try await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertEqual(attempts, 1)
        let buttons = descendants(controller.view).compactMap { $0 as? UIButton }
        XCTAssertTrue(try XCTUnwrap(buttons.first { $0.accessibilityIdentifier == "wallet-opening-nodes" }).isHidden)
        XCTAssertTrue(try XCTUnwrap(buttons.first { $0.accessibilityIdentifier == "wallet-opening-retry" }).isHidden)
        let recheck = try XCTUnwrap(buttons.first { $0.accessibilityIdentifier == "wallet-opening-recheck" })
        XCTAssertFalse(recheck.isHidden)
        recheck.sendActions(for: .touchUpInside)
        XCTAssertEqual(rechecks, 1)
        XCTAssertEqual(WalletMigrationRecoveryMarker.capture(settings), marker)
        XCTAssertEqual(try keys.allKeyIdentifiers(), identifiers)
        XCTAssertEqual(try keys.fetchKey(for: "retained-fixture-key"), Data([1, 2, 3]))
    }

    @MainActor
    func testNodeFailureUsesStatusWithoutBlockingPINOrClaimingAccountCreation() {
        let view = WalletUXNetworkStatusSpy()
        let presenter = NetworkAvailabilityLayerPresenter()
        presenter.view = view
        presenter.didDecideUnreachableNodesAllertPresentation()
        XCTAssertEqual(view.alerts, 0)
        XCTAssertEqual(view.statuses, [WalletUX.text("Network unavailable. Retrying connection…")])
    }

    @MainActor
    private func waitForWalletOpening(_ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(3)
        while !condition(), Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    @MainActor
    func testResumeAuthorizationPreservesRecoveryAndGoogleCompletionAfterTimeout() async throws {
        let previousKeyWindow = UIApplication.shared.keyWindow
        for pin in ["1234", "123456"] {
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
            defer { window.isHidden = true; window.rootViewController = nil; previousKeyWindow?.makeKeyAndVisible() }
            let settings = InMemorySettingsManager()
            settings.biometryEnabled = false
            settings.setWalletMigrationRecovery(reason: "retained missing credentials")
            let marker = WalletMigrationRecoveryMarker.capture(settings)
            let store = InMemoryKeychainManager()
            try store.keychain.addKey(Data(pin.utf8), with: KeystoreTag.pincode.rawValue)
            let recovery = WalletRecoveryViewController(reason: "retained missing credentials", onRetry: {})
            let root = UINavigationController(rootViewController: recovery)
            window.rootViewController = root
            root.loadViewIfNeeded()
            recovery.loadViewIfNeeded()
            window.makeKeyAndVisible()
            window.layoutIfNeeded()
            root.view.layoutIfNeeded()
            // Establish an attached fixture before testing whether the lock preserves it.
            // Queued PIN callbacks alone do not complete UIKit appearance transactions.
            try await waitForWalletOpening { recovery.view.window === window }
            guard recovery.view.window === window else {
                XCTFail("Recovery fixture did not attach before the background transition")
                return
            }
            var pinPresenter: AuthorizationPresenter?
            let wireframe = SecurityLayerWireframe(windowProvider: { window }, pinFactory: { delegate in
                let view = PincodeViewController()
                view.mode = .securedInput
                let presenter = AuthorizationPresenter()
                let interactor = LocalAuthInteractor(secretManager: store, settingsManager: settings,
                    biometryAuth: WalletUXNoBiometry(), locale: .current)
                view.presenter = presenter; presenter.view = view; presenter.interactor = interactor
                presenter.wireframe = delegate; interactor.presenter = presenter
                pinPresenter = presenter
                return view
            })
            defer {
                wireframe.authorizationWindow?.isHidden = true
                wireframe.authorizationWindow?.rootViewController = nil
            }
            var date = Date(timeIntervalSince1970: 1_000)
            let lifecycle = SecurityLayerInteractor(applicationHandler: ApplicationHandler(), settings: settings,
                keystore: store.keychain, pincodeDelay: 300, currentDate: { date })
            let presenter = SecurityLayerPresenter()
            presenter.wireframe = wireframe; presenter.interactor = lifecycle; lifecycle.presenter = presenter
            lifecycle.didReceiveWillResignActive(notification: Notification(name: UIApplication.willResignActiveNotification))
            date.addTimeInterval(301)
            lifecycle.didReceiveWillEnterForeground(notification: Notification(name: UIApplication.willEnterForegroundNotification))
            lifecycle.didReceiveDidBecomeActive(notification: Notification(name: UIApplication.didBecomeActiveNotification))
            await drainPINCallbacks()
            let lockWindow = try XCTUnwrap(wireframe.authorizationWindow)
            XCTAssertTrue(window.rootViewController === root)
            XCTAssertTrue(recovery.view.window === window)
            XCTAssertFalse(window.isHidden)
            XCTAssertFalse(lockWindow.isHidden)
            XCTAssertGreaterThan(lockWindow.windowLevel.rawValue, window.windowLevel.rawValue)
            XCTAssertEqual(lockWindow.rootViewController?.view.backgroundColor, .systemBackground)
            XCTAssertEqual(lockWindow.rootViewController?.view.alpha, 1)
            XCTAssertTrue(lockWindow.rootViewController?.view.isUserInteractionEnabled == true)
            // A Google completion arrives while the lock is visible. Its result
            // stays attached to the original flow and remains covered by the PIN window.
            let backupPrompt = UIAlertController(title: "Backup password", message: "Synthetic callback", preferredStyle: .alert)
            backupPrompt.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            recovery.present(backupPrompt, animated: false)
            XCTAssertTrue(recovery.presentedViewController === backupPrompt)
            wireframe.showAuthorization()
            XCTAssertTrue(wireframe.authorizationWindow === lockWindow, "Repeated foreground notifications cannot replace pending auth")
            let input = try XCTUnwrap(pinPresenter)
            for digit in String(repeating: "0", count: pin.count) { input.padButtonTapped(with: String(digit)) }
            await drainPINCallbacks()
            try await Task.sleep(nanoseconds: 600_000_000)
            XCTAssertTrue(wireframe.authorizationWindow === lockWindow, "An incorrect PIN cannot uncover recovery")
            for digit in pin { input.padButtonTapped(with: String(digit)) }
            await drainPINCallbacks()
            XCTAssertNil(wireframe.authorizationWindow)
            XCTAssertTrue(window.rootViewController === root)
            XCTAssertTrue(recovery.presentedViewController === backupPrompt, "Successful PIN must resume the outstanding import result")
            XCTAssertEqual(WalletMigrationRecoveryMarker.capture(settings), marker)
            XCTAssertEqual(try store.keychain.allKeyIdentifiers(), [KeystoreTag.pincode.rawValue])
            XCTAssertEqual(try store.keychain.fetchKey(for: KeystoreTag.pincode.rawValue), Data(pin.utf8), "Resume authentication cannot rewrite even a legacy PIN")
            var didDismissPrompt = false
            backupPrompt.dismiss(animated: false) { didDismissPrompt = true }
            try await waitForWalletOpening { didDismissPrompt && recovery.presentedViewController == nil }
            XCTAssertTrue(didDismissPrompt)
            XCTAssertNil(recovery.presentedViewController)
            window.isHidden = true
            window.rootViewController = nil
            try await waitForWalletOpening { recovery.view.window == nil }
            XCTAssertNil(recovery.view.window)
        }
    }

    @MainActor
    func testPINPresentersSubmitStoredLengthOnceAndKeepSixDigitUpgrade() async throws {
        for length in [4, 6] {
            let input = InputPincodePresenter()
            let inputView = WalletUXPINViewSpy()
            let inputAuth = WalletUXLocalAuthSpy()
            let inputWireframe = WalletUXPINWireframeSpy()
            input.view = inputView; input.interactor = inputAuth; input.wireframe = inputWireframe
            input.start()
            XCTAssertEqual(inputAuth.countRequests, 1)
            input.padButtonTapped(with: "1")
            XCTAssertTrue(inputAuth.submitted.isEmpty, "Do not guess the length before Keychain responds")
            input.setupPinCodeSymbols(with: 0)
            XCTAssertTrue(inputView.titles.last?.contains("PIN unavailable") == true)
            input.padButtonTapped(with: "1")
            XCTAssertEqual(inputAuth.countRequests, 2)
            XCTAssertTrue(inputAuth.submitted.isEmpty)
            input.setupPinCodeSymbols(with: length)
            for _ in 0 ..< length - 1 { input.padButtonTapped(with: "1") }
            XCTAssertTrue(inputAuth.submitted.isEmpty)
            input.padButtonTapped(with: "1")
            input.padButtonTapped(with: "9")
            XCTAssertEqual(inputAuth.submitted, [String(repeating: "1", count: length)])
            input.didEnterWrongPincode()
            await drainPINCallbacks()
            for _ in 0 ..< length { input.padButtonTapped(with: "2") }
            XCTAssertEqual(inputAuth.submitted.count, 2)
            input.didCompleteAuth()
            await drainPINCallbacks()
            if length == 4 {
                XCTAssertEqual(inputView.updateRequests, 1)
                XCTAssertEqual(inputWireframe.mainCount, 0)
                input.updatePinButtonTapped()
                for _ in 0 ..< 6 { input.padButtonTapped(with: "3") }
                for _ in 0 ..< 6 { input.padButtonTapped(with: "3") }
                XCTAssertEqual(inputAuth.updated, ["333333"])
                XCTAssertEqual(inputWireframe.mainCount, 1)
            } else {
                XCTAssertEqual(inputView.updateRequests, 0)
                XCTAssertEqual(inputWireframe.mainCount, 1)
                XCTAssertTrue(inputAuth.updated.isEmpty)
            }

            let authorization = AuthorizationPresenter()
            let auth = WalletUXLocalAuthSpy()
            let view = WalletUXPINViewSpy()
            let completion = WalletUXAuthorizationSpy()
            authorization.interactor = auth; authorization.view = view; authorization.wireframe = completion
            authorization.start()
            XCTAssertEqual(auth.countRequests, 1)
            authorization.setupPinCodeSymbols(with: 5)
            XCTAssertTrue(view.titles.last?.contains("PIN unavailable") == true)
            authorization.padButtonTapped(with: "1")
            XCTAssertEqual(auth.countRequests, 2)
            XCTAssertTrue(auth.submitted.isEmpty)
            authorization.setupPinCodeSymbols(with: length)
            XCTAssertEqual(view.symbolCounts.last, length)
            for _ in 0 ..< length { authorization.padButtonTapped(with: "4") }
            authorization.padButtonTapped(with: "5")
            XCTAssertEqual(auth.submitted, [String(repeating: "4", count: length)])
            authorization.didCompleteAuth()
            await drainPINCallbacks()
            XCTAssertEqual(completion.results, [true])
            XCTAssertTrue(auth.updated.isEmpty)

            let cooldownInput = InputPincodePresenter()
            let cooldownView = WalletUXPINViewSpy()
            let cooldownAuth = WalletUXLocalAuthSpy()
            cooldownAuth.blockDate = Date().addingTimeInterval(30)
            cooldownInput.view = cooldownView; cooldownInput.interactor = cooldownAuth
            cooldownInput.wireframe = inputWireframe
            cooldownInput.start()
            XCTAssertEqual(cooldownAuth.countRequests, 1, "Load the retained length even when reopening during cooldown")
            XCTAssertEqual(cooldownView.blockedDates.count, 1)
            cooldownInput.setupPinCodeSymbols(with: length)
            cooldownAuth.blockDate = nil
            for _ in 0 ..< length { cooldownInput.padButtonTapped(with: "7") }
            XCTAssertEqual(cooldownAuth.submitted, [String(repeating: "7", count: length)],
                "After cooldown, the first typed digit must not be consumed by a length reload")
        }

        let actualView = PincodeViewController()
        let actualPresenter = InputPincodePresenter()
        let actualAuth = WalletUXLocalAuthSpy()
        actualView.mode = .securedInput; actualView.presenter = actualPresenter
        actualPresenter.view = actualView; actualPresenter.interactor = actualAuth
        actualPresenter.wireframe = WalletUXPINWireframeSpy()
        actualView.loadViewIfNeeded()
        actualPresenter.setupPinCodeSymbols(with: 0)
        actualView.view.frame = CGRect(x: 0, y: 0, width: 375, height: 667)
        actualView.view.layoutIfNeeded()
        let feedback = try XCTUnwrap(descendants(actualView.view).compactMap { $0 as? SoramitsuLabel }
            .first { ($0.text ?? "").hasPrefix("PIN unavailable") })
        XCTAssertEqual(feedback.numberOfLines, 0)
        XCTAssertEqual(feedback.sora.lineBreakMode, .byWordWrapping)
        XCTAssertTrue(feedback.text?.contains("tap a number to retry") == true)
        XCTAssertLessThanOrEqual(feedback.frame.width, actualView.view.bounds.width)
        XCTAssertGreaterThan(feedback.frame.height, feedback.font.lineHeight)
    }

    @MainActor
    func testResumeAuthorizationFailureKeepsOpaqueLockAndAllowsRetry() throws {
        let previousKeyWindow = UIApplication.shared.keyWindow
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        let original = UIViewController()
        window.rootViewController = original
        window.makeKeyAndVisible()
        let delegate = try XCTUnwrap(UIApplication.shared.delegate as? AppDelegate)
        let previousAppWindow = delegate.window
        delegate.window = window
        let loadingWindow = UIWindow(frame: window.frame)
        loadingWindow.windowLevel = .alert
        let spinnerRoot = UIViewController()
        loadingWindow.rootViewController = spinnerRoot
        loadingWindow.makeKeyAndVisible()
        var attempts = 0
        let wireframe = SecurityLayerWireframe(pinFactory: { _ in attempts += 1; return nil })
        defer {
            wireframe.authorizationWindow?.isHidden = true
            loadingWindow.isHidden = true; loadingWindow.rootViewController = nil
            window.isHidden = true; window.rootViewController = nil
            delegate.window = previousAppWindow
            previousKeyWindow?.makeKeyAndVisible()
        }
        wireframe.showAuthorization()
        let lock = try XCTUnwrap(wireframe.authorizationWindow)
        let retry = try XCTUnwrap(descendants(try XCTUnwrap(lock.rootViewController?.view)).compactMap { $0 as? UIButton }.first)
        XCTAssertEqual(attempts, 1)
        XCTAssertFalse(lock.isHidden)
        XCTAssertEqual(lock.rootViewController?.view.backgroundColor, .systemBackground)
        retry.sendActions(for: .touchUpInside)
        XCTAssertEqual(attempts, 2)
        wireframe.showAuthorizationCompletion(with: false)
        XCTAssertEqual(attempts, 3)
        XCTAssertTrue(wireframe.authorizationWindow === lock)
        XCTAssertFalse(lock.isHidden)
        XCTAssertTrue(window.rootViewController === original)
        XCTAssertTrue(loadingWindow.rootViewController === spinnerRoot)
        XCTAssertGreaterThan(lock.windowLevel.rawValue, loadingWindow.windowLevel.rawValue)
        XCTAssertEqual((lock.rootViewController?.presentedViewController as? UIAlertController)?.title, "PIN verification unavailable")
    }

    @MainActor
    private func drainPINCallbacks() async {
        for _ in 0 ..< 5 {
            await withCheckedContinuation { continuation in
                DispatchQueue.main.async { continuation.resume() }
            }
        }
    }


    func testStartupRetryReportsCurrentFailureWithoutReplacingRecoveryMarker() throws {
        let settings = InMemorySettingsManager()
        let reason = UserStorageMigrationError.privacySafeRecoveryDescription(for: KeystoreError.unexpectedFail)
        settings.setWalletMigrationRecovery(reason: reason)
        let original = WalletMigrationRecoveryMarker.capture(settings)
        let secret = "PRIVATE-wallet-address-path-and-phrase"
        let failures: [(Error, WalletStartupDiagnostic.Cause, Int?)] = [
            (UserStorageMigrationError.backupVerificationFailed(secret), .backupVerification, nil),
            (WalletNetworkMigrationError.legacyIdentityMismatch(secret), .legacyIdentityMismatch, nil),
            (WalletIntegrityError.selectedAccountSecretMissing(address: secret), .missingSecret, nil),
            (KeystoreSystemError(status: -25308), .keychainSystem, -25308),
            (NSError(domain: NSCocoaErrorDomain, code: 134100,
                userInfo: [NSLocalizedDescriptionKey: secret, NSFilePathErrorKey: secret]), .cocoa, 134100),
            (NSError(domain: secret, code: 7, userInfo: [NSLocalizedDescriptionKey: secret]), .unexpected, nil)
        ]
        for (error, cause, systemCode) in failures {
            var migrated = false
            XCTAssertEqual(WalletStorageStartup.run(settings: settings, accountCommitRecovery: {
                try WalletStartupDiagnostic.check(.databaseInventory) { throw error }
            }, migration: { migrated = true }), .recoveryRequired)
            XCTAssertFalse(migrated)
            XCTAssertEqual(WalletMigrationRecoveryMarker.capture(settings), original)
            let diagnostic = try XCTUnwrap(WalletStartupDiagnostic.current(settings))
            XCTAssertEqual(diagnostic.phase, .databaseInventory)
            XCTAssertEqual(diagnostic.cause, cause)
            XCTAssertEqual(diagnostic.systemCode, systemCode)
            XCTAssertFalse(diagnostic.summary.contains(secret))
            XCTAssertFalse(diagnostic.userMessage.isEmpty)
            XCTAssertFalse(diagnostic.userMessage.contains(secret))
            XCTAssertFalse(try String(decoding: JSONEncoder().encode(diagnostic), as: UTF8.self).contains(secret))
        }
        settings.setWalletMigrationRecovery(reason: "A newer integrity failure")
        XCTAssertNil(WalletStartupDiagnostic.current(settings), "A new marker must not display the previous attempt's diagnostic")

        let fresh = InMemorySettingsManager()
        XCTAssertEqual(WalletStorageStartup.run(settings: fresh, migration: {
            throw KeystoreSystemError(status: -34018)
        }), .recoveryRequired)
        XCTAssertEqual(WalletStartupDiagnostic.current(fresh)?.phase, .databaseMigration)
        XCTAssertEqual(WalletStartupDiagnostic.current(fresh)?.systemCode, -34018)
        XCTAssertEqual(fresh.walletMigrationRecoveryReason, reason)
    }

    @MainActor
    func testRecoveryDetailsIncludeLatestSafeDiagnosticAndRejectInvalidStoredCodes() throws {
        let previousClipboard = UIPasteboard.general.string
        defer { UIPasteboard.general.string = previousClipboard }
        let settings = InMemorySettingsManager()
        let reason = UserStorageMigrationError.privacySafeRecoveryDescription(for: KeystoreError.unexpectedFail)
        settings.setWalletMigrationRecovery(reason: reason)
        let marker = WalletMigrationRecoveryMarker.capture(settings)
        WalletStartupDiagnostic.record(KeystoreSystemError(status: -25308),
            phase: .networkBootstrap, settings: settings)
        let diagnostic = try XCTUnwrap(WalletStartupDiagnostic.current(settings))
        let controller = WalletRecoveryViewController(reason: reason, diagnostic: diagnostic)
        controller.loadViewIfNeeded()
        let copy = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? UIButton }
            .first { $0.accessibilityIdentifier == "wallet-recovery-copy-details" })
        copy.sendActions(for: .touchUpInside)
        let details = try XCTUnwrap(UIPasteboard.general.string)
        XCTAssertTrue(details.contains(reason))
        XCTAssertTrue(details.contains("Latest verification: network_bootstrap / keychain_system (-25308)"))
        XCTAssertTrue(details.contains("Recovery report format: 2"))
        XCTAssertTrue(details.contains("Protected data when copied: "))
        XCTAssertTrue(details.contains("iOS: "))
        XCTAssertTrue(details.contains("Current failure: \(diagnostic.userMessage)"))
        let latestRange = try XCTUnwrap(details.range(of: "Latest verification:"))
        let originalRange = try XCTUnwrap(details.range(of: "Original recovery trigger:"))
        XCTAssertLessThan(latestRange.lowerBound, originalRange.lowerBound)
        let visibleDiagnostic = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? UILabel }
            .first { $0.accessibilityIdentifier == "wallet-recovery-diagnostic" })
        XCTAssertEqual(visibleDiagnostic.text, diagnostic.summary)
        XCTAssertEqual(WalletMigrationRecoveryMarker.capture(settings), marker)

        let privateHistoricalText = "PRIVATE-ACCOUNT-ADDRESS-PHRASE-PATH"
        let historicalController = WalletRecoveryViewController(reason: privateHistoricalText, diagnostic: diagnostic)
        historicalController.loadViewIfNeeded()
        let historicalCopy = try XCTUnwrap(descendants(historicalController.view).compactMap { $0 as? UIButton }
            .first { $0.accessibilityIdentifier == "wallet-recovery-copy-details" })
        historicalCopy.sendActions(for: .touchUpInside)
        let historicalDetails = try XCTUnwrap(UIPasteboard.general.string)
        XCTAssertFalse(historicalDetails.contains(privateHistoricalText))
        XCTAssertTrue(historicalDetails.contains(diagnostic.summary))
        XCTAssertTrue(historicalDetails.contains("Original recovery trigger: legacy record"))

        let oldController = WalletRecoveryViewController(reason: reason, onRetry: {})
        oldController.loadViewIfNeeded()
        let oldDiagnostic = try XCTUnwrap(descendants(oldController.view).compactMap { $0 as? UILabel }
            .first { $0.accessibilityIdentifier == "wallet-recovery-diagnostic" })
        XCTAssertTrue(try XCTUnwrap(oldDiagnostic.text).contains("Try again"))

        var stored = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(diagnostic)) as? [String: Any])
        stored["cause"] = "PRIVATE-ACCOUNT"
        let malformed = try JSONSerialization.data(withJSONObject: stored)
        settings.set(value: String(decoding: malformed, as: UTF8.self), for: "walletStartupDiagnostic")
        XCTAssertNil(WalletStartupDiagnostic.current(settings))
        XCTAssertEqual(WalletMigrationRecoveryMarker.capture(settings), marker)
    }

    @MainActor
    func testWalletRecoveryRetryRunsOnceWithoutClearingRecoveryState() throws {
        let settings = InMemorySettingsManager()
        let reason = UserStorageMigrationError.privacySafeRecoveryDescription(for: KeystoreError.invalidIdentifierFormat)
        settings.setWalletMigrationRecovery(reason: reason)
        let marker = WalletMigrationRecoveryMarker.capture(settings)
        var retries = 0
        let controller = WalletRecoveryViewController(reason: reason, onRetry: {
            XCTAssertEqual(WalletMigrationRecoveryMarker.capture(settings), marker)
            retries += 1
        })
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 375, height: 667)
        controller.view.layoutIfNeeded()
        let retry = try XCTUnwrap(descendants(controller.view).compactMap { $0 as? UIButton }
            .first { $0.accessibilityIdentifier == "wallet-recovery-retry" })
        XCTAssertEqual(retry.title(for: .normal), WalletUX.text("Try again"))
        XCTAssertTrue(retry.isEnabled)
        XCTAssertFalse(retry.isHidden)
        XCTAssertFalse(retry.frame.isEmpty)
        retry.sendActions(for: .touchUpInside)
        retry.sendActions(for: .touchUpInside)
        XCTAssertEqual(retries, 1)
        XCTAssertFalse(retry.isEnabled)
        XCTAssertEqual(WalletMigrationRecoveryMarker.capture(settings), marker)
        let passiveController = WalletRecoveryViewController(reason: reason)
        passiveController.loadViewIfNeeded()
        XCTAssertTrue(try XCTUnwrap(descendants(passiveController.view).compactMap { $0 as? UIButton }
            .first { $0.accessibilityIdentifier == "wallet-recovery-retry" }).isHidden)
        XCTAssertTrue(try XCTUnwrap(descendants(controller.view).compactMap { $0 as? UIButton }
            .first { $0.accessibilityIdentifier == "wallet-recovery-restore-keys" }).isHidden)
        XCTAssertTrue(try XCTUnwrap(descendants(controller.view).compactMap { $0 as? UIButton }
            .first { $0.accessibilityIdentifier == "wallet-recovery-restore-cloud-backup" }).isHidden)

        WalletStartupDiagnostic.record(UserStorageMigrationError.missingWalletSecret("fixture"),
            phase: .databaseMigration, settings: settings)
        let missingKeysController = WalletRecoveryViewController(reason: reason,
            diagnostic: WalletStartupDiagnostic.current(settings), onRetry: {})
        missingKeysController.loadViewIfNeeded()
        let restore = try XCTUnwrap(descendants(missingKeysController.view).compactMap { $0 as? UIButton }
            .first { $0.accessibilityIdentifier == "wallet-recovery-restore-keys" })
        XCTAssertFalse(restore.isHidden)
        XCTAssertTrue(restore.isEnabled)
        let restoreCloud = try XCTUnwrap(descendants(missingKeysController.view).compactMap { $0 as? UIButton }
            .first { $0.accessibilityIdentifier == "wallet-recovery-restore-cloud-backup" })
        XCTAssertFalse(restoreCloud.isHidden)
        XCTAssertTrue(restoreCloud.isEnabled)
        XCTAssertEqual(restoreCloud.title(for: .normal), "Restore from Google Drive backup")
        XCTAssertEqual(WalletCloudBackupRecoveryError.title(for: WalletCloudBackupRecoveryError.notFound),
            "Backup not found")
        XCTAssertTrue(WalletCloudBackupRecoveryError.userMessage(for: WalletCloudBackupRecoveryError.notFound)
            .contains("again to choose another Google account"))
        XCTAssertEqual(WalletCloudBackupRecoveryError.title(for: WalletCloudBackupRecoveryError.authorizationCanceled),
            "Google sign-in canceled")
        XCTAssertTrue(WalletCloudBackupRecoveryError.userMessage(for: WalletCloudBackupRecoveryError.authorizationCanceled)
            .contains("No wallet keys were changed"))
        XCTAssertEqual(WalletCloudBackupRecoveryError.title(for: WalletCloudBackupRecoveryError.incorrectPassword),
            "Wallet keys not restored")
        XCTAssertTrue(try XCTUnwrap(descendants(missingKeysController.view).compactMap { $0 as? UILabel }
            .first { $0.accessibilityIdentifier == "wallet-recovery-cloud-status" }).isHidden)
        let missingKeysRetry = try XCTUnwrap(descendants(missingKeysController.view).compactMap { $0 as? UIButton }
            .first { $0.accessibilityIdentifier == "wallet-recovery-retry" })
        missingKeysRetry.sendActions(for: .touchUpInside)
        XCTAssertFalse(restore.isEnabled)
        XCTAssertFalse(restoreCloud.isEnabled)
        let missingKeysWithoutRetry = WalletRecoveryViewController(reason: reason,
            diagnostic: WalletStartupDiagnostic.current(settings))
        missingKeysWithoutRetry.loadViewIfNeeded()
        XCTAssertTrue(try XCTUnwrap(descendants(missingKeysWithoutRetry.view).compactMap { $0 as? UIButton }
            .first { $0.accessibilityIdentifier == "wallet-recovery-restore-keys" }).isHidden)
        XCTAssertTrue(try XCTUnwrap(descendants(missingKeysWithoutRetry.view).compactMap { $0 as? UIButton }
            .first { $0.accessibilityIdentifier == "wallet-recovery-restore-cloud-backup" }).isHidden)
    }

    @MainActor
    func testStorageRetryRemainsAvailableAfterRepeatedLowSpace() throws {
        let window = SoraWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        let presenter = SplashPresenter(window: window)
        let controller = SplashViewController()
        controller.presenter = presenter
        presenter.view = controller
        var retries = 0
        for expected in 1 ... 2 {
            controller.showStorageSpaceRetry { retries += 1 }
            controller.view.layoutIfNeeded()
            let retry = try XCTUnwrap(descendants(controller.view)
                .compactMap { $0 as? UIButton }
                .first { $0.accessibilityIdentifier == "wallet-upgrade-storage-retry" })
            XCTAssertTrue(retry.isEnabled)
            XCTAssertFalse(retry.frame.isEmpty)
            retry.sendActions(for: .touchUpInside)
            XCTAssertEqual(retries, expected)
            XCTAssertFalse(retry.isEnabled)
        }
    }

    @MainActor
    func testEditableSoraTextRetainsDynamicTypeAfterChanges() throws {
        let parent = UIViewController()
        let child = UIViewController()
        parent.addChild(child)
        parent.view.addSubview(child.view)
        child.didMove(toParent: parent)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        window.rootViewController = parent
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        let field = SoramitsuTextField()
        let textView = SoramitsuTextView()
        let unchanged = SoramitsuTextField()
        [field, textView, unchanged].forEach { child.view.addSubview($0) }
        field.sora.dynamicTextStyle = .body
        textView.sora.dynamicTextStyle = .body
        let base = FontType.textM.font
        for category: UIContentSizeCategory in [.large, .accessibilityExtraExtraExtraLarge] {
            if #available(iOS 17.0, *) {
                child.traitOverrides.preferredContentSizeCategory = category
                child.updateTraitsIfNeeded()
                child.view.updateTraitsIfNeeded()
                [field, textView, unchanged].forEach { $0.updateTraitsIfNeeded() }
            } else {
                parent.setOverrideTraitCollection(UITraitCollection(preferredContentSizeCategory: category), forChild: child)
            }
            parent.view.layoutIfNeeded()
            child.view.layoutIfNeeded()
            XCTAssertEqual(field.traitCollection.preferredContentSizeCategory, category)
            XCTAssertEqual(textView.traitCollection.preferredContentSizeCategory, category)
            for input in ["First", "Edited again"] {
                field.sora.text = input
                textView.sora.text = input
                unchanged.sora.text = input
                let expected = UIFontMetrics(forTextStyle: .body).scaledFont(for: base,
                    compatibleWith: UITraitCollection(preferredContentSizeCategory: category)).pointSize
                let fieldFont = try XCTUnwrap(field.attributedText?.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
                let viewFont = try XCTUnwrap(textView.attributedText.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
                XCTAssertEqual(fieldFont.pointSize, expected, accuracy: 0.1)
                XCTAssertEqual(viewFont.pointSize, expected, accuracy: 0.1)
                let originalFont = try XCTUnwrap(unchanged.attributedText?.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
                XCTAssertEqual(originalFont.pointSize, base.pointSize, accuracy: 0.1)
            }
        }
    }

    @MainActor
    func testRecoveryChoicesExposeSelectionAndRequireAllAcknowledgements() throws {
        let controller = AccountWarningViewController(warningType: .passphrase)
        var completions = 0
        controller.completion = { completions += 1 }
        controller.loadViewIfNeeded()
        let choices = descendants(controller.view).compactMap { $0 as? CheckView }
        XCTAssertEqual(choices.count, 3)
        controller.completeTapped()
        XCTAssertEqual(completions, 0)
        for choice in choices {
            XCTAssertTrue(choice.isAccessibilityElement)
            XCTAssertFalse(choice.accessibilityLabel?.isEmpty ?? true)
            XCTAssertFalse(choice.accessibilityTraits.contains(.selected))
            XCTAssertTrue(choice.accessibilityActivate())
            XCTAssertTrue(choice.accessibilityTraits.contains(.selected))
        }
        controller.completeTapped()
        XCTAssertEqual(completions, 1)
        XCTAssertTrue(try XCTUnwrap(choices.first).accessibilityActivate())
        controller.completeTapped()
        XCTAssertEqual(completions, 1)
    }

    func testPristineCurrentSQLiteCanRelaunchWithOrdinarySidecars() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let storeURL = directory.appendingPathComponent("UserDataModel.sqlite")
        let modelURL = try XCTUnwrap(Bundle.main.url(forResource: UserStorageParams.modelVersion.rawValue,
            withExtension: "omo", subdirectory: UserStorageParams.modelDirectory)
            ?? Bundle.main.url(forResource: UserStorageParams.modelVersion.rawValue,
                withExtension: "mom", subdirectory: UserStorageParams.modelDirectory))
        let model = try XCTUnwrap(NSManagedObjectModel(contentsOf: modelURL))
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        let database = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil,
            at: storeURL, options: nil)
        defer { try? coordinator.remove(database) }
        XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.path + "-shm"))
        let originalStore = try Data(contentsOf: storeURL)
        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()
        let gate = WalletRecoveryCapabilityGate(settings: settings,
            unresolvedMigrationJournal: { false }, unresolvedWalletCommitJournal: { false })
        let migrator = UserStorageMigrator(targetVersion: UserStorageParams.modelVersion, storeURL: storeURL,
            modelDirectory: UserStorageParams.modelDirectory, keystore: keychain, settings: settings,
            fileManager: .default, recoveryGate: gate, loadWalletNetworkSnapshot: { nil })
        for _ in 0 ..< 2 {
            try migrator.performMigration()
            XCTAssertFalse(settings.hasRetainedWalletSettings())
            XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("WalletMigrationSafety").path))
            XCTAssertEqual(try Data(contentsOf: storeURL), originalStore)
        }
        try keychain.addKey(Data([1]), with: KeystoreTag.pincode.rawValue)
        XCTAssertThrowsError(try migrator.performMigration()) { error in
            guard case UserStorageMigrationError.missingWalletStore = error else {
                return XCTFail("Unexpected retained-wallet admission: \(error)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: storeURL), originalStore)
    }

    func testFirstLaunchKeepsPristineNamespaceAndReachesOnboarding() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try makeWalletNetworkStore(baseURL: directory)
        let settings = InMemorySettingsManager()
        let keychain = InMemoryKeychain()
        let root = RootInteractor(settings: settings, keystore: keychain, migrators: [],
            securityLayerInteractor: WalletUXSecurityLayerStub(),
            networkAvailabilityLayerInteractor: nil, legacyUpgradeSelectedAccount: { nil },
            legacyUpgradeSnapshotLoader: { try store.load() }, legacyUpgradeUnresolvedCommitLoader: { [] })
        let presenter = WalletUXRootPresenterSpy()
        root.presenter = presenter
        for _ in 0 ..< 2 {
            try SplashInteractor.initializeWalletNetworksIfNeeded(accounts: [], selectedAddress: nil,
                store: store, keystore: keychain, settings: settings)
            XCTAssertNil(try store.load())
            XCTAssertFalse(settings.hasRetainedWalletSettings())
            root.decideModuleSynchroniously()
        }
        XCTAssertEqual(presenter.decisions, [.onboarding, .onboarding])
    }

    func testEmptyBootstrapPreservesRetainedEvidenceAndRecovery() throws {
        for kind in ["pin", "watch-only", "version", "identity"] {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: directory) }
            let store = try makeWalletNetworkStore(baseURL: directory)
            let settings = InMemorySettingsManager()
            let keychain = InMemoryKeychain()
            switch kind {
            case "pin": try keychain.addKey(Data([1, 2, 3]), with: KeystoreTag.pincode.rawValue)
            case "watch-only": settings.set(value: true, for: "wallet.watchOnly.retained")
            case "version": settings.set(value: 3, for: SettingsKey.walletNetworkStoreVersion.rawValue)
            default: settings.set(value: "retained-id", for: SettingsKey.decentralizedId.rawValue)
            }
            let keysBefore = Set(settings.allKeys())
            let identifiersBefore = try keychain.allKeyIdentifiers()
            try SplashInteractor.initializeWalletNetworksIfNeeded(accounts: [], selectedAddress: nil,
                store: store, keystore: keychain, settings: settings)
            XCTAssertEqual(Set(settings.allKeys()), keysBefore)
            XCTAssertEqual(try keychain.allKeyIdentifiers(), identifiersBefore)
            XCTAssertNil(try store.load())
            let root = RootInteractor(settings: settings, keystore: keychain, migrators: [],
                securityLayerInteractor: WalletUXSecurityLayerStub(),
                networkAvailabilityLayerInteractor: nil, legacyUpgradeSelectedAccount: { nil },
                legacyUpgradeSnapshotLoader: { try store.load() }, legacyUpgradeUnresolvedCommitLoader: { [] })
            let presenter = WalletUXRootPresenterSpy()
            root.presenter = presenter
            root.decideModuleSynchroniously()
            XCTAssertEqual(presenter.decisions, [.broken], kind)
        }
    }

    func testEmptyBootstrapRejectsCorruptSnapshotWithoutChangingIt() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try makeWalletNetworkStore(baseURL: directory)
        let pointer = directory.appendingPathComponent("SORA/WalletNetworks/active.json")
        let retained = Data("interrupted-pointer".utf8)
        try retained.write(to: pointer)
        XCTAssertThrowsError(try SplashInteractor.initializeWalletNetworksIfNeeded(accounts: [], selectedAddress: nil,
            store: store, keystore: InMemoryKeychain(), settings: InMemorySettingsManager()))
        XCTAssertEqual(try Data(contentsOf: pointer), retained)
    }

    private func makeWalletNetworkStore(baseURL: URL) throws -> WalletNetworkStore {
        let gate = WalletRecoveryCapabilityGate(settings: InMemorySettingsManager(),
            unresolvedMigrationJournal: { false }, unresolvedWalletCommitJournal: { false })
        return try WalletNetworkStore(baseURL: baseURL, recoveryGate: gate)
    }

    @MainActor
    func testChartKeepsItsDescriptionAndExpandsForNarrowScreens() {
        let chart = PolkamarktLineChartView(frame: .zero)
        chart.caption = "Yes probability history"
        chart.context = "From 30% yesterday to 65% today. Vertical scale: 0% to 100%. Snapshots run from oldest to newest at equal spacing."
        chart.values = [0.3, 0.5, 0.65]
        XCTAssertTrue(chart.isAccessibilityElement)
        XCTAssertTrue(chart.accessibilityLabel?.contains(chart.context) == true)
        let wide = chart.sizeThatFits(CGSize(width: 600, height: 1000))
        let narrow = chart.sizeThatFits(CGSize(width: 320, height: 1000))
        XCTAssertGreaterThan(narrow.height, wide.height)
        XCTAssertGreaterThan(narrow.height, 180)
    }

    func testTotalRetainsExactPrecisionAndRejectsInvalidAmounts() throws {
        for (amount, fee, expected) in [
            ("12.5", "0.01", "12.51"),
            ("0.000000001", "0.000000009", "0.000000010"),
            ("999999999999999999999999999999999999999999.99", "0.01", "1000000000000000000000000000000000000000000.00")
        ] {
            XCTAssertEqual(WalletUX.total(amount: try PIQuantity(amount), fee: try PIQuantity(fee)), expected)
        }
        XCTAssertNil(WalletUX.total(amount: try PIQuantity("-1"), fee: try PIQuantity("0.01")))
        XCTAssertNil(WalletUX.total(amount: try PIQuantity("1"), fee: try PIQuantity("-0.01")))
    }

    func testLocalizationUsesSelectedLanguageThenEnglishFallback() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("bundle")
        defer { try? FileManager.default.removeItem(at: root) }
        for (language, content) in [
            ("en", "\"Greeting\" = \"Hello\";\n\"Fallback\" = \"English fallback\";\n\"Blank\" = \"English instead\";"),
            ("ja", "\"Greeting\" = \"こんにちは\";\n\"Blank\" = \"\";")
        ] {
            let directory = root.appendingPathComponent(language + ".lproj")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try content.write(to: directory.appendingPathComponent("Localizable.strings"), atomically: true, encoding: .utf8)
        }
        let bundle = try XCTUnwrap(Bundle(url: root))
        XCTAssertEqual(WalletUX.text("Greeting", language: "ja", bundle: bundle), "こんにちは")
        XCTAssertEqual(WalletUX.text("Fallback", language: "ja", bundle: bundle), "English fallback")
        XCTAssertEqual(WalletUX.text("Blank", language: "ja", bundle: bundle), "English instead")
        XCTAssertEqual(WalletUX.text("Greeting", language: "missing", bundle: bundle), "Hello")
    }

    func testGeneratedStringsChooseAValueBeforeFallingBackToEnglish() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("bundle")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let info = ["CFBundleDevelopmentRegion": "en", "CFBundleIdentifier": "org.sora.tests.localization"]
        let infoData = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try infoData.write(to: root.appendingPathComponent("Info.plist"))

        for (language, strings, plural) in [
            ("en", "\"greeting.key\" = \"Hello\";\n\"blank.key\" = \"English value\";\n\"formatted.key\" = \"Welcome %@\";",
             "%d items"),
            ("ja", "\"greeting.key\" = \"こんにちは\";\n\"blank.key\" = \"\";", "%d 項目")
        ] {
            let directory = root.appendingPathComponent(language + ".lproj")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try strings.write(to: directory.appendingPathComponent("Localizable.strings"),
                              atomically: true, encoding: .utf8)
            let pluralEntry: [String: Any] = [
                "count.key": [
                    "NSStringLocalizedFormatKey": "%#@items@",
                    "items": [
                        "NSStringFormatSpecTypeKey": "NSStringPluralRuleType",
                        "NSStringFormatValueTypeKey": "d",
                        "one": plural,
                        "other": plural
                    ]
                ]
            ]
            let pluralData = try PropertyListSerialization.data(fromPropertyList: pluralEntry,
                                                                format: .xml, options: 0)
            try pluralData.write(to: directory.appendingPathComponent("Localizable.stringsdict"))
        }

        let fixture = try XCTUnwrap(Bundle(url: root))
        func value(_ key: String) throws -> (Locale, String) {
            let (locale, selectedBundle) = try XCTUnwrap(
                R.localeBundle(tableName: "Localizable", key: key,
                               preferredLanguages: ["ja"], in: fixture)
            )
            return (locale, selectedBundle.localizedString(forKey: key, value: nil, table: "Localizable"))
        }

        XCTAssertEqual(try value("greeting.key").1, "こんにちは")
        XCTAssertEqual(try value("blank.key").1, "English value")
        let englishFormat = try value("formatted.key")
        XCTAssertEqual(String(format: englishFormat.1, locale: englishFormat.0, "Sora"), "Welcome Sora")
        let japanesePlural = try value("count.key")
        XCTAssertEqual(String(format: japanesePlural.1, locale: japanesePlural.0, 2), "2 項目")
        XCTAssertNil(R.localeBundle(tableName: "Localizable", key: "absent.key",
                                   preferredLanguages: ["ja"], in: fixture))
    }

    func testGeneratedStringsFallbackInTheShippedCatalogs() {
        XCTAssertEqual(R.string.localizable.commonFarms(preferredLanguages: ["de-DE"]), "Farms")
        XCTAssertEqual(R.string.localizable.inviteCodeLeftMinutes(preferredLanguages: ["egy-Egyp"]), "m")
        XCTAssertEqual(R.string.localizable.inviteCodeLeftMinutes(preferredLanguages: ["ja"]), "分")
        XCTAssertEqual(R.string.localizable.approveTheIrohaConnectConnectionFor(
            "Sora", preferredLanguages: ["ja"]), "Approve the IrohaConnect connection for Sora")
        XCTAssertTrue(R.string.localizable.favoriteUsers(favorite: 2,
                                                         preferredLanguages: ["ja"]).contains("お気に入り"))
        XCTAssertEqual(R.string.localizable.referendumDateSecondPlurals(
            preferredLanguages: ["ja"]), "")
    }

    func testLegacyLocalizableErrorsUseEnglishWhenSelectedValueIsMissing() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathExtension("bundle")
        defer { try? FileManager.default.removeItem(at: root) }
        for (language, strings) in [
            ("en", "\"selected.key\" = \"English selected\";\n\"missing.key\" = \"English fallback\";\n\"empty.key\" = \"English instead\";"),
            ("ja", "\"selected.key\" = \"日本語\";\n\"empty.key\" = \"\";")
        ] {
            let directory = root.appendingPathComponent(language + ".lproj")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try strings.write(to: directory.appendingPathComponent("Localizable.strings"),
                              atomically: true, encoding: .utf8)
        }
        let bundle = try XCTUnwrap(Bundle(url: root))
        func localize(_ key: String) -> String {
            L10n.getFormat(for: key, localization: "ja", bundle: bundle)
        }

        XCTAssertEqual(localize("selected.key"), "日本語")
        XCTAssertEqual(localize("missing.key"), "English fallback")
        XCTAssertEqual(localize("empty.key"), "English instead")
        XCTAssertEqual(localize("unshipped.key"), "")

        let activeFallbacks = [
            "amount.error.asset": "Sorry, we couldn't find asset information you want to send. Please, try again later.",
            "amount.error.balance": "Sorry, balance checking request failed. Please, try again later.",
            "amount.error.transfer": "Sorry, we couldn't contact transfer provider. Please, try again later.",
            "invoice_scan.error.camera_restricted_previously": "Unfortunately, you denied access to camera previously. Would you like to allow access now?",
            "invoice_scan.error.camera_title": "Camera Access",
            "invoice_scan.error.extract_fail": "Can't extract receiver's data",
            "invoice_scan.error.gallery_restricted_previously": "Unfortunately, you denied access to photos previously. Would you like to allow access now?",
            "invoice_scan.error.gallery_title": "Photos Access",
            "invoice_scan.error.match": "You can't send to yourself",
            "invoice_scan.error.no_internet": "Please, check internet connection",
            "invoice_scan.error.user_not_found": "Can't find a user from QR"
        ]
        for (key, expected) in activeFallbacks {
            XCTAssertEqual(localize(key), expected, key)
        }

        XCTAssertEqual(TransferPresenterError.missingAsset
            .toErrorContent(for: Locale(identifier: "ja")).title, "エラー")
        XCTAssertEqual(TransferPresenterError.missingAsset
            .toErrorContent(for: Locale(identifier: "ja")).message,
                       activeFallbacks["amount.error.asset"])
        XCTAssertEqual(L10n.InvoiceScan.Error.extractFail,
                       activeFallbacks["invoice_scan.error.extract_fail"])
    }

    @MainActor
    func testWalletSecondaryTextMeetsContrastInBothThemes() {
        let previous = SoramitsuUI.shared.themeMode
        defer { SoramitsuUI.shared.themeMode = previous }
        for mode in [SoramitsuThemeMode.manual(.light), .manual(.dark)] {
            SoramitsuUI.shared.themeMode = mode
            XCTAssertGreaterThanOrEqual(WalletUX.contrast(WalletUX.secondary, WalletUX.page), 4.5)
            XCTAssertGreaterThanOrEqual(WalletUX.contrast(WalletUX.secondary, WalletUX.surface), 4.5)
        }
    }

    @MainActor
    func testBusySendCannotStartAnotherReview() throws {
        let view = NexusSendViewController(network: "Taira · TESTNET", balance: "100")
        view.loadViewIfNeeded()
        try XCTUnwrap(descendants(view.view).compactMap { $0 as? UITextView }.first).text = "recipient"
        try XCTUnwrap(descendants(view.view).compactMap { $0 as? UITextField }.first).text = "1"
        var reviews = 0
        view.onReview = { _, _ in reviews += 1; view.setBusy(true) }
        let primary = try XCTUnwrap(button("Review send", in: view.view))
        primary.sendActions(for: .touchUpInside)
        primary.sendActions(for: .touchUpInside)
        XCTAssertEqual(reviews, 1)
    }

    @MainActor
    func testEditingReviewPreservesDraftAndRequiresAnotherQuote() throws {
        let view = NexusSendViewController(network: "Taira · TESTNET", balance: "100")
        view.loadViewIfNeeded()
        let recipient = try XCTUnwrap(descendants(view.view).compactMap { $0 as? UITextView }.first)
        let amount = try XCTUnwrap(descendants(view.view).compactMap { $0 as? UITextField }.first)
        recipient.text = "test-recipient-address"
        amount.text = "12.5"
        let quantity = try PIQuantity("12.5")
        let request = NexusTransferRequest(walletId: "test-wallet", networkId: .taira,
            sender: "test-sender", receiver: recipient.text, amount: quantity)
        let quote = NexusTransferFeeQuote(networkId: .taira, authority: "test-sender", receiver: recipient.text,
            assetDefinitionId: "test-asset", amount: quantity, fee: try PIQuantity("0.01"), quoteIdentity: "test-quote", validUntilBlock: 100)
        let prepared = NexusPreparedTransfer(request: request, canonicalReceiver: recipient.text,
            assetDefinitionID: "test-asset", availableBalance: try PIQuantity("100"), quote: quote)
        XCTAssertFalse(prepared.submissionMayHaveStarted)
        view.showReview(prepared)
        XCTAssertTrue(descendants(view.view).compactMap { ($0 as? UILabel)?.text }.contains("12.51 XOR"))
        let edit = try XCTUnwrap(button("Edit details", in: view.view))
        edit.sendActions(for: .touchUpInside)
        XCTAssertEqual(recipient.text, "test-recipient-address")
        XCTAssertEqual(amount.text, "12.5")
        var reviewedDraft: (String, String)?
        view.onReview = { reviewedDraft = ($0, $1) }
        view.onConfirm = { _ in XCTFail("Editing must invalidate the prepared quote") }
        try XCTUnwrap(button("Review send", in: view.view)).sendActions(for: .touchUpInside)
        XCTAssertEqual(reviewedDraft?.0, "test-recipient-address")
        XCTAssertEqual(reviewedDraft?.1, "12.5")

        view.showReview(prepared)
        view.setBusy(true)
        view.showUnsentError(WalletUX.sendError(NexusToriiError.quoteExpired))
        reviewedDraft = nil
        try XCTUnwrap(button("Review send", in: view.view)).sendActions(for: .touchUpInside)
        XCTAssertEqual(reviewedDraft?.0, "test-recipient-address")
        XCTAssertEqual(reviewedDraft?.1, "12.5")

        view.showReview(prepared)
        var submissions = 0
        view.onConfirm = { _ in submissions += 1; view.setBusy(true) }
        let confirm = try XCTUnwrap(button("Confirm and send", in: view.view))
        confirm.sendActions(for: .touchUpInside)
        confirm.sendActions(for: .touchUpInside)
        XCTAssertEqual(submissions, 1, "A busy confirmation must not submit twice")
        prepared.markTransportStarted()
        XCTAssertTrue(prepared.submissionMayHaveStarted)
    }

    func testAmbiguousSendNeverLooksCompletedOrInvitesResubmission() {
        XCTAssertNotEqual(WalletUX.status(.submissionUnknown), WalletUX.status(.committed))
        XCTAssertTrue(WalletUX.statusDetail(.submissionUnknown).contains("do not send it again"))
        XCTAssertTrue(WalletUX.sendError(NexusToriiError.ambiguousSubmission).contains("Activity"))
        XCTAssertNotEqual(WalletUX.status(.committedPendingReconciliation), WalletUX.status(.committed))
        XCTAssertTrue(WalletUX.sendOutcomeNeedsChecking(NexusToriiError.ambiguousSubmission))
        XCTAssertTrue(WalletUX.sendOutcomeNeedsChecking(NexusToriiError.confirmationAlreadySubmitted))
        XCTAssertTrue(WalletUX.sendOutcomeNeedsChecking(NexusToriiError.transactionHashMismatch))
        XCTAssertTrue(WalletUX.sendOutcomeNeedsChecking(NexusToriiError.httpStatus(500)))
        XCTAssertTrue(WalletUX.sendOutcomeNeedsChecking(NexusToriiError.server))
        XCTAssertTrue(WalletUX.sendOutcomeNeedsChecking(NexusToriiError.invalidResponse))
        XCTAssertFalse(WalletUX.sendOutcomeNeedsChecking(NexusToriiError.insufficientBalance))
        XCTAssertFalse(WalletUX.sendOutcomeNeedsChecking(NexusToriiError.quoteExpired))
        XCTAssertFalse(WalletUX.sendOutcomeNeedsChecking(NexusToriiError.httpStatus(500), submissionMayHaveStarted: false),
                       "A failed read before transport must restore the draft")
        XCTAssertTrue(WalletUX.sendOutcomeNeedsChecking(NexusToriiError.quoteExpired, submissionMayHaveStarted: true),
                      "The transport boundary takes precedence over an error classification")
        XCTAssertTrue(WalletUX.sendOutcomeNeedsChecking(NexusToriiError.confirmationAlreadySubmitted, submissionMayHaveStarted: false))
    }

    @MainActor
    func testUncertainSubmissionOnlyOffersActivity() throws {
        let view = NexusSendViewController(network: "Taira · TESTNET", balance: "100")
        view.loadViewIfNeeded()
        view.onConfirm = { _ in XCTFail("An uncertain submission must not be sent again") }
        view.onReview = { _, _ in XCTFail("An uncertain submission must not be reviewed again") }
        view.showUncertainSubmission(WalletUX.sendError(NexusToriiError.ambiguousSubmission))
        let primary = try XCTUnwrap(button("Review send", in: view.view))
        let edit = try XCTUnwrap(button("Edit details", in: view.view))
        XCTAssertTrue(primary.isHidden)
        XCTAssertTrue(edit.isHidden)
        XCTAssertFalse(try XCTUnwrap(button("View Activity", in: view.view)).isHidden)
        primary.sendActions(for: .touchUpInside)
        edit.sendActions(for: .touchUpInside)
        XCTAssertTrue(primary.isHidden)
    }

    func testDurableAncestorSynchronizationStopsAtContainerBeforeSandboxDeniedParent() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let container = root.appendingPathComponent("AppHome", isDirectory: true)
        let shallow = container.appendingPathComponent("Documents/CoreData", isDirectory: true)
        let deep = container.appendingPathComponent("Library/Application Support/SORA/WalletNetworks", isDirectory: true)
        try FileManager.default.createDirectory(at: shallow, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: deep, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let alias = root.appendingPathComponent("AppHomeAlias", isDirectory: true)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: container)
        let homeDescriptor = Darwin.open(container.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        XCTAssertGreaterThanOrEqual(homeDescriptor, 0)
        defer { _ = Darwin.close(homeDescriptor) }
        var homeIdentity = stat()
        XCTAssertEqual(Darwin.fstat(homeDescriptor, &homeIdentity), 0)
        let cases: [(URL, URL, Int)] = [
            (container, container, 0),
            (shallow, container, 2),
            (deep, container, 4),
            (alias.appendingPathComponent("Documents/CoreData"), container, 2),
            (shallow, alias, 2)
        ]
        for (start, boundary, expectedOpens) in cases {
            let descriptor = Darwin.open(start.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
            XCTAssertGreaterThanOrEqual(descriptor, 0)
            defer { _ = Darwin.close(descriptor) }
            var opens = 0
            var outsideContainerAttempted = false
            try DurableFileWriter.synchronizeAncestorDirectoryEntries(from: descriptor,
                maximumDepth: 4, containerURL: boundary, openParent: { current in
                    var identity = stat()
                    guard Darwin.fstat(current, &identity) == 0 else { return -1 }
                    if identity.st_dev == homeIdentity.st_dev && identity.st_ino == homeIdentity.st_ino {
                        outsideContainerAttempted = true
                        errno = EACCES
                        return -1
                    }
                    opens += 1
                    return Darwin.openat(current, "..", O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
                })
            XCTAssertEqual(opens, expectedOpens)
            XCTAssertFalse(outsideContainerAttempted,
                "The app container must be recognized before openat attempts its forbidden parent")
        }
        let descriptor = Darwin.open(shallow.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        XCTAssertGreaterThanOrEqual(descriptor, 0)
        defer { _ = Darwin.close(descriptor) }
        var attempted = 0
        XCTAssertThrowsError(try DurableFileWriter.synchronizeAncestorDirectoryEntries(from: descriptor,
            maximumDepth: 4, containerURL: container, openParent: { _ in
                attempted += 1
                errno = EACCES
                return -1
            })) { error in
                guard case DurableFileWriter.Failure.fileSystemFailure = error else {
                    return XCTFail("An in-container durability failure must remain a failure")
                }
            }
        XCTAssertEqual(attempted, 1)
    }

    @MainActor
    private func descendants(_ view: UIView) -> [UIView] {
        view.subviews.flatMap { [$0] + descendants($0) }
    }
    @MainActor
    private func button(_ title: String, in view: UIView) -> UIButton? {
        descendants(view).compactMap { $0 as? UIButton }.first {
            ($0.configuration?.title ?? $0.title(for: .normal)) == WalletUX.text(title)
        }
    }
}

private final class WalletUXSecurityLayerStub: SecurityLayerInteractorInputProtocol {
    func setup() {}
}

private final class WalletUXRootPresenterSpy: RootInteractorOutputProtocol {
    enum Decision: Equatable { case onboarding, legacyWalletUpgrade, localAuthentication, broken, pincodeSetup }
    var decisions: [Decision] = []
    func didDecideOnboarding() { decisions.append(.onboarding) }
    func didDecideLegacyWalletUpgrade() { decisions.append(.legacyWalletUpgrade) }
    func didDecideLocalAuthentication() { decisions.append(.localAuthentication) }
    func didDecideBroken() { decisions.append(.broken) }
    func didDecidePincodeSetup() { decisions.append(.pincodeSetup) }
}

private final class WalletUXNoBiometry: BiometryAuthProtocol {
    var availableBiometryType: AvailableBiometryType { .none }
    func authenticate(localizedReason: String, completionQueue: DispatchQueue, completionBlock: @escaping (Bool) -> Void) {
        completionQueue.async { completionBlock(false) }
    }
}

private final class WalletUXPINViewSpy: UIViewController, PinSetupViewProtocol {
    var controller: UIViewController { self }
    var symbolCounts: [Int] = []
    var updateRequests = 0
    var titles: [String] = []
    var blockedDates: [Date] = []
    func didRequestBiometryUsage(biometryType: AvailableBiometryType, completionBlock: @escaping (Bool) -> Void) { completionBlock(false) }
    func didChangeAccessoryState(enabled: Bool) {}
    func didReceiveWrongPincode() {}
    func updatePinCodeSymbolsCount(with count: Int) { symbolCounts.append(count) }
    func showUpdatePinRequestView() { updateRequests += 1 }
    func blockUserInputUntil(date: Date) { blockedDates.append(date) }
    func showLastChanceAlert() {}
    func updateInputedCircles(with count: Int) {}
    func setupDeleteButton(isHidden: Bool) {}
    func setupTitleLabel(text: String) { titles.append(text) }
    func resetTitleColor() {}
    func animateWrongInputError(with completion: @escaping (Bool) -> Void) { completion(true) }
    func askBiometryPermission() {}
}

private final class WalletUXLocalAuthSpy: LocalAuthInteractorInputProtocol {
    var allowManualBiometryAuth: Bool { false }
    var countRequests = 0
    var submitted: [String] = []
    var updated: [String] = []
    var blockDate: Date?
    func startAuth(completion: (() -> Void)?) {}
    func process(pin: String) { submitted.append(pin) }
    func getPinCodeCount() { countRequests += 1 }
    func getInputBlockDate() -> Date? { blockDate }
    func updatePin(pin: String, completion: (() -> Void)?) { updated.append(pin); completion?() }
}

private final class WalletUXPINWireframeSpy: PinSetupWireframeProtocol {
    var mainCount = 0
    func dismiss(from view: PinSetupViewProtocol?) {}
    func showMain(from view: PinSetupViewProtocol?) { mainCount += 1 }
    func showSignup(from view: PinSetupViewProtocol?) {}
    func showPinUpdatedNotify(from view: PinSetupViewProtocol?, completionBlock: @escaping () -> Void) { completionBlock() }
}

private final class WalletUXAuthorizationSpy: ScreenAuthorizationWireframeProtocol {
    var results: [Bool] = []
    func showAuthorizationCompletion(with result: Bool) { results.append(result) }
}

private final class WalletUXNetworkStatusSpy: ApplicationStatusPresentable {
    var alerts = 0
    var statuses: [String] = []
    func presentAlert(alert: UIAlertController, animated: Bool) { alerts += 1 }
    func presentStatus(title: String, style: ApplicationStatusStyle, animated: Bool) { statuses.append(title) }
    func dismissStatus(title: String?, style: ApplicationStatusStyle?, animated: Bool) {}
}
