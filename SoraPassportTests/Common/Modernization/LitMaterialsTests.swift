// SPDX-License-Identifier: Apache-2.0
import SoraUIKit
import UIKit
import XCTest
@testable import SoraPassport

/// The lit materials: which surfaces get a plate, that their baked images exist and stay readable, that the
/// ray-traced hero builds its shader, and the motion that must keep the numbers true.
@MainActor
final class LitMaterialsTests: XCTestCase {
    private func plates(in view: UIView) -> [LitPlateLayer] {
        view.layer.sublayers?.compactMap { $0 as? LitPlateLayer } ?? []
    }

    // MARK: Which surfaces stand on a plate

    func testRoundedUnclippedSurfaceStandsOnAPlateInsteadOfAShadow() throws {
        let card = SoramitsuView()
        card.sora.backgroundColor = .bgSurface
        card.sora.cornerRadius = .max
        card.sora.clipsToBounds = false
        card.sora.shadow = .default
        card.bounds = CGRect(x: 0, y: 0, width: 300, height: 200)
        let plate = try XCTUnwrap(plates(in: card).first)
        XCTAssertTrue(card.layer.sublayers?.first === plate, "behind all the card's content")
        XCTAssertEqual(plate.frame, card.bounds)
        XCTAssertEqual(plate.cornerRadiusValue, 32)
        XCTAssertEqual(card.layer.shadowOpacity, 0, "the plate's own shadows replace the classic one")
    }

    func testPlatesFollowTheSurfaceSize() throws {
        let card = SoramitsuView()
        card.sora.backgroundColor = .bgSurface
        card.sora.cornerRadius = .max
        card.sora.clipsToBounds = false
        card.bounds = CGRect(x: 0, y: 0, width: 300, height: 200)
        card.bounds = CGRect(x: 0, y: 0, width: 200, height: 40)
        let plate = try XCTUnwrap(plates(in: card).first)
        XCTAssertEqual(plate.frame.size, CGSize(width: 200, height: 40))
        XCTAssertEqual(plate.cornerRadiusValue, 20, "never rounder than a capsule")
        XCTAssertEqual(plate.elevation, 9, "small things stand lower")
    }

    func testOtherViewsStayFlat() {
        let clipped = SoramitsuView()
        clipped.sora.backgroundColor = .bgSurface
        clipped.sora.cornerRadius = .max
        clipped.bounds = CGRect(x: 0, y: 0, width: 300, height: 200)
        XCTAssertTrue(plates(in: clipped).isEmpty, "a clipped view could not show the plate's shadows")

        let solid = SoramitsuView()
        solid.sora.material = .solid
        solid.sora.backgroundColor = .bgSurface
        solid.sora.cornerRadius = .max
        solid.sora.clipsToBounds = false
        solid.bounds = CGRect(x: 0, y: 0, width: 300, height: 200)
        XCTAssertTrue(plates(in: solid).isEmpty)

        let coloured = SoramitsuView()
        coloured.sora.backgroundColor = .accentPrimary
        coloured.sora.cornerRadius = .max
        coloured.sora.clipsToBounds = false
        coloured.bounds = CGRect(x: 0, y: 0, width: 300, height: 200)
        XCTAssertTrue(plates(in: coloured).isEmpty)

        let square = SoramitsuView()
        square.sora.backgroundColor = .bgSurface
        square.sora.clipsToBounds = false
        square.bounds = CGRect(x: 0, y: 0, width: 300, height: 200)
        XCTAssertTrue(plates(in: square).isEmpty)
    }

    func testAPlateIsRemovedWhenTheSurfaceStopsBeingOne() {
        let card = SoramitsuView()
        card.sora.backgroundColor = .bgSurface
        card.sora.cornerRadius = .max
        card.sora.clipsToBounds = false
        card.bounds = CGRect(x: 0, y: 0, width: 300, height: 200)
        XCTAssertEqual(plates(in: card).count, 1)
        card.sora.backgroundColor = .accentPrimary
        XCTAssertTrue(plates(in: card).isEmpty)
    }

    func testGlassViewIsAPlateInItsShape() {
        let capsule = GlassView()
        capsule.shape = .capsule
        capsule.bounds = CGRect(x: 0, y: 0, width: 160, height: 44)
        capsule.layoutIfNeeded()
        XCTAssertEqual(capsule.plate.frame, capsule.bounds)
        XCTAssertEqual(capsule.plate.cornerRadiusValue, 22)
        XCTAssertEqual(capsule.plate.elevation, 8)

        let card = GlassView()
        card.shape = .rounded(24)
        card.bounds = CGRect(x: 0, y: 0, width: 300, height: 200)
        card.layoutIfNeeded()
        XCTAssertEqual(card.plate.cornerRadiusValue, 24)
        XCTAssertEqual(card.plate.elevation, 16)

        card.elevation = 18
        card.layoutIfNeeded()
        XCTAssertEqual(card.plate.elevation, 18)
    }

    // MARK: Buttons

    func testFilledButtonsAreLacquerAndSurfaceButtonsArePlates() throws {
        let filled = SoramitsuButton()
        filled.widthAnchor.constraint(equalToConstant: 200).isActive = true
        filled.layoutIfNeeded()
        XCTAssertGreaterThan(filled.layer.shadowOpacity, 0, "its own colour on the plate below it")
        XCTAssertFalse(filled.layer.masksToBounds)
        XCTAssertTrue(plates(in: filled).isEmpty)
        XCTAssertEqual(filled.layer.shadowColor, SoramitsuThemeType.light.palette.color(.accentPrimary).cgColor)

        let key = SoramitsuButton()
        key.sora.backgroundColor = .bgSurface
        key.sora.cornerRadius = .circle
        key.widthAnchor.constraint(equalToConstant: 200).isActive = true
        key.layoutIfNeeded()
        let plate = try XCTUnwrap(plates(in: key).first, "a surface-coloured button, like a PIN key, stands on a plate")
        XCTAssertEqual(plate.cornerRadiusValue, 28, "a capsule of the button's own height")
        XCTAssertEqual(key.layer.shadowOpacity, 0)

        let text = SoramitsuButton(size: .small, type: .text(.primary))
        text.widthAnchor.constraint(equalToConstant: 80).isActive = true
        text.layoutIfNeeded()
        XCTAssertTrue(plates(in: text).isEmpty)
        XCTAssertEqual(text.layer.shadowOpacity, 0)
    }

    func testADisabledFilledButtonLosesItsLacquer() {
        let button = SoramitsuButton()
        button.widthAnchor.constraint(equalToConstant: 200).isActive = true
        button.layoutIfNeeded()
        XCTAssertGreaterThan(button.layer.shadowOpacity, 0)
        button.sora.isEnabled = false
        button.layoutIfNeeded()
        XCTAssertEqual(button.layer.shadowOpacity, 0)
    }

    // MARK: Baked images

    func testWellsPlatesAndDomesHaveTheirImages() {
        let well = LitWellLayer()
        well.cornerRadiusValue = 18
        XCTAssertNotNil(well.contents)
        well.place(in: CGRect(x: 10, y: 10, width: 100, height: 36))
        XCTAssertGreaterThan(well.frame.width, 100, "its lip extends just outside")

        let tinted = LitWellLayer()
        tinted.floorColor = UIColor(litHex: 0xDDE7DF)
        XCTAssertNotNil(tinted.contents)

        let dome = LitCabochonView(lit: .red, deep: .black, domeDiameter: 50, wellDiameter: 62)
        XCTAssertEqual(dome.intrinsicContentSize, CGSize(width: 62, height: 62))
        dome.setPressed(true)
        XCTAssertEqual(dome.glyphView.alpha, 0.9, accuracy: 0.01)
        dome.setPressed(false)

        let led = LitLEDView(diameter: 8)
        led.setColor(.green)
        led.pulse(true)
        led.pulse(false)

        let coin = LitCoinImageView(diameter: 40)
        XCTAssertEqual(coin.imageView.layer.cornerRadius, 20)
    }

    func testPressedWellsAndEngravedLinesLayOut() {
        let line = LitEngravedLine(frame: CGRect(x: 0, y: 0, width: 100, height: 2))
        line.layoutIfNeeded()
        XCTAssertEqual(line.layer.sublayers?.count, 2)
        XCTAssertEqual(line.intrinsicContentSize.height, 2)

        let page = LitPageView(frame: CGRect(x: 0, y: 0, width: 300, height: 600))
        page.layoutIfNeeded()
        XCTAssertEqual(page.backgroundColor, Lit.page)
    }

    // MARK: Text stays readable on the new surfaces

    func testTextContrastOnPorcelain() {
        for background in [Lit.page, Lit.plateLit, Lit.plateDeep, Lit.surface] {
            XCTAssertGreaterThanOrEqual(WalletUX.contrast(Lit.ink, background), 7)
            XCTAssertGreaterThanOrEqual(WalletUX.contrast(Lit.inkSecondary, background), 4.5)
            XCTAssertGreaterThanOrEqual(WalletUX.contrast(Lit.inkTertiary, background), 3)
        }
        XCTAssertGreaterThanOrEqual(WalletUX.contrast(Lit.inkSecondary, Lit.wellFloor), 4.5)
        XCTAssertGreaterThanOrEqual(WalletUX.contrast(NeonTokens.lit.success, Lit.wellFloor), 3)
    }

    func testTheAppDrawsWithTheLitTokens() {
        XCTAssertEqual(NeonTokens.current.canvas, Lit.page)
        XCTAssertEqual(SoramitsuThemeType.light.palette.color(.bgPage), Lit.page)
        XCTAssertEqual(SoramitsuThemeType.light.palette.color(.bgSurface), Lit.surface)
        XCTAssertEqual(SoramitsuThemeType.light.palette.color(.fgSecondary), Lit.inkSecondary)
    }

    // MARK: The hero

    func testHeroShaderBuildsAndDrawsItsStates() throws {
        let built = expectation(description: "the shader built off the main thread")
        LitHeroView.preload { built.fulfill() }
        wait(for: [built], timeout: 60)
        let hero = LitHeroView(frame: CGRect(x: 0, y: 0, width: 390, height: 280))
        try XCTSkipUnless(hero.isAvailable, "no Metal device on this host")
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.isHidden = false
        defer { window.isHidden = true }
        window.addSubview(hero)
        hero.planetCenter = CGPoint(x: 195, y: 170)
        hero.setSegments([LitHeroView.Segment(start: 0, sweep: 3, color: .red),
                          LitHeroView.Segment(start: 3.1, sweep: 3, color: .blue, strength: 0.26, widthScale: 1.35, lift: 1)],
                         ringStart: 0)
        hero.isCometRunning = true
        hero.runReveal(duration: 0.1)
        hero.flare()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        hero.isCometRunning = false
        hero.setSegments([], ringStart: 0)
        hero.setNeedsFrame()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertEqual(hero.reveal, 1)
    }

    func testAHeroMadeBeforeTheShaderIsBuiltDrawsItsRingOnceItIs() throws {
        // No wait for the shader here: whichever comes first, the ring still draws in to the end.
        let hero = LitHeroView(frame: CGRect(x: 0, y: 0, width: 390, height: 280))
        try XCTSkipUnless(hero.isAvailable, "no Metal device on this host")
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.isHidden = false
        defer { window.isHidden = true }
        window.addSubview(hero)
        hero.setSegments([LitHeroView.Segment(start: 0, sweep: 6, color: .red)], ringStart: 0)
        hero.runReveal(duration: 0.1)
        let finished = expectation(for: NSPredicate { _, _ in hero.reveal == 1 }, evaluatedWith: nil)
        wait(for: [finished], timeout: 60)
    }

    func testRingGeometryMatchesTheHitTestPlane() {
        // The ray-traced band and the tap test must agree: a point on the band's centre line on screen
        // is on the band in the plane the shader intersects.
        let pose = PortfolioRingPose.at(center: CGPoint(x: 195, y: 170), x: 0.3, y: -0.2)
        for degrees in stride(from: CGFloat(0), to: 360, by: 30) {
            let onScreen = pose.point(degrees)
            let inPlane = pose.toPlane(onScreen)
            XCTAssertEqual((inPlane.x * inPlane.x + inPlane.y * inPlane.y).squareRoot(), pose.radius, accuracy: 0.001)
        }
    }

    // MARK: Moving light

    func testTheLightMovesPlatesAndComesBackToRest() {
        let plate = LitPlateLayer()
        plate.elevation = 16
        plate.frame = CGRect(x: 0, y: 0, width: 300, height: 200)
        plate.layoutSublayers()
        let shadow = try? XCTUnwrap(plate.sublayers?.first)
        let rest = shadow?.frame.origin
        LitLightRig.shared.set(x: 1, y: 0)
        XCTAssertNotEqual(shadow?.frame.origin, rest)
        LitLightRig.shared.set(x: 0, y: 0)
        XCTAssertEqual(shadow?.frame.origin, rest)
    }

    // MARK: A number that rolls still ends on the true value

    func testRollEndsOnTheNewTextAndWithoutItsOverlay() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.isHidden = false
        defer { window.isHidden = true }
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 300, height: 60))
        window.addSubview(label)
        let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 40).litTabularDigits]
        label.attributedText = NSAttributedString(string: "$21,426", attributes: attributes)
        let next = NSAttributedString(string: "$21,431", attributes: attributes)
        LitRoller.setText(next, on: label, animated: true)
        XCTAssertEqual(label.attributedText?.string, "$21,431", "accessibility and tests read the new value at once")
        RunLoop.main.run(until: Date().addingTimeInterval(1.2))
        XCTAssertEqual(label.attributedText, next)
        XCTAssertTrue(label.subviews.isEmpty)
    }

    func testRollFallsBackToACrossfadeWhenTheLengthChanges() {
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 300, height: 60))
        label.attributedText = NSAttributedString(string: "$999")
        let next = NSAttributedString(string: "$1,000")
        LitRoller.setText(next, on: label, animated: true)
        XCTAssertEqual(label.attributedText, next)
        XCTAssertTrue(label.subviews.isEmpty)
    }

    func testNotAnimatedMeansAtOnce() {
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 300, height: 60))
        label.attributedText = NSAttributedString(string: "$100")
        let next = NSAttributedString(string: "$200")
        LitRoller.setText(next, on: label, animated: false)
        XCTAssertEqual(label.attributedText, next)
    }

    // MARK: Tab bar

    func testTheSelectionWellSlidesToTheSelectedTab() throws {
        let cover = ClassicTabBarCover(frame: CGRect(x: 0, y: 0, width: 390, height: 83))
        let items = (0 ..< 5).map { UITabBarItem(title: "Tab \($0)", image: UIImage(systemName: "circle.fill"), tag: $0) }
        cover.update(items: items, selectedIndex: 0)
        cover.layoutIfNeeded()
        let well = try XCTUnwrap(cover.layer.sublayers?.first { $0 is LitWellLayer })
        let first = well.position
        XCTAssertEqual(first.x, cover.itemControls[0].frame.midX, accuracy: 0.5)
        cover.update(items: items, selectedIndex: 3)
        cover.layoutIfNeeded()
        XCTAssertEqual(well.position.x, cover.itemControls[3].frame.midX, accuracy: 0.5)
    }

    // MARK: Swap

    /// Polkaswap is the only swap the wallet has, so Swap wears its flower, never a generic glyph.
    func testSwapActionsWearTheFlower() throws {
        let swap = PortfolioQuickActionView(action: .swap)
        XCTAssertEqual(swap.accessibilityLabel, PortfolioStrings.swap)
        let cell = TransferableCell(style: .default, reuseIdentifier: nil)
        let button = try XCTUnwrap(descendants(cell).compactMap { $0 as? AssetActionView }
            .first { $0.accessibilityIdentifier == "assetDetails.swap" }).button
        XCTAssertNotNil(button.sora.leftImage)
        XCTAssertEqual(button.sora.leftImage?.renderingMode, .alwaysOriginal)
        XCTAssertEqual(button.sora.leftImage?.pngData(), R.image.wallet.polkaswap()?.withRenderingMode(.alwaysOriginal).pngData())
    }

    private func descendants(_ view: UIView) -> [UIView] {
        view.subviews + view.subviews.flatMap(descendants)
    }
}
