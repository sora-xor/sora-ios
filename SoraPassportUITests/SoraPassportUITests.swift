import XCTest

class SoraPassportUITests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        XCUIApplication().launch()

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() {
        // Use recording to get started writing UI tests.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

}

/// Opt-in UI acceptance for an already-created, disposable simulator wallet.
/// It never creates an account, accepts terms, signs, or submits a transaction.
final class WalletUXVisualAcceptanceTests: XCTestCase {
    func testOnboardingScrollingKeyboardAndRecoveryChoices() throws {
        guard ProcessInfo.processInfo.environment["SORA_UX_ONBOARDING"] == "1" else {
            throw XCTSkip("Requires the isolated empty UX simulator")
        }
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "co.jp.soramitsu.sora.dev.flex")
        app.activate()
        let create = app.buttons["Create account"]
        XCTAssertTrue(create.waitForExistence(timeout: 20))
        for _ in 0 ..< 8 where !create.isHittable { app.swipeUp() }
        XCTAssertTrue(create.isHittable)
        keep(app, name: "Maximum text onboarding actions")
        create.tap()
        let field = app.textFields["Account name"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("UX Layout")
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        let proceed = app.buttons["Continue"]
        for _ in 0 ..< 5 where !proceed.isHittable { app.swipeUp() }
        XCTAssertTrue(proceed.isHittable)
        keep(app, name: "Maximum text name entry and keyboard")
        proceed.tap()
        let choices = [
            "If I lose my passphrase, my funds will be lost forever.",
            "If I expose or share my passphrase to anybody, my funds can get stolen.",
            "It is my full responsibility to keep my passphrase secure."
        ]
        for title in choices {
            let choice = app.buttons[title]
            XCTAssertTrue(choice.waitForExistence(timeout: 5))
            for _ in 0 ..< 5 where !choice.isHittable { app.swipeUp() }
            XCTAssertTrue(choice.isHittable)
            choice.tap()
            XCTAssertTrue(choice.isSelected)
        }
        for _ in 0 ..< 5 where !app.buttons["Continue"].isHittable { app.swipeUp() }
        XCTAssertTrue(app.buttons["Continue"].isEnabled)
        keep(app, name: "Maximum text recovery selections")
    }

    private func keep(_ app: XCUIApplication, name: String) {
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = name
        capture.lifetime = .keepAlways
        add(capture)
    }

    func testPreparedSampleWalletScrollingAndNavigation() throws {
        guard ProcessInfo.processInfo.environment["SORA_UX_SAMPLE_WALLET"] == "1" else {
            throw XCTSkip("Requires the isolated UX sample wallet simulator")
        }
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "co.jp.soramitsu.sora.dev.flex")
        app.activate()
        if app.staticTexts["Enter Pin Code"].waitForExistence(timeout: 5) {
            let pin = try XCTUnwrap(ProcessInfo.processInfo.environment["SORA_UX_SAMPLE_PIN"])
            for digit in pin { app.staticTexts[String(digit)].tap() }
        }
        XCTAssertTrue(app.buttons["UX Sample"].waitForExistence(timeout: 25))
        let table = app.tables.firstMatch
        XCTAssertTrue(table.exists)
        table.swipeUp()
        let holdings = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "0 XOR")).firstMatch
        XCTAssertTrue(holdings.isHittable, "Holdings must remain reachable below the enlarged wallet header")
        let capture = XCTAttachment(screenshot: app.screenshot())
        capture.name = "Sample wallet scrolled holdings"
        capture.lifetime = .keepAlways
        add(capture)
        table.swipeDown()
        let activity = app.tabBars.buttons["Activity"]
        XCTAssertTrue(activity.exists)
        activity.tap()
        let activityCapture = XCTAttachment(screenshot: app.screenshot())
        activityCapture.name = "Sample wallet Activity"
        activityCapture.lifetime = .keepAlways
        add(activityCapture)
        let wallet = app.tabBars.buttons["Wallet"]
        XCTAssertTrue(wallet.exists)
        wallet.tap()
        XCTAssertTrue(wallet.isSelected)
    }
}
