// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

@testable import SoraPassport
import CryptoKit
import SoraFoundation
import SoraUIKit
import UIKit
import XCTest

/// The layouts every iPhone had before the folding-screen work, pinned frame by frame.
///
/// Each screen is laid out in a window of an iPhone 17 (402 × 874) and of an iPhone SE (375 × 667), and
/// the frame of every view in it is hashed. The hashes below were recorded on the commit before the
/// folding-screen work (2a350001) with this same file, so a change that moves anything on a classic
/// iPhone fails here. The home and the PIN were recorded again with the white-and-red materials: the
/// home's quick actions are pads (52 high where the domes' wells were 62) and its balance sheet has a
/// backdrop under it; the PIN stands on a page of its own and its places hold 12-point beads.
/// A failing test writes the frames it saw next to the hash, to compare by hand.
@MainActor
final class ClassicPhoneLayoutTests: XCTestCase {
    struct Phone {
        let name: String
        let size: CGSize
        let insets: UIEdgeInsets
    }

    static let phones = [
        Phone(name: "402x874", size: CGSize(width: 402, height: 874),
              insets: UIEdgeInsets(top: 62, left: 0, bottom: 34, right: 0)),
        Phone(name: "375x667", size: CGSize(width: 375, height: 667),
              insets: UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0))
    ]

    /// Recorded on 2a350001 (iOS 26.5 simulator, English); home and PIN with the white-and-red materials.
    static let recorded: [String: String] = [
        "home-375x667": "e0b80376a54920e67f32af8ae8df8c90aa219f78ae00c1ca1cfd4bc74cb252c3",
        "home-402x874": "9ccf9bfd5ab95c38ae1fcb5a62e3fdc776b3e3f92e09b3d538db920cceae5d23",
        "launch-375x667": "5ce85bf0039f243875f9b51c7597a3477d7278bc22f02a9383e230c2879a515c",
        "launch-402x874": "2ba0bfaed8d6755af6022315f30b8f1315e0b2583881b1e2d4b93063f42641fe",
        "phrase-hidden-375x667": "3de8be60c4111cda629dcfec347e922c5639403192af832bca38f8fc16b7cc11",
        "phrase-hidden-402x874": "1217647642becd60265769b645746a3161e23327b0a57b16f20cb55644734e5f",
        "phrase-shown-375x667": "b3177ab7dd972eccc5b519f5824977ccf889cab7708693fa1c5c83ea004f06dc",
        "phrase-shown-402x874": "2bd7552abf697e45b584543f4cc095a04fa1651c63905eb5406b902963276cc1",
        "pin-entry-375x667": "84cc4bf050efaabd62c462c0840ae7809e5352a996f4c4eb4914e5348fa69d7e",
        "pin-entry-402x874": "860169971f1584365427b7a30117dfcfc1b1d5fdb20e864f78154ed87675a848",
        "pin-unlock-key-375x667": "84cc4bf050efaabd62c462c0840ae7809e5352a996f4c4eb4914e5348fa69d7e",
        "pin-unlock-key-402x874": "860169971f1584365427b7a30117dfcfc1b1d5fdb20e864f78154ed87675a848",
        "raw-seed-375x667": "04f4955a810689eda431c3c02ea6e63c82ebfbc7d43090683748b5eafa45c1ee",
        "raw-seed-402x874": "c98494898e551525f0c6d35ab24808b8f0fffce80a53132d8464f65123c2fa14",
        "receive-375x667": "011401fb570d936b0243407b42c36da0ea1b282c90703eaa83f64bed51d72125",
        "receive-402x874": "7b2295abe95832ec17c73f550712b4cc31ea27b2265cd446255b9628edccb9aa"
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
        if let language { LocalizationManager.shared.selectedLocalization = language }
        try await super.tearDown()
    }

    // MARK: Screens

    func testPinEntryKeepsItsFrames() {
        for phone in Self.phones {
            let controller = PincodeViewController()
            controller.mode = .securedInput
            controller.presenter = ClassicPinPresenter(view: controller, biometry: false)
            check("pin-entry", phone, controller)
        }
    }

    func testPinEntryWithTheUnlockKeyKeepsItsFrames() {
        for phone in Self.phones {
            let controller = PincodeViewController()
            controller.mode = .securedInput
            controller.presenter = ClassicPinPresenter(view: controller, biometry: true)
            check("pin-unlock-key", phone, controller)
        }
    }

    func testRecoveryPhraseKeepsItsFrames() throws {
        for phone in Self.phones {
            let controller = AccountCreateViewController()
            controller.localizationManager = LocalizationManager.shared
            controller.mode = .view
            controller.presenter = ClassicBackupPresenter()
            controller.loadViewIfNeeded()
            controller.set(mnemonic: Self.words)
            controller.set(backupDerivationPath: "//public-preview")
            let window = show(controller, phone)
            let reveal = try XCTUnwrap(Self.descendants(of: controller.view)
                .first { $0.accessibilityIdentifier == "wallet-backup-reveal" } as? UIButton)
            compare("phrase-hidden", phone, window)
            reveal.sendActions(for: .touchUpInside)
            window.layoutIfNeeded()
            // The words are on screen only while the app is active; the frames are the point here.
            compare("phrase-shown", phone, window)
        }
    }

    func testRawSeedKeepsItsFrames() {
        for phone in Self.phones {
            let controller = AccountExportRawSeedViewController()
            controller.presenter = ClassicRawSeedPresenter()
            controller.loadViewIfNeeded()
            controller.set(rawSeed: "0xPUBLIC_SYNTHETIC_PREVIEW", derivationPath: "//public")
            check("raw-seed", phone, controller)
        }
    }

    func testReceiveCardKeepsItsFrames() {
        for phone in Self.phones {
            let controller = ClassicTableController(rows: [
                ReceiveItem(name: "Fixture", address: "cnVkoGs3rEMqLqY27c2nfVXJRGdzNJk2ns78DcqtppaSRe8qm",
                            qrImage: Self.square(.black))
            ])
            check("receive", phone, controller)
        }
    }

    // The home's capture host is only in debug test builds, like the capture tests that own it.
    #if DEBUG
    func testWalletHomeKeepsItsFrames() {
        for phone in Self.phones {
            let defaults = UserDefaults(suiteName: "classic.phone.layout")!
            defaults.removePersistentDomain(forName: "classic.phone.layout")
            let home = PortfolioHome(dataSource: PortfolioFakeSource(PortfolioFixtures.snapshot()),
                                     preferences: PortfolioPreferences(defaults: defaults))
            let controller = PortfolioCaptureHomeController(home: home, variant: .full)
            let window = show(controller, phone)
            home.viewWillAppear()
            settle(window)
            compare("home", phone, window)
            home.viewDidDisappear()
        }
    }
    #endif

    func testLaunchScreenKeepsItsFrames() {
        // The line-figure flight: one view, laid out at once, whatever the GPU is doing.
        let traced = SacredTenmonView.isEnabled
        SacredTenmonView.isEnabled = false
        defer { SacredTenmonView.isEnabled = traced }
        for phone in Self.phones {
            check("launch", phone, SplashViewController())
        }
    }

    // MARK: Recording and comparing

    private func check(_ name: String, _ phone: Phone, _ controller: UIViewController) {
        let window = show(controller, phone)
        compare(name, phone, window)
    }

    private func show(_ controller: UIViewController, _ phone: Phone) -> UIWindow {
        let window = UIWindow(frame: CGRect(origin: .zero, size: phone.size))
        controller.additionalSafeAreaInsets = phone.insets
        window.rootViewController = controller
        window.isHidden = false
        windows.append(window)
        settle(window)
        return window
    }

    private func settle(_ window: UIWindow) {
        for _ in 0..<3 {
            window.setNeedsLayout()
            window.layoutIfNeeded()
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        window.layoutIfNeeded()
    }

    private func compare(_ name: String, _ phone: Phone, _ window: UIWindow,
                         file: StaticString = #filePath, line: UInt = #line) {
        let key = "\(name)-\(phone.name)"
        let frames = Self.frames(in: window)
        let hash = SHA256.hash(data: Data(frames.utf8)).map { String(format: "%02x", $0) }.joined()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("classic-layout-\(key).txt")
        try? frames.write(to: url, atomically: true, encoding: .utf8)
        print("CLASSIC-LAYOUT \(key) \(hash) \(url.path)")
        guard let expected = Self.recorded[key] else {
            XCTFail("No recorded layout for \(key): \(hash)", file: file, line: line)
            return
        }
        XCTAssertEqual(hash, expected, "\(key) moved on a classic iPhone; frames seen: \(url.path)",
                       file: file, line: line)
    }

    /// One line per view: its place in the tree, its class, its frame in the window, and whether it shows.
    static func frames(in window: UIWindow) -> String {
        var lines: [String] = []
        func walk(_ view: UIView, _ path: String) {
            let frame = view.convert(view.bounds, to: window)
            func half(_ value: CGFloat) -> String { String(format: "%.1f", (value * 2).rounded() / 2) }
            let name = String(describing: type(of: view))
            lines.append("\(path) \(name) \(half(frame.minX)) \(half(frame.minY)) \(half(frame.width)) \(half(frame.height))"
                + (view.isHidden ? " hidden" : "") + (view.accessibilityIdentifier.map { " #\($0)" } ?? ""))
            // What UIKit builds inside its own controls is its business and changes with the system.
            guard !(view is UILabel), !(view is UIImageView), !(view is UISwitch), !(view is UITextField),
                  !(view is UIActivityIndicatorView), !(view is UIVisualEffectView) else { return }
            for (index, child) in view.subviews.enumerated() {
                walk(child, path + "." + String(index))
            }
        }
        walk(window, "0")
        return lines.joined(separator: "\n")
    }

    static func descendants(of view: UIView) -> [UIView] {
        view.subviews.flatMap { [$0] + descendants(of: $0) }
    }

    static let words = ["public", "synthetic", "preview", "words", "never", "used", "for", "any",
                        "real", "wallet", "at", "all"]

    static func square(_ color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64)).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        }
    }
}

// MARK: - Fixtures

/// A PIN screen with six dots, two of them entered.
final class ClassicPinPresenter: PinSetupPresenterProtocol {
    weak var view: PincodeViewController?
    let biometry: Bool

    init(view: PincodeViewController, biometry: Bool) {
        self.view = view
        self.biometry = biometry
    }

    func start() {
        view?.updatePinCodeSymbolsCount(with: 6)
        view?.didChangeAccessoryState(enabled: biometry)
        view?.updateInputedCircles(with: 2)
        view?.setupDeleteButton(isHidden: false)
    }

    func cancel() {}
    func activateBiometricAuth() {}
    func submit(pin: String) {}
    func deleteButtonTapped() {}
    func padButtonTapped(with symbol: String) {}
    func updatePinButtonTapped() {}
}

final class ClassicBackupPresenter: AccountCreatePresenterProtocol {
    func setup() {}
    func activateInfo() {}
    func proceed() {}
    func share() {}
    func restoredApp() {}
    func skip() {}
    func backupToGoogle() {}
}

final class ClassicRawSeedPresenter: AccountExportRawSeedPresenterProtocol {
    func exportRawSeed() {}
    func copyRawSeed() {}
    func exportJSON() {}
}

/// A screen that is one table, pinned the way the wallet's table screens pin theirs.
final class ClassicTableController: SoramitsuViewController {
    let tableView = SoramitsuTableView()
    private let rows: [SoramitsuTableViewItemProtocol]

    init(rows: [SoramitsuTableViewItemProtocol]) {
        self.rows = rows
        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.sora.estimatedRowHeight = UITableView.automaticDimension
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        tableView.sora.sections = [SoramitsuTableViewSection(rows: rows)]
    }
}
