import CryptoKit
import XCTest

/// Normal app launches after the separate unit-host writer exits. This does not
/// loosen or invoke the production-IPA retained-device evidence controller.
final class WalletSimulatorUpgradeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        #if targetEnvironment(simulator)
        let env = ProcessInfo.processInfo.environment
        guard env["SORA_SIMULATOR_FIXTURES"] == "PUBLIC_FIXTURES_ONLY",
              let expected = env["SORA_SIMULATOR_EXPECTED_UDID"],
              env["SIMULATOR_UDID"] == expected,
              env["SORA_SIMULATOR_CASE"] != nil else {
            throw XCTSkip("Opt-in public fixtures on an explicitly owned simulator only")
        }
        #else
        throw XCTSkip("Simulator source qualification is not physical release evidence")
        #endif
    }

    func testNormalApplicationLaunchAfterHistoricalWriter() throws {
        let env = ProcessInfo.processInfo.environment
        let name = try XCTUnwrap(env["SORA_SIMULATOR_CASE"])
        let route = try XCTUnwrap(env["SORA_SIMULATOR_ROUTE"])
        let phase = env["SORA_SIMULATOR_PHASE"] ?? "single"
        let publicPIN = ["two-reinstalls", "preserved-return"].contains(name) ? "654321" : "123456"
        let bundle = env["SORA_SIMULATOR_APP_BUNDLE"] ?? "co.jp.soramitsu.sora.dev"
        XCTAssertTrue(["co.jp.soramitsu.sora.dev", "co.jp.soramitsu.sora"].contains(bundle))
        let app = XCUIApplication(bundleIdentifier: bundle)
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        defer { app.terminate() }
        func evidence(_ suffix: String) {
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = name + "-" + suffix
            screenshot.lifetime = .keepAlways
            add(screenshot)
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = name + "-" + suffix + "-accessibility"
            tree.lifetime = .keepAlways
            add(tree)
        }
        func importPublicPhrase() throws {
            app.buttons["Import account"].tap()
            let source = app.buttons["Passphrase"]
            XCTAssertTrue(source.waitForExistence(timeout: 10))
            source.tap()
            let phrase = app.textViews.firstMatch
            XCTAssertTrue(phrase.waitForExistence(timeout: 10))
            phrase.tap()
            phrase.typeText(try XCTUnwrap(env["SORA_SIMULATOR_PUBLIC_PHRASE"]))
            let next = app.buttons["Continue"]
            if !next.isHittable { app.swipeUp() }
            next.tap()
            let accountName = app.textFields["Account name"]
            XCTAssertTrue(accountName.waitForExistence(timeout: 10))
            accountName.tap()
            accountName.typeText("Audit imported phrase")
            if !next.isHittable { app.swipeUp() }
            next.tap()
            evidence("public-phrase-import")
        }
        if route == "welcome" {
            XCTAssertTrue(app.otherElements["wallet-welcome-back"].waitForExistence(timeout: 60))
            XCTAssertTrue(app.buttons["wallet-welcome-back-phrase"].exists)
            evidence("welcome")
            if name == "two-reinstalls" && phase == "first-install" {
                let setUp = app.buttons["wallet-welcome-back-set-up-again"]
                XCTAssertTrue(setUp.waitForExistence(timeout: 10))
                setUp.tap()
                let first = app.alerts["Set up this iPhone again?"]
                XCTAssertTrue(first.waitForExistence(timeout: 10))
                evidence("first-uninstall-confirmation-1")
                first.buttons["Continue"].tap()
                let second = app.alerts["Start fresh?"]
                XCTAssertTrue(second.waitForExistence(timeout: 10))
                evidence("first-uninstall-confirmation-2")
                second.buttons["Set up again"].tap()
                let retained = app.alerts["Restore the wallets found on this iPhone first?"]
                XCTAssertTrue(retained.waitForExistence(timeout: 10))
                evidence("explicitly-continue-without-A")
                retained.buttons["Continue without them"].tap()
                XCTAssertTrue(app.buttons["Create account"].waitForExistence(timeout: 20), app.debugDescription)
                try importPublicPhrase()
            } else if name == "bound-reinstall" || (name == "two-reinstalls" && phase == "second-install") {
                let restore = app.buttons["wallet-welcome-back-restore-found"]
                XCTAssertTrue(restore.waitForExistence(timeout: 15))
                restore.tap()
                let pin = app.secureTextFields["wallet-retained-pin"]
                XCTAssertTrue(pin.waitForExistence(timeout: 10))
                pin.tap()
                pin.typeText(publicPIN)
                app.alerts.buttons["Continue"].tap()
            } else {
                XCTAssertFalse(app.buttons["wallet-welcome-back-restore-found"].exists)
                return
            }
        } else if route == "onboarding" {
            XCTAssertTrue(app.buttons["Create account"].waitForExistence(timeout: 60), app.debugDescription)
            XCTAssertFalse(app.otherElements["wallet-welcome-back"].exists)
            evidence("onboarding-preserved-metadata")
            if name == "fresh-import" {
                try importPublicPhrase()
            } else { return }
        } else if route == "recovery" {
            XCTAssertTrue(app.otherElements["sora.migrationEvidence.v3.recovery"].waitForExistence(timeout: 60))
            XCTAssertTrue(app.buttons["wallet-recovery-restore-phrase"].exists)
            evidence("recovery")
            if name == "preserved-return" {
                let setUp = app.buttons["wallet-recovery-set-up-again"]
                if !setUp.isHittable { app.swipeUp() }
                XCTAssertTrue(setUp.isHittable, app.debugDescription)
                setUp.tap()
                let first = app.alerts["Set up this iPhone again?"]
                XCTAssertTrue(first.waitForExistence(timeout: 10))
                evidence("preserve-confirmation-1")
                first.buttons["Continue"].tap()
                let second = app.alerts["Start fresh?"]
                XCTAssertTrue(second.waitForExistence(timeout: 10))
                evidence("preserve-confirmation-2")
                second.buttons["Set up again"].tap()
                XCTAssertTrue(app.otherElements["wallet-welcome-back"].waitForExistence(timeout: 30), app.debugDescription)
                let earlier = app.buttons["wallet-welcome-back-earlier-data"]
                XCTAssertTrue(earlier.waitForExistence(timeout: 15), app.debugDescription)
                if !earlier.isHittable { app.swipeUp() }
                evidence("preserved-generation-available")
                earlier.tap()
                let ownerPIN = app.secureTextFields["wallet-retained-pin"]
                XCTAssertTrue(ownerPIN.waitForExistence(timeout: 15), app.debugDescription)
                evidence("return-requires-owner-pin")
                ownerPIN.tap()
                ownerPIN.typeText("123456")
                app.alerts.buttons["Continue"].tap()
                let protect = app.alerts["Protect the returned wallets"]
                XCTAssertTrue(protect.waitForExistence(timeout: 15), app.debugDescription)
                evidence("return-new-pin-confirmation")
                let newPIN = protect.secureTextFields["App PIN"]
                newPIN.tap()
                newPIN.typeText(publicPIN)
                let confirmation = protect.secureTextFields["Confirm app PIN"]
                confirmation.tap()
                confirmation.typeText(publicPIN)
                protect.buttons["Use earlier wallet data"].tap()
            } else { return }
        }
        do {
            // An update asks nothing: whatever the old state, the next thing
            // on screen is the ordinary PIN pad.
            XCTAssertTrue(app.otherElements["MainViewAccessibilityId"].waitForExistence(timeout: 60), app.debugDescription)
            XCTAssertFalse(app.buttons["sora.migrationEvidence.v3.continueUpgrade"].exists)
            XCTAssertFalse(app.alerts["Enter your PIN"].exists)
            evidence("pin")
            func enterPIN() {
                for digit in publicPIN {
                    let button = app.buttons[String(digit)]
                    if button.exists { button.tap() } else { app.staticTexts[String(digit)].firstMatch.tap() }
                }
            }
            enterPIN()
            if ["pinless", "metadata-only", "erase-restore", "fresh-import"].contains(name)
                || (name == "two-reinstalls" && phase == "first-install") {
                // Initial PIN validation runs asynchronously. Do not deliver
                // confirmation digits into the first entry's reset window.
                XCTAssertTrue(app.staticTexts["Confirm Pin Code"].waitForExistence(timeout: 15), app.debugDescription)
                enterPIN()
            }
            let restored = name == "bound-reinstall" || (name == "two-reinstalls" && phase == "second-install")
            let walletName = restored ? "Restored wallet" : (route == "legacy" ? "Public legacy fixture" : "Audit")
            // The portfolio home's wallet name is a button; the classic home's is a text.
            let wallet = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", walletName)).firstMatch
            if name == "unreachable-node" {
                // Local PIN must remain reachable despite the bad saved URL.
                // The node service may recover through its existing fallback;
                // otherwise opening must end in the actionable bounded state.
                let status = app.staticTexts["wallet-opening-status"]
                let safeOutcome = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                    wallet.exists || (status.exists
                        && status.label == "Wallet services are not ready. Try again or choose another node."
                        && app.buttons["wallet-opening-retry"].isEnabled
                        && app.buttons["wallet-opening-nodes"].isHittable)
                }, object: nil)
                XCTAssertEqual(XCTWaiter.wait(for: [safeOutcome], timeout: 30), .completed, app.debugDescription)
                XCTAssertFalse(app.otherElements["sora.migrationEvidence.v3.recovery"].exists)
                evidence(wallet.exists ? "unreachable-node-wallet-opened" : "unreachable-node-bounded-service-recovery")
                return
            }
            // Multiple wallets now open the aggregate portfolio. Select the
            // expected fixture through its real scope picker before checking
            // its address and phrase; an aggregate heading alone is not proof
            // that the original account is available.
            let allWallets = app.buttons["All wallets"]
            func waitForPortfolio(_ timeout: TimeInterval) -> Bool {
                let visible = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                    wallet.exists || allWallets.exists
                }, object: nil)
                return XCTWaiter.wait(for: [visible], timeout: timeout) == .completed
            }
            var opened = waitForPortfolio(20)
            if !opened, app.buttons["wallet-opening-retry"].exists {
                // Exercise the real bounded retry after an unavailable live
                // service. Keep the first result in the evidence, never call
                // an opening/retry screen a successful wallet launch.
                evidence("opening-service-retry")
                app.buttons["wallet-opening-retry"].tap()
                opened = waitForPortfolio(60)
            }
            XCTAssertTrue(opened, app.debugDescription)
            if !wallet.exists, allWallets.exists {
                allWallets.tap()
                let individual = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", walletName)).firstMatch
                XCTAssertTrue(individual.waitForExistence(timeout: 10), app.debugDescription)
                individual.tap()
                let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"),
                    object: app.buttons["portfolio.manage-wallets"])
                XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 10), .completed)
            }
            XCTAssertTrue(wallet.waitForExistence(timeout: 10), app.debugDescription)
            XCTAssertFalse(app.otherElements["sora.migrationEvidence.v3.recovery"].exists)
            evidence("wallet")
            if name == "fresh-import" || (name == "two-reinstalls" && phase == "first-install") {
                let activityTab = app.tabBars.buttons["Activity"]
                XCTAssertTrue(activityTab.waitForExistence(timeout: 10))
                activityTab.tap()
                XCTAssertTrue(activityTab.isSelected)
                evidence("activity")
                let walletTab = app.tabBars.buttons["Wallet"]
                XCTAssertTrue(walletTab.waitForExistence(timeout: 10))
                walletTab.tap()
                XCTAssertTrue(wallet.waitForExistence(timeout: 10))
                XCTAssertTrue(walletTab.isSelected)
                evidence("wallet-after-activity")
            }
            if env["SORA_SIMULATOR_REVEAL_PHRASE"] == "1" {
                // Showing the recovery phrase is a timed disclosure. XCTest otherwise waits up to 60 s
                // after a tap for the app's repeating animations to stop, and the phrase is covered
                // again before it is read. The wait is turned off only here, once a run has reached the
                // steps that show the phrase, and only where this Xcode has the setting. Everything
                // before this point, every case that never gets here, and an Xcode without the setting
                // run exactly as before.
                if app.responds(to: NSSelectorFromString("setIdleAnimationWaitEnabled:")) {
                    app.setValue(false, forKey: "idleAnimationWaitEnabled")
                }
                wallet.tap()
                // The portfolio's wallet name opens the Wallets sheet, which leads to the account list.
                let manage = app.buttons["portfolio.manage-wallets"].firstMatch
                XCTAssertTrue(manage.waitForExistence(timeout: 10))
                manage.tap()
                let options = app.buttons["wallet-account-options"].firstMatch
                XCTAssertTrue(options.waitForExistence(timeout: 10))
                evidence("account-picker")
                options.tap()
                if let address = env["SORA_SIMULATOR_ADDRESS"] {
                    XCTAssertTrue(app.staticTexts[address].waitForExistence(timeout: 10))
                }
                let show = app.staticTexts["Show Passphrase"]
                XCTAssertTrue(show.waitForExistence(timeout: 10))
                show.tap()
                for title in ["If I lose my passphrase, my funds will be lost forever.",
                              "If I expose or share my passphrase to anybody, my funds can get stolen.",
                              "It is my full responsibility to keep my passphrase secure."] {
                    let check = app.buttons[title]
                    XCTAssertTrue(check.waitForExistence(timeout: 10))
                    if !check.isHittable { app.swipeUp() }
                    check.tap()
                }
                let next = app.buttons["Continue"]
                if !next.isHittable { app.swipeUp() }
                next.tap()
                XCTAssertTrue(app.otherElements["MainViewAccessibilityId"].waitForExistence(timeout: 10))
                enterPIN()
                let count = try XCTUnwrap(env["SORA_SIMULATOR_WORD_COUNT"].flatMap(Int.init))
                let digest = try XCTUnwrap(env["SORA_SIMULATOR_PHRASE_SHA256"])
                XCTAssertTrue((12...24).contains(count))
                let reveal = app.buttons["wallet-backup-reveal"]
                XCTAssertTrue(reveal.waitForExistence(timeout: 10))
                let words = (1...count).map { app.staticTexts["wallet-backup-word-\($0)"].firstMatch }
                let last = try XCTUnwrap(words.last)
                // The screen may still be settling after the PIN controller disappears.
                // Wait for a real, hittable Show button before a user's reveal attempt.
                for attempt in 1...3 {
                    if last.exists { break }
                    let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                        reveal.exists && reveal.isEnabled && reveal.isHittable && app.state == .runningForeground
                    }, object: nil)
                    XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed)
                    if reveal.label != "Hide" { reveal.tap() }
                    let reached = last.waitForExistence(timeout: 3)
                    print("Historical export attempt \(attempt) first=\(words.first?.exists == true) last=\(reached) hidden=\(reveal.label != "Hide")")
                    if reached { break }
                }
                XCTAssertTrue(last.exists)
                let displayed = words.map(\.label).joined(separator: " ")
                let actual = SHA256.hash(data: Data(displayed.utf8)).map { String(format: "%02x", $0) }.joined()
                XCTAssertTrue(actual == digest, "Displayed recovery words differ from the public fixture")
            }
            if name == "metadata-only" || name == "erase-restore" {
                XCTAssertTrue(app.staticTexts["Read-only"].exists || app.staticTexts["Wallet keys are not on this iPhone"].exists, app.debugDescription)
            }
        }
    }
}
