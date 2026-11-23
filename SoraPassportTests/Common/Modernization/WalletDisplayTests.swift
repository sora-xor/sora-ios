// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

@testable import SoraPassport
import SoraFoundation
import SoraKeystore
import SoraUIKit
import UIKit
import XCTest

/// The wallet on a folding iPhone: a cover screen that is a short, wide phone (466 × 678), and an inner
/// screen (951 × 669 the natural way up, 669 × 951 turned) the scene moves to and from while it runs.
/// Screens are laid out in windows of those sizes and resized between them; no test asks which device
/// it runs on.
@MainActor
final class WalletDisplayTests: XCTestCase {
    static let cover = CGSize(width: 466, height: 678)
    static let innerLandscape = CGSize(width: 951, height: 669)
    static let innerPortrait = CGSize(width: 669, height: 951)
    static let coverInsets = UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)
    static let innerInsets = UIEdgeInsets(top: 24, left: 0, bottom: 20, right: 0)
    static let classicPhones: [CGSize] = [
        CGSize(width: 320, height: 568), CGSize(width: 375, height: 667), CGSize(width: 414, height: 736),
        CGSize(width: 375, height: 812), CGSize(width: 414, height: 896), CGSize(width: 390, height: 844),
        CGSize(width: 428, height: 926), CGSize(width: 393, height: 852), CGSize(width: 430, height: 932),
        CGSize(width: 402, height: 874), CGSize(width: 420, height: 912), CGSize(width: 440, height: 956)
    ]

    private var windows: [UIWindow] = []
    private var language: String?

    override func setUp() async throws {
        try await super.setUp()
        language = LocalizationManager.shared.selectedLocalization
        LocalizationManager.shared.selectedLocalization = "en"
    }

    override func tearDown() async throws {
        windows.forEach { $0.isHidden = true; $0.rootViewController = nil }
        windows = []
        WalletDisplay.canvasOverride = nil
        if let language { LocalizationManager.shared.selectedLocalization = language }
        try await super.tearDown()
    }

    // MARK: The canvas

    func testEveryClassicIPhoneKeepsThePhoneCanvas() {
        for size in Self.classicPhones {
            let canvas = LayoutCanvas(size: size)
            XCTAssertEqual(canvas.kind, .phone, "\(size)")
            XCTAssertFalse(canvas.isTwoPage)
            XCTAssertNil(canvas.pages(in: CGRect(origin: .zero, size: size)))
            XCTAssertEqual(LayoutCanvas.readableInset(forWidth: size.width), 0)
            XCTAssertEqual(canvas.codeSide(columnWidth: size.width - 64), size.width - 64,
                           "a code is as wide as its column on a phone")
        }
    }

    func testTheFoldingScreensGetTheirOwnCanvases() throws {
        let cover = LayoutCanvas(size: Self.cover)
        XCTAssertEqual(cover.kind, .squat)
        XCTAssertFalse(cover.isTwoPage)
        XCTAssertEqual(LayoutCanvas.readableInset(forWidth: 466), 0)
        XCTAssertEqual(cover.codeSide(columnWidth: 402), 339)

        let turned = LayoutCanvas(size: Self.innerPortrait)
        XCTAssertEqual(turned.kind, .wide)
        XCTAssertFalse(turned.isTwoPage, "turned upright the inner screen is one tall page")
        XCTAssertEqual(LayoutCanvas.readableInset(forWidth: 669), 54)
        XCTAssertEqual(turned.codeSide(columnWidth: 497), 475)

        let open = LayoutCanvas(size: Self.innerLandscape)
        XCTAssertEqual(open.kind, .wide)
        XCTAssertTrue(open.isTwoPage)
        XCTAssertEqual(LayoutCanvas.readableInset(forWidth: 951), 195)
        XCTAssertEqual(open.codeSide(columnWidth: 497), 334)

        let bounds = CGRect(origin: .zero, size: Self.innerLandscape)
        let pages = try XCTUnwrap(open.pages(in: bounds))
        XCTAssertEqual(pages.left, CGRect(x: 0, y: 0, width: 475.5, height: 669))
        XCTAssertEqual(pages.right, CGRect(x: 475.5, y: 0, width: 475.5, height: 669))

        // The strip the system reserves for the fold keeps both pages clear of it.
        let fold = CGRect(x: 465.5, y: 0, width: 20, height: 669)
        let parted = try XCTUnwrap(open.pages(in: bounds, division: fold))
        XCTAssertEqual(parted.left.maxX, 465.5)
        XCTAssertEqual(parted.right.minX, 485.5)
        XCTAssertEqual(parted.right.maxX, 951)

        // A strip that runs across, or sits at an edge, does not split the window into these pages.
        let across = try XCTUnwrap(open.pages(in: bounds, division: CGRect(x: 0, y: 324, width: 951, height: 20)))
        XCTAssertEqual(across.left.maxX, 475.5)
        let edge = try XCTUnwrap(open.pages(in: bounds, division: CGRect(x: 0, y: 0, width: 30, height: 669)))
        XCTAssertEqual(edge.right.minX, 475.5)
    }

    // MARK: Orientation

    func testPhoneScreensStayPortraitAndARoomyScreenFollowsTheDevice() {
        for size in Self.classicPhones + [Self.cover] {
            XCTAssertEqual(WalletDisplay.supportedOrientations(screenSize: size, idiom: .phone), .portrait, "\(size)")
        }
        // A screen reports its size the way it is held, so both are asked.
        XCTAssertEqual(WalletDisplay.supportedOrientations(screenSize: Self.innerLandscape, idiom: .phone), .all)
        XCTAssertEqual(WalletDisplay.supportedOrientations(screenSize: Self.innerPortrait, idiom: .phone), .all)
        XCTAssertEqual(WalletDisplay.supportedOrientations(screenSize: CGSize(width: 744, height: 1133), idiom: .pad), .all)
    }

    func testTheAppAnswersForTheScreenItIsOn() throws {
        let delegate = try XCTUnwrap(UIApplication.shared.delegate as? AppDelegate)
        let screen = UIApplication.shared.soraWindowScene?.screen ?? UIScreen.main
        let expected = WalletDisplay.supportedOrientations(screenSize: screen.bounds.size,
                                                           idiom: screen.traitCollection.userInterfaceIdiom)
        XCTAssertEqual(delegate.application(UIApplication.shared, supportedInterfaceOrientationsFor: nil), expected)
        if LayoutCanvas(size: screen.bounds.size).kind == .phone, screen.traitCollection.userInterfaceIdiom == .phone {
            XCTAssertEqual(expected, .portrait)
        }
    }

    // MARK: Moving between screens

    func testAMoveToAnotherScreenIsToldAndATurnIsNot() {
        final class Count { var value = 0 }
        let center = NotificationCenter()
        let tracker = WalletDisplay.ScreenTracker(center: center)
        let count = Count()
        let token = center.addObserver(forName: WalletDisplay.screenDidChangeNotification, object: nil, queue: nil) { _ in
            count.value += 1
        }
        defer { center.removeObserver(token) }

        XCTAssertFalse(tracker.update(screen: nil, size: Self.cover), "where the scene starts is not a move")
        XCTAssertFalse(tracker.update(screen: nil, size: Self.cover))
        XCTAssertEqual(count.value, 0)
        XCTAssertTrue(tracker.update(screen: nil, size: Self.innerLandscape), "unfolded")
        XCTAssertEqual(count.value, 1)
        XCTAssertFalse(tracker.update(screen: nil, size: Self.innerPortrait), "turned on the same screen")
        XCTAssertEqual(count.value, 1)
        XCTAssertTrue(tracker.update(screen: nil, size: Self.cover), "folded")
        XCTAssertEqual(count.value, 2)
        // Another screen of the same kind of room is still another screen.
        XCTAssertTrue(tracker.update(screen: UIScreen.main, size: Self.cover))
        XCTAssertEqual(count.value, 3)

        tracker.hingeDidCross(closed: false, wasClosed: true)
        XCTAssertEqual(count.value, 4, "opened")
        tracker.hingeDidCross(closed: false, wasClosed: false)
        XCTAssertEqual(count.value, 4, "half open to open stays on the inner screen")
        tracker.hingeDidCross(closed: true, wasClosed: false)
        XCTAssertEqual(count.value, 5, "closed")
    }

    func testRevealedSecretsAreCoveredWhenTheSceneChangesScreens() throws {
        let backup = AccountCreateViewController()
        backup.localizationManager = LocalizationManager.shared
        backup.mode = .view
        backup.presenter = ClassicBackupPresenter()
        backup.loadViewIfNeeded()
        backup.set(mnemonic: ClassicPhoneLayoutTests.words)
        let reveal = try XCTUnwrap(descendants(of: backup.view)
            .first { $0.accessibilityIdentifier == "wallet-backup-reveal" } as? UIButton)
        func shownWords() -> [String] {
            descendants(of: backup.view).compactMap { ($0 as? UILabel)?.text }
                .filter { ClassicPhoneLayoutTests.words.contains($0) }
        }
        reveal.sendActions(for: .touchUpInside)
        XCTAssertEqual(shownWords().count, 12)
        NotificationCenter.default.post(name: WalletDisplay.screenDidChangeNotification, object: nil)
        XCTAssertTrue(shownWords().isEmpty, "words shown on one screen are not carried onto the other")
        reveal.sendActions(for: .touchUpInside)
        XCTAssertEqual(shownWords().count, 12, "the owner can show them again there")

        let seed = AccountExportRawSeedViewController()
        seed.presenter = ClassicRawSeedPresenter()
        seed.loadViewIfNeeded()
        seed.set(rawSeed: "0xPUBLIC_SYNTHETIC_PREVIEW", derivationPath: "//public")
        let value = try XCTUnwrap(descendants(of: seed.view)
            .first { $0.accessibilityIdentifier == "wallet-raw-seed-value" } as? UILabel)
        let show = try XCTUnwrap(descendants(of: seed.view)
            .first { $0.accessibilityIdentifier == "wallet-raw-seed-reveal" } as? UIButton)
        show.sendActions(for: .touchUpInside)
        XCTAssertEqual(value.text, "0xPUBLIC_SYNTHETIC_PREVIEW")
        NotificationCenter.default.post(name: WalletDisplay.screenDidChangeNotification, object: nil)
        XCTAssertNil(value.text)
    }

    // MARK: Touch ID and Face ID

    func testEachSensorHasItsOwnNameAndGlyph() throws {
        XCTAssertEqual(AvailableBiometryType.touchId.productName, "Touch ID")
        XCTAssertEqual(AvailableBiometryType.faceId.productName, "Face ID")
        XCTAssertNil(AvailableBiometryType.none.productName)
        XCTAssertEqual(AvailableBiometryType.touchId.unlockLabel(preferredLanguages: ["en"]), "Touch ID")
        XCTAssertEqual(AvailableBiometryType.faceId.unlockLabel(preferredLanguages: ["en"]), "Face ID")

        let fingerprint = try XCTUnwrap(R.image.pin.touch())
        let keypadFace = try XCTUnwrap(R.image.wallet.faceId())
        let settingsFace = try XCTUnwrap(R.image.profile.biometry())
        XCTAssertTrue(same(AvailableBiometryType.touchId.keypadGlyph, fingerprint))
        XCTAssertTrue(same(AvailableBiometryType.touchId.settingsGlyph, fingerprint))
        XCTAssertTrue(same(AvailableBiometryType.faceId.keypadGlyph, keypadFace))
        XCTAssertTrue(same(AvailableBiometryType.faceId.settingsGlyph, settingsFace))
        XCTAssertFalse(same(fingerprint, keypadFace))
        XCTAssertFalse(same(fingerprint, settingsFace))
    }

    func testTheUnlockKeyShowsAFingerprintWhereTheSensorIsTouchID() throws {
        let touch = pin(biometry: true, sensor: .touchId)
        touch.loadViewIfNeeded()
        let touchKey = touch.numpadView.accessoryButton
        XCTAssertEqual(touchKey.alpha, 1)
        XCTAssertEqual(touchKey.accessibilityLabel, "Touch ID")
        XCTAssertTrue(same(touchKey.sora.leftImage, try XCTUnwrap(R.image.pin.touch())))

        let face = pin(biometry: true, sensor: .faceId)
        face.loadViewIfNeeded()
        let faceKey = face.numpadView.accessoryButton
        XCTAssertEqual(faceKey.accessibilityLabel, "Face ID")
        XCTAssertTrue(same(faceKey.sora.leftImage, try XCTUnwrap(R.image.wallet.faceId())))
    }

    func testTheLoginSettingShowsAFingerprintWhereTheSensorIsTouchID() throws {
        func glyph(_ sensor: AvailableBiometryType) throws -> UIImage {
            let environment = ProfileLoginEnvironment(
                settings: InMemorySettingsManager(), presentingController: { nil },
                authenticate: { _ in throw NSError(domain: "wallet.display.tests", code: 1) },
                makeEditor: { _ in nil }, biometryType: { sensor })
            let presenter = ProfileLoginPresenter(environment: environment)
            presenter.localizationManager = LocalizationManager(localization: "en")
            let view = ProfileLoginView()
            presenter.view = view
            view.presenter = presenter
            view.loadViewIfNeeded()
            let table = try XCTUnwrap(descendants(of: view.view).compactMap { $0 as? SoramitsuTableView }.first)
            let card = try XCTUnwrap(table.sora.sections.first?.rows.first as? AppSettingsCardItem)
            XCTAssertEqual(card.menuItems.count, 2)
            return try XCTUnwrap(card.menuItems[1].picture?.image)
        }
        XCTAssertTrue(same(try glyph(.touchId), try XCTUnwrap(R.image.pin.touch())))
        XCTAssertTrue(same(try glyph(.faceId), try XCTUnwrap(R.image.profile.biometry())))
    }

    func testAChangedSensorIsNamedInItsQuestion() throws {
        let host = pin(biometry: false, sensor: .touchId)
        show(host, Self.cover, Self.coverInsets)
        let touch = host.askToKeepChangedBiometry(type: .touchId) { _ in }
        XCTAssertEqual(touch.title, WalletUX.format("%@ changed on this iPhone", "Touch ID"))
        XCTAssertEqual(touch.actions.compactMap(\.title), [WalletUX.format("Keep %@", "Touch ID"),
                                                           WalletUX.format("Turn %@ off", "Touch ID")])
        XCTAssertFalse(touch.message?.contains("Face ID") ?? true)
    }

    // MARK: The PIN screen

    func testThePinPadFitsTheFoldedCover() throws {
        let controller = pin(biometry: true, sensor: .touchId)
        let window = show(controller, Self.cover, Self.coverInsets)
        let safe = window.bounds.inset(by: Self.coverInsets)
        XCTAssertFalse(controller.isPaged)
        let keypad = frame(controller.numpadView, in: window)
        XCTAssertEqual(keypad.height, 368)
        XCTAssertEqual(keypad.midX, 233, accuracy: 0.5)
        for key in controller.numpadView.buttons + [controller.numpadView.backspaceButton,
                                                    controller.numpadView.accessoryButton] {
            let place = frame(key, in: window)
            XCTAssertTrue(safe.contains(place), "\(place) is off the cover screen")
            XCTAssertGreaterThanOrEqual(place.width, 44)
        }
        let parts = try pinParts(controller, in: window)
        XCTAssertGreaterThanOrEqual(parts.title.minY, safe.minY)
        XCTAssertGreaterThanOrEqual(parts.dots.minY, parts.title.maxY)
        XCTAssertLessThanOrEqual(parts.dots.maxY, keypad.minY, "the dots stay clear of the keys")
        XCTAssertTrue(controller.emblemView.isHidden, "no room for the ring above the title on the cover")
    }

    func testThePinPadTakesTwoPagesOnTheOpenScreen() throws {
        let controller = pin(biometry: false, sensor: .touchId)
        let window = show(controller, Self.innerLandscape, Self.innerInsets)
        // The safe area the screen really has: the test host's own status bar is added to the inner screen's.
        let safe = safeFrame(controller, in: window)
        let middle = window.bounds.midX
        XCTAssertTrue(controller.isPaged)

        let keypad = frame(controller.numpadView, in: window)
        XCTAssertEqual(keypad.height, 368)
        XCTAssertTrue(safe.contains(keypad))
        XCTAssertGreaterThanOrEqual(keypad.minX, middle, "the keys are on the right page, off the fold")
        XCTAssertEqual(keypad.midX, middle * 1.5, accuracy: 0.5)
        XCTAssertEqual(keypad.midY, safe.midY, accuracy: 0.5)

        let parts = try pinParts(controller, in: window)
        XCTAssertLessThanOrEqual(parts.title.maxX, middle)
        XCTAssertLessThanOrEqual(parts.dots.maxX, middle)
        XCTAssertEqual(parts.dots.midX, middle * 0.5, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(parts.dots.minY, parts.title.maxY)
        XCTAssertTrue(safe.contains(parts.dots))

        let emblem = frame(controller.emblemView, in: window)
        XCTAssertFalse(controller.emblemView.isHidden, "the open screen has room for the lock ring")
        XCTAssertEqual(emblem.midX, middle * 0.5, accuracy: 0.5)
        XCTAssertLessThanOrEqual(emblem.maxX, middle)
        XCTAssertLessThanOrEqual(emblem.maxY, parts.title.minY)
        XCTAssertGreaterThanOrEqual(emblem.minY, safe.minY)
    }

    func testThePinPadIsOneTallPageWhenTheOpenScreenIsTurned() throws {
        let controller = pin(biometry: false, sensor: .touchId)
        let window = show(controller, Self.innerPortrait, Self.innerInsets)
        let safe = window.bounds.inset(by: Self.innerInsets)
        XCTAssertFalse(controller.isPaged)
        let keypad = frame(controller.numpadView, in: window)
        XCTAssertEqual(keypad.midX, window.bounds.midX, accuracy: 0.5)
        XCTAssertEqual(keypad.maxY, safe.maxY - 18, accuracy: 0.5)
        let parts = try pinParts(controller, in: window)
        XCTAssertLessThanOrEqual(parts.dots.maxY, keypad.minY)
        let emblem = frame(controller.emblemView, in: window)
        XCTAssertFalse(controller.emblemView.isHidden)
        XCTAssertLessThanOrEqual(emblem.maxY, parts.title.minY)
    }

    func testFoldingAndUnfoldingKeepsTheDigitsEntered() throws {
        let controller = pin(biometry: true, sensor: .touchId)
        let window = show(controller, Self.cover, Self.coverInsets)
        func entered() -> Int { descendants(of: controller.view).compactMap { $0 as? PincodeDotView }.filter(\.isFilled).count }
        func title() throws -> String? { try pinTitle(controller).text }
        func places() throws -> [CGRect] {
            let parts = try pinParts(controller, in: window)
            return [parts.title, parts.dots, frame(controller.numpadView, in: window)]
                + (controller.numpadView.buttons + [controller.numpadView.backspaceButton,
                                                    controller.numpadView.accessoryButton]).map { frame($0, in: window) }
        }
        let closedPlaces = try places()
        let closedTitle = try title()
        XCTAssertEqual(entered(), 2)

        resize(window, Self.innerLandscape, Self.innerInsets)
        XCTAssertTrue(controller.isPaged)
        XCTAssertEqual(entered(), 2, "unfolding mid-entry keeps the digits")
        XCTAssertEqual(try title(), closedTitle)
        XCTAssertEqual(controller.numpadView.accessoryButton.alpha, 1)

        resize(window, Self.innerPortrait, Self.innerInsets)
        XCTAssertFalse(controller.isPaged)
        XCTAssertEqual(entered(), 2)

        resize(window, Self.cover, Self.coverInsets)
        XCTAssertFalse(controller.isPaged)
        XCTAssertEqual(entered(), 2, "folding mid-entry keeps the digits")
        XCTAssertEqual(try places(), closedPlaces,
                       "the cover layout comes back exactly after a trip to the inner screen")
        XCTAssertTrue(controller.emblemView.isHidden)
    }

    func testThePlanetLandsWhereThePinScreenShowsIt() throws {
        // Classic phones: where it always landed.
        let tall = SacredEmblemLayout.pinPlacement(bounds: CGRect(x: 0, y: 0, width: 402, height: 874),
                                                   safeArea: UIEdgeInsets(top: 62, left: 0, bottom: 34, right: 0))
        XCTAssertEqual(tall, SacredEmblemLayout.Placement(centre: CGPoint(x: 201, y: 152), ringRadius: 66))
        XCTAssertNil(SacredEmblemLayout.pinPlacement(bounds: CGRect(x: 0, y: 0, width: 375, height: 667),
                                                     safeArea: UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)))
        // The cover is too short for the ring above the title, like an iPhone SE.
        XCTAssertNil(SacredEmblemLayout.pinPlacement(bounds: CGRect(origin: .zero, size: Self.cover),
                                                     safeArea: Self.coverInsets))
        // Two pages: on the left one, in the middle of the group it makes with the title and the dots.
        let open = try XCTUnwrap(SacredEmblemLayout.pinPlacement(bounds: CGRect(origin: .zero, size: Self.innerLandscape),
                                                                 safeArea: Self.innerInsets))
        XCTAssertEqual(open.centre.x, 237.75)
        XCTAssertEqual(open.ringRadius, 66)
        XCTAssertEqual(open.centre.y, 291.5)
        XCTAssertLessThan(open.frame.maxX, 475.5)

        let controller = pin(biometry: false, sensor: .touchId)
        let window = show(controller, Self.innerLandscape, Self.innerInsets)
        // Asked with the safe area the screen really has (the test host adds its own status bar).
        let landing = try XCTUnwrap(SacredEmblemLayout.pinPlacement(bounds: window.bounds,
                                                                    safeArea: controller.view.safeAreaInsets))
        XCTAssertEqual(frame(controller.emblemView, in: window), landing.frame,
                       "the flight lands the planet exactly where this screen's ring stands")
    }

    func testTheLaunchFlightFollowsAWindowResizedUnderIt() throws {
        let traced = SacredTenmonView.isEnabled
        let effects = FxPolicy.reduceEffects
        SacredTenmonView.isEnabled = false
        FxPolicy.reduceEffects = false
        defer { SacredTenmonView.isEnabled = traced; FxPolicy.reduceEffects = effects }

        let splash = SplashViewController()
        let window = show(splash, Self.cover, Self.coverInsets)
        if splash.flight == nil {
            splash.beginAppearanceTransition(true, animated: false)
            splash.endAppearanceTransition()
        }
        let flight = try XCTUnwrap(splash.flight as? SacredGateView)
        XCTAssertEqual(flight.frame, window.bounds)
        // At rest in front of the inner gate, as while the wallet is still getting ready.
        flight.rest()
        XCTAssertEqual(flight.phase, .holding)
        let closed = try XCTUnwrap(flight.placement)
        XCTAssertEqual(closed.centre.x, 233, accuracy: 0.5)

        resize(window, Self.innerLandscape, Self.innerInsets)
        XCTAssertEqual(flight.frame, window.bounds, "the scene fills the screen it has moved to")
        XCTAssertEqual(flight.phase, .holding, "and stays where it was in the flight")
        let open = try XCTUnwrap(flight.placement)
        XCTAssertEqual(open, SacredEmblemLayout.pinPlacement(bounds: flight.bounds, safeArea: flight.safeAreaInsets))
        XCTAssertLessThan(open.frame.maxX, window.bounds.midX)

        resize(window, Self.cover, Self.coverInsets)
        XCTAssertEqual(flight.frame, window.bounds)
        XCTAssertEqual(try XCTUnwrap(flight.placement).centre.x, 233, accuracy: 0.5)
    }

    // MARK: Lists and cards

    func testRowsKeepToTheReadableWidthOnAWideWindow() throws {
        let controller = ClassicTableController(rows: [receiveRow()])
        let window = show(controller, Self.innerPortrait, Self.innerInsets)
        var cell = try XCTUnwrap(controller.tableView.visibleCells.first)
        XCTAssertEqual(cell.frame.minX, 54)
        XCTAssertEqual(cell.frame.width, 561)
        XCTAssertEqual(controller.tableView.readableRowWidth, 561)

        resize(window, Self.innerLandscape, Self.innerInsets)
        cell = try XCTUnwrap(controller.tableView.visibleCells.first)
        XCTAssertEqual(cell.frame.minX, 195)
        XCTAssertEqual(cell.frame.width, 561)

        resize(window, Self.cover, Self.coverInsets)
        cell = try XCTUnwrap(controller.tableView.visibleCells.first)
        XCTAssertEqual(cell.frame.minX, 0)
        XCTAssertEqual(cell.frame.width, 466, "on the cover a row is the width of the screen, like a phone")
    }

    func testTheReceiveCodeLeavesTheAddressAndShareInView() throws {
        // The cover: short for its width.
        var controller = ClassicTableController(rows: [receiveRow()])
        var window = show(controller, Self.cover, Self.coverInsets)
        var cell = try XCTUnwrap(controller.tableView.visibleCells.first)
        var card = try codeCard(in: cell)
        XCTAssertEqual(card.frame.height, 339)
        XCTAssertEqual(card.frame.width, 402)
        // Below the navigation bar (44) the whole card, the address and Share are on screen at once.
        XCTAssertLessThanOrEqual(cell.frame.height, window.bounds.inset(by: Self.coverInsets).height - 44)

        // The open screen turned upright: a bigger code than any phone shows, in a readable column.
        controller = ClassicTableController(rows: [receiveRow()])
        window = show(controller, Self.innerPortrait, Self.innerInsets)
        cell = try XCTUnwrap(controller.tableView.visibleCells.first)
        card = try codeCard(in: cell)
        XCTAssertEqual(card.frame.width, 497)
        XCTAssertEqual(card.frame.height, 475)
        XCTAssertGreaterThan(card.frame.height, 440 - 64, "larger than on the largest phone")

        // The open screen the natural way up: short again, so the code gives way to the rest.
        // Nothing reloads the table: a row is measured again when the window is resized under it.
        resize(window, Self.innerLandscape, Self.innerInsets)
        cell = try XCTUnwrap(controller.tableView.visibleCells.first)
        card = try codeCard(in: cell)
        XCTAssertEqual(card.frame.height, 334)
        XCTAssertLessThanOrEqual(cell.frame.height, window.bounds.inset(by: Self.innerInsets).height - 44)
    }

    func testTheHeroPaintsEdgeToEdgeAndKeepsItsCardInLineWithTheCardsBelow() throws {
        let home = makeHome()
        let controller = ClassicTableController(rows: home.items)
        let window = show(controller, Self.innerPortrait, Self.innerInsets)
        home.viewWillAppear()
        settle(window)
        defer { home.viewDidDisappear() }

        let hero = try XCTUnwrap(controller.tableView.visibleCells.first { $0 is PortfolioHeroCell })
        XCTAssertEqual(hero.frame.minX, 0)
        XCTAssertEqual(hero.frame.width, 669, "the sky runs from edge to edge")
        // Constraint arithmetic leaves 70.00000000000001; edges are compared on the half point.
        let sides = hero.contentView.subviews.map { ($0.frame.minX * 2).rounded() / 2 }.sorted()
        XCTAssertEqual(sides, [0, 70, 70], "the sky is full width; the wallet button and the card are readable")
        let widest = hero.contentView.subviews.map { $0.frame.maxX }.sorted()
        XCTAssertEqual(widest.last, 669)
        XCTAssertTrue(hero.contentView.subviews.contains { $0.frame.minX == 70 && $0.frame.maxX == 599 })

        let list = try XCTUnwrap(controller.tableView.visibleCells.first { !($0 is PortfolioHeroCell) })
        XCTAssertEqual(list.frame.minX, 54)
        XCTAssertEqual(list.frame.width, 561)

        // On the cover everything is 16 from the sides, as on a phone.
        resize(window, Self.cover, Self.coverInsets)
        let closed = try XCTUnwrap(controller.tableView.visibleCells.first { $0 is PortfolioHeroCell })
        XCTAssertEqual(closed.contentView.subviews.map { $0.frame.minX }.sorted(), [0, 16, 16])
    }

    func testTwoPagesKeepTheHeroBesideTheCards() {
        let home = makeHome()
        let friends = FriendsItem()
        let all: [SoramitsuTableViewItemProtocol] = home.items + [friends]

        let one = WalletHomePages.split(all, twoPage: false)
        XCTAssertEqual(one.first.count, all.count)
        XCTAssertTrue(one.second.isEmpty)

        let two = WalletHomePages.split(all, twoPage: true)
        XCTAssertEqual(two.first.count, 1)
        XCTAssertTrue(two.first[0] === home.heroItem)
        XCTAssertEqual(two.second.count, 3)
        XCTAssertTrue(two.second[0] === home.listItem)
        XCTAssertTrue(two.second[1] === home.otherNetworksItem)
        XCTAssertTrue(two.second[2] === friends)

        // The warning that the selected account cannot sign stays under the hero.
        home.noticeItem.setCapability(.missingKeys)
        let warned = WalletHomePages.split(home.items + [friends], twoPage: true)
        XCTAssertEqual(warned.first.count, 2)
        XCTAssertTrue(warned.first[1] === home.noticeItem)
        XCTAssertTrue(warned.second[0] === home.listItem)

        // The classic home has no hero: one page, whatever the window.
        let classic = WalletHomePages.split([friends], twoPage: true)
        XCTAssertEqual(classic.first.count, 1)
        XCTAssertTrue(classic.second.isEmpty)
    }

    // MARK: Secrets and forms

    func testThePhraseTakesThreeColumnsOnlyOnAWideWindow() {
        for size in Self.classicPhones + [Self.cover] {
            XCTAssertEqual(AccountCreateViewController.phraseColumns(canvas: LayoutCanvas(size: size), accessibilitySize: false), 2)
        }
        for size in [Self.innerLandscape, Self.innerPortrait] {
            let canvas = LayoutCanvas(size: size)
            XCTAssertEqual(AccountCreateViewController.phraseColumns(canvas: canvas, accessibilitySize: false), 3)
            XCTAssertEqual(AccountCreateViewController.phraseColumns(canvas: canvas, accessibilitySize: true), 1)
        }
    }

    func testThePhraseScreenIsAReadableColumnOnTheOpenScreen() throws {
        let controller = AccountCreateViewController()
        controller.localizationManager = LocalizationManager.shared
        controller.mode = .view
        controller.presenter = ClassicBackupPresenter()
        controller.loadViewIfNeeded()
        controller.set(mnemonic: ClassicPhoneLayoutTests.words)
        let window = show(controller, Self.innerLandscape, Self.innerInsets)
        let reveal = try XCTUnwrap(descendants(of: controller.view)
            .first { $0.accessibilityIdentifier == "wallet-backup-reveal" } as? UIButton)
        let card = try XCTUnwrap(reveal.superview)
        XCTAssertEqual(frame(card, in: window).width, 560)
        XCTAssertEqual(frame(card, in: window).midX, window.bounds.midX, accuracy: 0.5)

        reveal.sendActions(for: .touchUpInside)
        settle(window)
        let words = try XCTUnwrap(descendants(of: controller.view)
            .first { $0.accessibilityIdentifier == "wallet-backup-words" })
        XCTAssertFalse(words.isHidden)
        let columns = words.subviews.filter { $0.frame.width > 0 && $0.frame.height > 0 }
        XCTAssertEqual(columns.count, 3, "twelve words in three columns of four")
        XCTAssertEqual(descendants(of: words).compactMap { ($0 as? UILabel)?.text }
            .filter { ClassicPhoneLayoutTests.words.contains($0) }.count, 12)

        // Folded: 16 from each side, like a phone.
        resize(window, Self.cover, Self.coverInsets)
        XCTAssertEqual(frame(card, in: window).minX, 16)
        XCTAssertEqual(frame(card, in: window).width, 434)
    }

    func testTheScanWindowFitsTheFoldingScreens() {
        XCTAssertEqual(ScanQRViewController.scanWindowSide(viewSize: Self.cover, bottomInset: 34), 322)
        XCTAssertEqual(ScanQRViewController.scanWindowSide(viewSize: Self.innerLandscape, bottomInset: 20), 341)
        XCTAssertEqual(ScanQRViewController.scanWindowSide(viewSize: Self.innerPortrait, bottomInset: 20), 392)
    }

    // MARK: Helpers

    private func pin(biometry: Bool, sensor: AvailableBiometryType) -> PincodeViewController {
        let controller = PincodeViewController()
        controller.mode = .securedInput
        controller.biometryType = { sensor }
        controller.presenter = ClassicPinPresenter(view: controller, biometry: biometry)
        return controller
    }

    private func makeHome() -> PortfolioHome {
        let defaults = UserDefaults(suiteName: "wallet.display.tests")!
        defaults.removePersistentDomain(forName: "wallet.display.tests")
        return PortfolioHome(dataSource: PortfolioFakeSource(PortfolioFixtures.snapshot()),
                             preferences: PortfolioPreferences(defaults: defaults))
    }

    private func receiveRow() -> ReceiveItem {
        let row = ReceiveItem(name: "Fixture", address: "cnVkoGs3rEMqLqY27c2nfVXJRGdzNJk2ns78DcqtppaSRe8qm",
                    qrImage: ClassicPhoneLayoutTests.square(.black))
        row.shareHandler = {}
        row.accountTapHandler = {}
        return row
    }

    /// The white card the code is in: the superview of the image view that shows it.
    private func codeCard(in cell: UIView) throws -> UIView {
        let image = try XCTUnwrap(descendants(of: cell).compactMap { $0 as? UIImageView }
            .first { $0.image?.size == CGSize(width: 64, height: 64) })
        XCTAssertEqual(image.bounds.height, image.bounds.width, accuracy: 0.5)
        return try XCTUnwrap(image.superview)
    }

    private func pinTitle(_ controller: PincodeViewController) throws -> UILabel {
        let dots = try XCTUnwrap(descendants(of: controller.view)
            .first { $0.accessibilityIdentifier == "InputFieldAccessibilityId" })
        return try XCTUnwrap(dots.superview?.subviews.compactMap { $0 as? UILabel }.first)
    }

    private func pinParts(_ controller: PincodeViewController, in window: UIWindow) throws -> (title: CGRect, dots: CGRect) {
        let dots = try XCTUnwrap(descendants(of: controller.view)
            .first { $0.accessibilityIdentifier == "InputFieldAccessibilityId" })
        return (frame(try pinTitle(controller), in: window), frame(dots, in: window))
    }

    @discardableResult
    private func show(_ controller: UIViewController, _ size: CGSize, _ insets: UIEdgeInsets) -> UIWindow {
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        controller.additionalSafeAreaInsets = insets
        window.rootViewController = controller
        window.isHidden = false
        windows.append(window)
        settle(window)
        return window
    }

    private func resize(_ window: UIWindow, _ size: CGSize, _ insets: UIEdgeInsets) {
        window.rootViewController?.additionalSafeAreaInsets = insets
        window.frame = CGRect(origin: .zero, size: size)
        settle(window)
    }

    private func settle(_ window: UIWindow) {
        for _ in 0..<3 {
            window.setNeedsLayout()
            window.layoutIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        window.layoutIfNeeded()
    }

    private func frame(_ view: UIView, in window: UIWindow) -> CGRect {
        view.convert(view.bounds, to: window)
    }

    private func safeFrame(_ controller: UIViewController, in window: UIWindow) -> CGRect {
        controller.view.convert(controller.view.safeAreaLayoutGuide.layoutFrame, to: window)
    }

    private func descendants(of view: UIView) -> [UIView] {
        ClassicPhoneLayoutTests.descendants(of: view)
    }

    private func same(_ image: UIImage?, _ other: UIImage) -> Bool {
        guard let image else { return false }
        return image === other || image.pngData() == other.pngData()
    }
}
