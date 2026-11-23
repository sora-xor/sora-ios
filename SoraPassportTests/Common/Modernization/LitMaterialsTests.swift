// SPDX-License-Identifier: Apache-2.0
@testable import SoraUIKit
import UIKit
import XCTest
@testable import SoraPassport

/// The materials: which surfaces are glass or pads, that their baked images exist and stay readable, that the
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
        XCTAssertEqual(plate.cornerRadiusValue, 18)
        XCTAssertEqual(card.layer.shadowOpacity, 0, "the sheet's own shadows replace the classic one")
        XCTAssertFalse(card.motionEffects.isEmpty, "a sheet floats nearer the eye: it moves when the phone tilts")
    }

    func testPlatesFollowTheSurfaceSize() throws {
        let card = SoramitsuView()
        card.sora.backgroundColor = .bgSurface
        card.sora.cornerRadius = .max
        card.sora.clipsToBounds = false
        card.bounds = CGRect(x: 0, y: 0, width: 300, height: 200)
        card.bounds = CGRect(x: 0, y: 0, width: 200, height: 30)
        let plate = try XCTUnwrap(plates(in: card).first)
        XCTAssertEqual(plate.frame.size, CGSize(width: 200, height: 30))
        XCTAssertEqual(plate.cornerRadiusValue, 15, "never rounder than a capsule")
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
        XCTAssertEqual(card.plate.cornerRadiusValue, Lit.sheetRadius, "a sheet of glass keeps small corners")
        XCTAssertEqual(card.plate.elevation, 16)
        XCTAssertFalse(card.plate.isOverBackdrop)
        card.blursBackdrop = true
        XCTAssertTrue(card.plate.isOverBackdrop, "glass over something live thins its milk")
        XCTAssertTrue(card.subviews.contains { $0 is UIVisualEffectView })
        card.blursBackdrop = false
        XCTAssertFalse(card.subviews.contains { $0 is UIVisualEffectView })

        card.elevation = 18
        card.layoutIfNeeded()
        XCTAssertEqual(card.plate.elevation, 18)
    }

    // MARK: Buttons

    func testFilledButtonsAreCutGlassAndSurfaceButtonsArePads() throws {
        let filled = SoramitsuButton()
        filled.widthAnchor.constraint(equalToConstant: 200).isActive = true
        filled.layoutIfNeeded()
        XCTAssertFalse(filled.layer.masksToBounds)
        XCTAssertTrue(plates(in: filled).isEmpty)
        let glass = try XCTUnwrap(filled.layer.sublayers?.first, "the cut glass is the button's face, under its content")
        XCTAssertNotNil(glass.contents)
        XCTAssertGreaterThan(glass.frame.width, filled.bounds.width, "its shadow and the light it throws lie round it")
        XCTAssertEqual(filled.backgroundColor, .clear, "no flat fill showing round the cut edge")
        XCTAssertEqual(filled.layer.cornerRadius, Lit.controlRadius)

        let key = SoramitsuButton()
        key.sora.backgroundColor = .bgSurface
        key.sora.cornerRadius = .circle
        key.widthAnchor.constraint(equalToConstant: 200).isActive = true
        key.layoutIfNeeded()
        let plate = try XCTUnwrap(plates(in: key).first, "a surface-coloured button, like a PIN key, is a soft raised pad")
        XCTAssertEqual(plate.cornerRadiusValue, 28, "a capsule of the button's own height")
        XCTAssertEqual(key.layer.shadowOpacity, 0)

        let text = SoramitsuButton(size: .small, type: .text(.primary))
        text.widthAnchor.constraint(equalToConstant: 80).isActive = true
        text.layoutIfNeeded()
        XCTAssertTrue(plates(in: text).isEmpty)
        XCTAssertEqual(text.layer.shadowOpacity, 0)
    }

    func testADisabledFilledButtonLosesItsGlass() {
        let button = SoramitsuButton()
        button.widthAnchor.constraint(equalToConstant: 200).isActive = true
        button.layoutIfNeeded()
        XCTAssertNotNil(button.layer.sublayers?.first?.contents)
        button.sora.isEnabled = false
        button.layoutIfNeeded()
        XCTAssertNil(button.layer.sublayers?.first?.contents)
    }

    // MARK: Baked images

    func testWellsGlassAndMarksHaveTheirImages() {
        let well = LitWellLayer()
        well.cornerRadiusValue = 18
        XCTAssertNotNil(well.contents)
        well.place(in: CGRect(x: 10, y: 10, width: 100, height: 36))
        XCTAssertEqual(well.frame, CGRect(x: 10, y: 10, width: 100, height: 36), "let into the surface: nothing outside its shape")
        let plain = well.contents as AnyObject
        well.isRuled = true
        XCTAssertFalse(plain === (well.contents as AnyObject), "a well that takes input has a boundary of its own")

        let tinted = LitWellLayer()
        tinted.floorColor = UIColor(litHex: 0xDDE7DF)
        XCTAssertNotNil(tinted.contents)

        let disc = LitCutGlassView(size: CGSize(width: 56, height: 56), cornerRadius: 28)
        XCTAssertEqual(disc.intrinsicContentSize, CGSize(width: 56, height: 56))
        disc.setGlyph(UIImage(systemName: "circle.fill"), key: "test")
        disc.layoutIfNeeded()
        let rest = disc.layer.sublayers?.first?.position
        disc.setPressed(true)
        XCTAssertEqual(disc.layer.sublayers?.first?.position.y ?? 0, (rest?.y ?? 0) + 1, accuracy: 0.01, "set down a point")
        disc.setPressed(false)
        XCTAssertEqual(disc.layer.sublayers?.first?.position, rest)

        let dot = LitDotView(diameter: 8)
        dot.setColor(.green)
        dot.pulse(true)
        dot.pulse(false)

        let bead = LitBeadView(diameter: 12)
        XCTAssertEqual(bead.intrinsicContentSize, CGSize(width: 12, height: 12))
        bead.drop()

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
        XCTAssertNotNil(page.backgroundColor, "washi")
        XCTAssertGreaterThanOrEqual(page.layer.sublayers?.count ?? 0, 3, "the mica print, the light's falloff and its moving pool")
    }

    // MARK: Text stays readable on the new surfaces

    func testTextContrastOnWhite() {
        for background in [Lit.page, Lit.padLit, Lit.padShade, Lit.surface] {
            XCTAssertGreaterThanOrEqual(WalletUX.contrast(Lit.ink, background), 7)
            XCTAssertGreaterThanOrEqual(WalletUX.contrast(Lit.inkSecondary, background), 4.5)
            XCTAssertGreaterThanOrEqual(WalletUX.contrast(Lit.inkTertiary, background), 3)
        }
        XCTAssertGreaterThanOrEqual(WalletUX.contrast(Lit.inkSecondary, Lit.wellFloor), 4.5)
        XCTAssertGreaterThanOrEqual(WalletUX.contrast(NeonTokens.lit.success, Lit.wellFloor), 3)
        // Red as ink on every white, and white type on the red.
        for background in [Lit.page, Lit.padShade, Lit.surface, Lit.wellFloor] {
            XCTAssertGreaterThanOrEqual(WalletUX.contrast(Lit.lacquerText, background), 4.5)
        }
        XCTAssertGreaterThanOrEqual(WalletUX.contrast(Lit.inlay, Lit.lacquerRed), 4.5)
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
        LitLightRig.shared.set(x: 0, y: 0)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.isHidden = false
        defer { window.isHidden = true }
        let plate = LitPlateLayer()
        plate.elevation = 16
        plate.frame = CGRect(x: 0, y: 0, width: 300, height: 200)
        window.layer.addSublayer(plate)
        plate.layoutSublayers()
        let shadow = try? XCTUnwrap(plate.sublayers?.first)
        let rest = shadow?.frame.origin
        LitLightRig.shared.set(x: 1, y: 0)
        XCTAssertNotEqual(shadow?.frame.origin, rest)
        LitLightRig.shared.set(x: 0, y: 0)
        XCTAssertEqual(shadow?.frame.origin, rest)
    }

    func testASheetOffScreenIsNotToldAboutTheLightAndTakesItWhenItIsLaidOut() {
        LitLightRig.shared.set(x: 0, y: 0)
        defer { LitLightRig.shared.set(x: 0, y: 0) }
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.isHidden = false
        defer { window.isHidden = true }
        let covered = UIView(frame: window.bounds)
        window.addSubview(covered)
        func sheet(in layer: CALayer?) -> (LitPlateLayer, CALayer?) {
            let plate = LitPlateLayer()
            plate.elevation = 16
            plate.frame = CGRect(x: 0, y: 0, width: 300, height: 200)
            layer?.addSublayer(plate)
            plate.layoutSublayers()
            return (plate, plate.sublayers?.first)
        }
        let shown = sheet(in: window.layer), hidden = sheet(in: covered.layer), nowhere = sheet(in: nil)
        let rest = shown.1?.frame.origin
        XCTAssertTrue(shown.0.isLitOnScreen)
        covered.isHidden = true
        XCTAssertFalse(hidden.0.isLitOnScreen, "under a hidden screen")
        XCTAssertFalse(nowhere.0.isLitOnScreen, "in no window")

        LitLightRig.shared.set(x: 1, y: 0)
        XCTAssertNotEqual(shown.1?.frame.origin, rest)
        XCTAssertEqual(hidden.1?.frame.origin, rest, "a covered sheet costs nothing while the light moves")
        XCTAssertEqual(nowhere.1?.frame.origin, rest)

        // Shown again and laid out, each takes the light as it stands.
        covered.isHidden = false
        hidden.0.layoutSublayers()
        nowhere.0.layoutSublayers()
        XCTAssertEqual(hidden.1?.frame.origin, shown.1?.frame.origin)
        XCTAssertEqual(nowhere.1?.frame.origin, shown.1?.frame.origin)
    }

    /// A hand holding the phone trembles by a fraction of a degree. That moved the old light on most
    /// frames, and every step redrew every surface on screen; it does not move the light now.
    func testAHandsTremorDoesNotMoveTheLight() {
        let sensor = StillPhone()
        let rig = LitLightRig(source: sensor)
        let surface = LightSteps()
        rig.add(surface)
        var time: TimeInterval = 10
        var before = 0
        var old = 0.0
        // Ten seconds at thirty samples a second: a third of a degree to and fro, nine times a second.
        for frame in 0..<300 {
            time += 1 / LitLightRig.movingRate
            let wobble = 0.006 * sin(2 * Double.pi * 9 * Double(frame) / LitLightRig.movingRate)
            rig.sensed(x: 0.10 + wobble, y: -0.70 + wobble * 0.7, time: time)
            if rig.isAnimating { rig.step() }
            // The light as it was eased before: every step of more than 0.003 was drawn.
            let next = old + (wobble * 3.4 - old) * 0.22
            if abs(next - old) > 0.003 {
                old = next
                before += 1
            }
        }
        print("LIGHT-TREMOR frames 300, redrawn before \(before), now \(surface.steps)")
        XCTAssertEqual(surface.steps, 0, "a tremor redraws nothing")
        XCTAssertFalse(rig.isAnimating, "and the frame loop has stopped")
        XCTAssertGreaterThan(before, 30, "the same trace kept the old light moving")
        rig.remove(surface)
    }

    /// A phone lying still runs no frame loop for the light; a tilt starts it again.
    func testTheLightRestsWhenThePhoneIsStillAndWakesOnATilt() async throws {
        let sensor = StillPhone()
        let rig = LitLightRig(source: sensor)
        let plate = LitPlateLayer()
        rig.add(plate)
        XCTAssertTrue(sensor.isRunning)
        XCTAssertTrue(rig.isAnimating)
        XCTAssertEqual(sensor.interval, 1 / LitLightRig.movingRate, accuracy: 0.0001)

        // Held still: the light does not move, and after a moment the frame loop stops.
        var time: TimeInterval = 100
        func hold(x: Double, y: Double, frames: Int) async {
            for _ in 0..<frames {
                time += 1 / LitLightRig.movingRate
                rig.sensed(x: x, y: y, time: time)
                // A wake is handed to the main thread: let it arrive.
                if !rig.isAnimating { try? await Task.sleep(nanoseconds: 1_000_000) }
                if rig.isAnimating { rig.step() }
            }
        }
        await hold(x: 0.10, y: -0.70, frames: LitLightRig.restAfter + 2)
        XCTAssertFalse(rig.isAnimating, "no frame loop on a still phone")
        XCTAssertEqual(rig.x, 0, accuracy: 0.001)
        XCTAssertEqual(sensor.interval, 1 / LitLightRig.restingRate, accuracy: 0.0001, "the sensor is read less often at rest")

        // Sensor noise on a table does not wake it.
        await hold(x: 0.1005, y: -0.7004, frames: 30)
        XCTAssertFalse(rig.isAnimating)

        // A tilt does, on the main thread, and the light follows it.
        time += 0.1
        rig.sensed(x: 0.30, y: -0.70, time: time)
        for _ in 0..<50 where !rig.isAnimating { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertTrue(rig.isAnimating, "a tilt starts the frame loop again")
        XCTAssertEqual(sensor.interval, 1 / LitLightRig.movingRate, accuracy: 0.0001)
        await hold(x: 0.30, y: -0.70, frames: 6)
        XCTAssertGreaterThan(rig.x, 0.2, "the light moved towards the tilt")

        // Held in the new posture, that posture becomes straight and the light comes back to rest.
        await hold(x: 0.30, y: -0.70, frames: Int(LitLightRig.movingRate * 30))
        // Within the dead band of straight: nearer than a tilt that would set it off again.
        XCTAssertLessThan(abs(rig.x), LitLightRig.startDistance + 2 * LitLightRig.settleStep)
        rig.remove(plate)
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
        XCTAssertEqual(button.sora.leftImage?.pngData(), PortfolioGlyphs.polkaswapMark?.pngData())
        XCTAssertNotEqual(button.sora.leftImage?.pngData(), R.image.wallet.polkaswap()?.pngData(), "the flower in the app's red, not its own pink")
    }

    private func descendants(_ view: UIView) -> [UIView] {
        view.subviews + view.subviews.flatMap(descendants)
    }
}

/// Counts the steps of the light it is told about.
private final class LightSteps: LitLightListener {
    var steps = 0
    func lightDidMove(x: CGFloat, y: CGFloat) { steps += 1 }
}

/// A tilt sensor fed by hand.
private final class StillPhone: LitTiltSource {
    var isAvailable: Bool { true }
    private(set) var isRunning = false
    private(set) var interval: TimeInterval = 0

    func start(interval: TimeInterval, handler: @escaping (Double, Double, TimeInterval) -> Void) {
        isRunning = true
        self.interval = interval
    }

    func setInterval(_ interval: TimeInterval) { self.interval = interval }

    func stop() { isRunning = false }
}
