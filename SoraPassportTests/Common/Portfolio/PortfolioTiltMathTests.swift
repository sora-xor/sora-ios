// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

@testable import SoraPassport
import XCTest

/// Replays the portfolio dashboard's golden parallax vectors (`parallax-vectors.json`, generated
/// from the reference prototype) against `PortfolioTilt`. Every port must reproduce them within 1e-6.
final class PortfolioTiltMathTests: XCTestCase {
    private let eps = 1e-6

    private func vectors() throws -> (constants: [String: Any], cases: [[String: Any]]) {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "parallax-vectors", withExtension: "json"))
        let root = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        return (try XCTUnwrap(root["constants"] as? [String: Any]), try XCTUnwrap(root["cases"] as? [[String: Any]]))
    }

    private func number(_ value: Any?) -> Double { (value as? NSNumber)?.doubleValue ?? .nan }
    private func numbers(_ value: Any?) -> [Double] { (value as? [Any] ?? []).map(number) }

    func testConstantsMatchTheVectors() throws {
        let constants = try vectors().constants
        XCTAssertEqual(number(constants["tiltRangeDeg"]), PortfolioTilt.Constants.tiltRangeDeg)
        XCTAssertEqual(number(constants["baselineTauMs"]), PortfolioTilt.Constants.baselineTauMs)
        XCTAssertEqual(number(constants["deadzone"]), PortfolioTilt.Constants.deadzone)
        XCTAssertEqual(number(constants["phoneSmoothTauMs"]), PortfolioTilt.Constants.phoneSmoothTauMs)
        XCTAssertEqual(number(constants["settleEps"]), PortfolioTilt.Constants.settleEps)
    }

    func testEveryVectorCase() throws {
        let cases = try vectors().cases
        XCTAssertEqual(cases.count, 13)
        var checks = 0
        for item in cases {
            let id = try XCTUnwrap(item["id"] as? String)
            let kind = try XCTUnwrap(item["kind"] as? String)
            let expect = try XCTUnwrap(item["expect"] as? [Any])
            switch kind {
            case "baseline":
                var baseline = PortfolioTilt.Baseline(tauMs: number(item["tauMs"]))
                for (index, sample) in (item["samples"] as? [Any] ?? []).enumerated() {
                    let values = numbers(sample)
                    let output = baseline.normalise(rollDeg: values[1], pitchDeg: values[2], nowMs: values[0])
                    let expected = numbers(expect[index])
                    XCTAssertEqual(output.x, expected[0], accuracy: eps, "\(id)[\(index)].x")
                    XCTAssertEqual(output.y, expected[1], accuracy: eps, "\(id)[\(index)].y")
                    checks += 2
                }
            case "smooth":
                var smooth = PortfolioTilt.Smooth2D(tauMs: number(item["tauMs"]))
                let start = numbers(item["start"])
                smooth.x = start[0]
                smooth.y = start[1]
                smooth.tx = start[0]
                smooth.ty = start[1]
                for (index, step) in (item["steps"] as? [Any] ?? []).enumerated() {
                    let values = numbers(step)
                    smooth.tx = values[1]
                    smooth.ty = values[2]
                    let settled = smooth.step(dtMs: values[0])
                    let expected = numbers(expect[index])
                    XCTAssertEqual(smooth.x, expected[0], accuracy: eps, "\(id)[\(index)].x")
                    XCTAssertEqual(smooth.y, expected[1], accuracy: eps, "\(id)[\(index)].y")
                    XCTAssertEqual(settled ? 1.0 : 0.0, expected[2], "\(id)[\(index)] settled")
                    checks += 3
                }
            case "offset":
                for (index, input) in (item["inputs"] as? [Any] ?? []).enumerated() {
                    let values = numbers(input)
                    let output = PortfolioTilt.layerOffset(x: values[0], y: values[1], depthX: values[2],
                                                           depthY: values[3], scale: values[4])
                    let expected = numbers(expect[index])
                    XCTAssertEqual(output.dx, expected[0], accuracy: eps, "\(id)[\(index)].dx")
                    XCTAssertEqual(output.dy, expected[1], accuracy: eps, "\(id)[\(index)].dy")
                    checks += 2
                }
            case "viewer-tilt":
                for (index, input) in (item["inputs"] as? [[Any]] ?? []).enumerated() {
                    let from = numbers(input[0]), to = numbers(input[1])
                    let output = PortfolioTilt.viewerTilt(from: (from[0], from[1], from[2], from[3]),
                                                          to: (to[0], to[1], to[2], to[3]))
                    let expected = numbers(expect[index])
                    XCTAssertEqual(output.xDeg, expected[0], accuracy: eps, "\(id)[\(index)].x")
                    XCTAssertEqual(output.yDeg, expected[1], accuracy: eps, "\(id)[\(index)].y")
                    checks += 2
                }
            case "gate":
                for (index, input) in (item["inputs"] as? [[Any]] ?? []).enumerated() {
                    // The reference's "full" effects tier is the portfolio flag on this app.
                    let gate = PortfolioTilt.Gate(enabled: (input[0] as? String) == "full",
                                                  reduceMotion: input[1] as? Bool ?? false,
                                                  lowPower: input[2] as? Bool ?? false,
                                                  hidden: input[3] as? Bool ?? false,
                                                  heroVisible: input[4] as? Bool ?? false)
                    XCTAssertEqual(gate.isOpen ? 1.0 : 0.0, number(expect[index]), "\(id)[\(index)]")
                    checks += 1
                }
            default:
                XCTFail("Unknown vector kind \(kind)")
            }
        }
        // The reference Swift port runs 923 checks including the five constants.
        XCTAssertEqual(checks, 918)
    }

    func testLayersMoveOppositeToTheInputAndNearLayersMoveMore() {
        let fan = PortfolioTilt.layerOffset(x: 1, y: 0, depthX: 7, depthY: 4.55, scale: 1)
        let flower = PortfolioTilt.layerOffset(x: 1, y: 0, depthX: 22, depthY: 14.3, scale: 1)
        XCTAssertLessThan(fan.dx, 0)
        XCTAssertLessThan(flower.dx, fan.dx)
    }
}
