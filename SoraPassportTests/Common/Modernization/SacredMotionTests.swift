// SPDX-License-Identifier: Apache-2.0
import SoraUIKit
import UIKit
import XCTest
@testable import SoraPassport

/// The figures and proportions the motion is built on, the launch flight's numbers, the PIN screen's
/// lock ring, the seal on a sent transaction, and that the traced launch scene builds and draws.
@MainActor
final class SacredMotionTests: XCTestCase {
    private func shapes(in layer: CALayer) -> [CAShapeLayer] {
        (layer.sublayers ?? []).flatMap { ([$0 as? CAShapeLayer].compactMap { $0 }) + shapes(in: $0) }
    }

    /// The nearest any straight stroke of a path comes to the origin.
    private func nearestStraightStroke(_ path: CGPath) -> CGFloat {
        var nearest = CGFloat.greatestFiniteMagnitude
        var current = CGPoint.zero
        var start = CGPoint.zero
        func measure(_ a: CGPoint, _ b: CGPoint) {
            let ab = CGPoint(x: b.x - a.x, y: b.y - a.y)
            let length = ab.x * ab.x + ab.y * ab.y
            let along = length > 0 ? min(1, max(0, -(a.x * ab.x + a.y * ab.y) / length)) : 0
            nearest = min(nearest, hypot(a.x + ab.x * along, a.y + ab.y * along))
        }
        path.applyWithBlock { pointer in
            let element = pointer.pointee
            switch element.type {
            case .moveToPoint:
                current = element.points[0]
                start = current
            case .addLineToPoint:
                measure(current, element.points[0])
                current = element.points[0]
            case .addQuadCurveToPoint:
                current = element.points[1]
            case .addCurveToPoint:
                current = element.points[2]
            case .closeSubpath:
                current = start
            @unknown default:
                break
            }
        }
        return nearest
    }

    // MARK: Figures and proportions

    func testBeatsStepByTheGoldenRatio() {
        XCTAssertEqual(SacredGeometry.beat(0), 0.110, accuracy: 0.0001)
        for step in 0..<5 {
            XCTAssertEqual(SacredGeometry.beat(step + 1) / SacredGeometry.beat(step), Double(SacredGeometry.phi), accuracy: 0.0001)
        }
        XCTAssertEqual(SacredGeometry.yamato * SacredGeometry.yamato, 2, accuracy: 0.0001)
    }

    func testTheSeedsSixCirclesStandOnAHexagonAndMeetInTheMiddle() {
        let centres = SacredGeometry.seedCentres(radius: 100)
        XCTAssertEqual(centres.count, 6)
        XCTAssertEqual(centres[0].x, 0, accuracy: 0.001)
        XCTAssertEqual(centres[0].y, -50, accuracy: 0.001, "the first stands at the top")
        XCTAssertGreaterThan(centres[1].x, 0, "and they go round clockwise")
        for (index, centre) in centres.enumerated() {
            XCTAssertEqual(hypot(centre.x, centre.y), 50, accuracy: 0.001)
            let next = centres[(index + 1) % 6]
            XCTAssertEqual(hypot(next.x - centre.x, next.y - centre.y), 50, accuracy: 0.001, "a hexagon's side")
            // Each circle is drawn from the middle, where the planet hides its start.
            let first = SacredGeometry.seedCircle(index, radius: 100).currentPoint
            XCTAssertEqual(hypot(first.x, first.y), 0, accuracy: 0.001)
        }
        XCTAssertEqual(SacredGeometry.shippoCentres(radius: 90).count, 19)
    }

    func testNoStraightStrokeComesNearTheMiddle() {
        // The red disc sits in the middle of every figure; lines leaving a red disc read as a flag.
        for figure in SacredGeometry.Figure.allCases {
            let path = SacredGeometry.path(for: figure, radius: 100)
            XCTAssertGreaterThan(nearestStraightStroke(path), 45, "\(figure)")
            XCTAssertLessThanOrEqual(path.boundingBoxOfPath.width, 213, "\(figure) stays in its circle")
        }
    }

    // MARK: The plain flight

    func testThePlainFlightStopsWhereItGoesOnFromAndSetsThePlanetDown() {
        let landing = CGPoint(x: 201, y: 152)
        let scene = SacredGateScene(size: CGSize(width: 402, height: 874), landing: landing, planetRadius: 32, ringRadius: 66)
        XCTAssertEqual(scene.pose(.intro, at: 1), scene.pose(.outro, at: 0), "no jump at the gate")
        XCTAssertEqual(scene.pose(.intro, at: 0).fade, 0, "it rises out of the plain launch page")
        let end = scene.frame(.outro, at: 1)
        XCTAssertEqual(end.planetCentre.x, landing.x, accuracy: 0.01)
        XCTAssertEqual(end.planetCentre.y, landing.y, accuracy: 0.01)
        XCTAssertEqual(end.planetRadius, 32, accuracy: 0.01)
        XCTAssertEqual(end.lock.opacity, 0.5, accuracy: 0.001, "the ring is there, as the PIN screen draws it")
        XCTAssertEqual(end.lock.path.boundingBoxOfPath.width, 132, accuracy: 0.5)
        XCTAssertTrue(end.gates.allSatisfy { $0.opacity == 0 }, "every gate is behind the lens")
        let waiting = scene.frame(.intro, at: 1)
        XCTAssertGreaterThan(waiting.gates[SacredGateScene.innerGate].opacity, 0.3, "the inner gate stands in front")
        XCTAssertTrue(waiting.gates.prefix(3).allSatisfy { $0.opacity == 0 }, "the gates it has passed are gone")
    }

    func testAGateIsGoneBeforeItReachesTheLensAndItsPointsStayFinite() {
        XCTAssertEqual(SacredGateScene.gateOpacity(depth: 0.6), 0)
        XCTAssertGreaterThan(SacredGateScene.gateOpacity(depth: 6), SacredGateScene.gateOpacity(depth: 60))
        let scene = SacredGateScene(size: CGSize(width: 375, height: 667), landing: CGPoint(x: 187, y: 200), planetRadius: 30, ringRadius: 62)
        for phase in [SacredGateScene.Phase.intro, .outro] {
            for step in 0...40 {
                let frame = scene.frame(phase, at: CGFloat(step) / 40)
                for stroke in frame.gates + [frame.lock] {
                    let box = stroke.path.boundingBoxOfPath
                    XCTAssertTrue(box.width.isFinite && box.height.isFinite && box.width < 100_000)
                    XCTAssertTrue((0...1).contains(stroke.opacity))
                }
            }
        }
    }

    // MARK: Where the emblem stands

    func testTheEmblemStandsAboveThePinTitleAndShortScreensGoWithout() throws {
        let tall = try XCTUnwrap(SacredEmblemLayout.pinPlacement(
            bounds: CGRect(x: 0, y: 0, width: 402, height: 874), safeArea: UIEdgeInsets(top: 62, left: 0, bottom: 34, right: 0)))
        XCTAssertEqual(tall.ringRadius, 66)
        XCTAssertEqual(tall.centre, CGPoint(x: 201, y: 152))
        XCTAssertEqual(tall.planetRadius, 66 / 2.05, accuracy: 0.001)
        XCTAssertLessThan(tall.frame.maxY, 246, "clear of a one-line title")
        XCTAssertNil(SacredEmblemLayout.pinPlacement(
            bounds: CGRect(x: 0, y: 0, width: 375, height: 667), safeArea: UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)),
            "the keypad and title leave no room on the shortest phones")
        let fallback = SacredEmblemLayout.fallback(
            bounds: CGRect(x: 0, y: 0, width: 375, height: 667), safeArea: UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0))
        XCTAssertEqual((fallback.centre.y - 20) / 647, 1 - 1 / SacredGeometry.phi, accuracy: 0.001, "on the golden section")
    }

    // MARK: The lock ring

    func testEachSixthOfTheCodeDrawsOneMoreCircleAndTheLastClosesTheRim() {
        let emblem = SacredEmblemView(frame: CGRect(x: 0, y: 0, width: 136, height: 136))
        emblem.layoutIfNeeded()
        XCTAssertEqual(emblem.ringRadius, 66)
        XCTAssertFalse(emblem.isAccessibilityElement, "the dots say how much is entered; this only shows it")
        let lit = shapes(in: emblem.layer).filter { $0.lineWidth == 1.6 }
        XCTAssertEqual(lit.count, 7, "six circles and the rim")
        func drawn() -> Int { lit.filter { $0.strokeEnd == 1 }.count }
        XCTAssertEqual(drawn(), 0)
        emblem.setShare(3.0 / 6, animated: false)
        XCTAssertEqual(drawn(), 3)
        emblem.setShare(2.0 / 4, animated: false)
        XCTAssertEqual(drawn(), 3, "half of a four-digit code is half the ring")
        emblem.setShare(1, animated: false)
        XCTAssertEqual(drawn(), 7)
        emblem.showError(color: .systemRed)
        XCTAssertTrue(lit.allSatisfy { $0.strokeColor == UIColor.systemRed.cgColor && $0.strokeEnd == 1 })
        emblem.setShare(0, animated: false)
        XCTAssertEqual(drawn(), 0)
        XCTAssertTrue(lit.allSatisfy { $0.strokeColor == SacredInk.gold.cgColor }, "the next try starts clean")
        XCTAssertNotNil(emblem.planetView.image)
    }

    // MARK: The seal

    func testTheSealIsOpenInFlightClosedAndFlatWhenSettledAndStaysOpenWhenBroken() throws {
        let seal = SacredSealView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        seal.layoutIfNeeded()
        let layers = shapes(in: seal.layer)
        XCTAssertEqual(layers.count, 4)
        let ring = layers[1], square = layers[2], mark = layers[3]
        XCTAssertEqual(seal.state, .working)
        XCTAssertEqual(ring.strokeEnd, 0.82, accuracy: 0.001, "the circle of heaven is open")
        XCTAssertNil(square.fillColor)
        XCTAssertFalse(CATransform3DIsIdentity(square.transform), "the square of earth stands on its corner")
        XCTAssertNil(mark.path)

        seal.setState(.settled, animated: false)
        XCTAssertEqual(ring.strokeEnd, 1)
        XCTAssertTrue(CATransform3DIsIdentity(square.transform), "it has come down flat")
        XCTAssertEqual(square.fillColor, seal.settledColor.cgColor)
        XCTAssertNotNil(mark.path)

        seal.setState(.broken, animated: false)
        XCTAssertEqual(ring.strokeEnd, 0.82, accuracy: 0.001)
        XCTAssertEqual(ring.strokeColor, seal.brokenColor.cgColor)
        XCTAssertNil(square.fillColor)
    }

    // MARK: The traced scene

    func testTheCameraWaitsWhereTheWayThroughBeginsAndDayBreaksOnlyAtTheEnd() {
        let scene = SacredTenmonScene(size: SIMD2(603, 1311), pixelsPerPoint: 1.5, landing: SIMD2(301.5, 228),
                                      landingRadius: 48, page: SIMD3(0.91, 0.886, 0.87), keepsPlanet: true)
        let waiting = scene.uniforms(.intro, progress: 1, clock: 1, turn: 0)
        let leaving = scene.uniforms(.outro, progress: 0, clock: 1, turn: 0)
        XCTAssertEqual(waiting.flight, leaving.flight)
        XCTAssertEqual(waiting.lens, leaving.lens)
        XCTAssertEqual(waiting.flight.x, SacredTenmonScene.holdZ)
        XCTAssertEqual(scene.uniforms(.intro, progress: 0, clock: 0, turn: 0).state.x, 0, "it rises out of the dark")
        XCTAssertEqual(waiting.state.x, 1)

        let end = scene.uniforms(.outro, progress: 1, clock: 2, turn: 0)
        XCTAssertEqual(end.flight.x, scene.endZ, accuracy: 0.001)
        XCTAssertEqual(end.lens.x, 301.5, accuracy: 0.001)
        XCTAssertEqual(end.lens.y, 228, accuracy: 0.001)
        // The planet's radius on screen at the end is the landing radius.
        XCTAssertEqual(scene.focal * SacredTenmonScene.planetRadius / (SacredTenmonScene.planetZ - end.flight.x), 48, accuracy: 0.01)
        XCTAssertGreaterThan(scene.endZ, 37, "past the last gate")
        XCTAssertEqual(end.state.y, 1, "the armillary's rings have come to rest")
        XCTAssertEqual(end.state.w, 1, "and it is day")
        XCTAssertEqual(scene.uniforms(.outro, progress: 0.6, clock: 2, turn: 0).state.w, 0)
        XCTAssertEqual(end.page.w, 0, "the planet stays for the PIN screen to take over")
    }

    func testTheBoardsPlateRunsOnToItsNextMarkAndStops() {
        let hour = Float.pi / 6
        let turn = SacredTenmonScene.turn(holding: 2)
        XCTAssertEqual(turn, 2 / SacredTenmonScene.hourPeriod * hour, accuracy: 0.0001)
        XCTAssertEqual(SacredTenmonScene.settledTurn(from: turn, progress: 0), turn, accuracy: 0.0001)
        let settled = SacredTenmonScene.settledTurn(from: turn, progress: 1)
        XCTAssertGreaterThanOrEqual(settled, turn, "never backwards")
        XCTAssertEqual((settled / hour).rounded(), settled / hour, accuracy: 0.0001, "on a mark")
        XCTAssertEqual(SacredTenmonScene.settledTurn(from: 0, progress: 1), 0, "an unturned plate stays put")
    }

    func testTheTracedSceneBuildsItsShaderAndDraws() async throws {
        try XCTSkipUnless(SacredTenmonPipeline.shared.isAvailable, "no GPU on this machine")
        let built = expectation(description: "the launch scene's shader builds")
        var ready = false
        SacredTenmonPipeline.shared.whenReady(within: 90) { ready = $0; built.fulfill() }
        await fulfillment(of: [built], timeout: 100)
        XCTAssertTrue(ready, "the Metal source must compile")
        XCTAssertTrue(SacredTenmonPipeline.shared.isReady)

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 200, height: 420))
        if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            window.windowScene = scene
        }
        let view = SacredTenmonView(frame: window.bounds)
        window.addSubview(view)
        window.isHidden = false
        defer { window.isHidden = true }
        var stopped = false
        view.playIntro { stopped = true }
        XCTAssertEqual(view.phase, .intro)
        for _ in 0..<60 where !(stopped && view.framesDrawn > 2) {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertTrue(stopped, "the phase ends on the clock")
        XCTAssertEqual(view.phase, .holding)
        XCTAssertGreaterThan(view.framesDrawn, 2)
        XCTAssertNotNil(view.placement)
    }
}
