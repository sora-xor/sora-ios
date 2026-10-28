// SPDX-License-Identifier: Apache-2.0
import UIKit
import XCTest

@testable import SoraPassport

@MainActor final class ScannerFrameRenderingTests: XCTestCase {
  private func make() -> QRFrameView {
    let v = QRFrameView(frame: CGRect(x: 0, y: 0, width: 320, height: 480))
    v.windowSize = CGSize(width: 100, height: 100)
    v.windowPosition = CGPoint(x: 0.5, y: 100)
    v.cornerRadius = 0
    v.layoutIfNeeded()
    return v
  }
  private func overlay(_ v: QRFrameView) throws -> CAShapeLayer {
    try XCTUnwrap(v.layer.sublayers?.compactMap { $0 as? CAShapeLayer }.first)
  }
  func testScannerOverlayCoversTheViewBounds() throws {
    let v = make()
    XCTAssertEqual(try overlay(v).frame, v.bounds)
    XCTAssertEqual(try overlay(v).fillRule, .evenOdd)
  }
  func testScannerWindowRemainsTransparentAtItsCenter() throws {
    let v = make()
    let path = try XCTUnwrap(overlay(v).path)
    XCTAssertFalse(path.contains(CGPoint(x: 160, y: 150), using: .evenOdd))
    XCTAssertTrue(path.contains(CGPoint(x: 20, y: 20), using: .evenOdd))
  }
  func testWindowSizeChangeUpdatesTheTransparentRegion() throws {
    let v = make()
    v.windowSize = CGSize(width: 200, height: 200)
    let path = try XCTUnwrap(overlay(v).path)
    XCTAssertFalse(path.contains(CGPoint(x: 80, y: 150), using: .evenOdd))
    XCTAssertTrue(path.contains(CGPoint(x: 40, y: 150), using: .evenOdd))
  }
  func testWindowPositionMovesTheTransparentRegion() throws {
    let v = make()
    v.windowPosition = CGPoint(x: 0.5, y: 250)
    let path = try XCTUnwrap(overlay(v).path)
    XCTAssertTrue(path.contains(CGPoint(x: 160, y: 150), using: .evenOdd))
    XCTAssertFalse(path.contains(CGPoint(x: 160, y: 300), using: .evenOdd))
  }
  func testFillColorUpdatesTheActualOverlayLayer() throws {
    let v = make()
    v.fillColor = .red
    XCTAssertEqual(try overlay(v).fillColor, UIColor.red.cgColor)
  }
  func testPreviewLayerAlwaysMatchesTheCurrentBounds() {
    let v = make()
    let preview = CALayer()
    v.frameLayer = preview
    v.layoutIfNeeded()
    XCTAssertEqual(preview.frame, v.bounds)
    v.bounds.size = CGSize(width: 480, height: 320)
    v.setNeedsLayout()
    v.layoutIfNeeded()
    XCTAssertEqual(preview.frame, v.bounds)
  }
  func testReplacingPreviewLayerRemovesThePreviousCameraPreview() {
    let v = make()
    let old = CALayer()
    let current = CALayer()
    v.frameLayer = old
    v.frameLayer = current
    XCTAssertNil(old.superlayer)
    XCTAssertTrue(current.superlayer === v.layer)
    XCTAssertEqual(v.layer.sublayers?.count, 2)
  }
  func testClearingPreviewLayerPreservesOnlyTheOverlay() throws {
    let v = make()
    v.frameLayer = CALayer()
    v.frameLayer = nil
    XCTAssertEqual(v.layer.sublayers?.count, 1)
    XCTAssertTrue(v.layer.sublayers?.first === (try overlay(v)))
  }
  func testPreviewLayerIsBelowTheOpaqueOverlay() throws {
    let v = make()
    let preview = CALayer()
    v.frameLayer = preview
    XCTAssertTrue(v.layer.sublayers?.first === preview)
    XCTAssertTrue(v.layer.sublayers?.last === (try overlay(v)))
  }
  func testRepeatedLayoutDoesNotAccumulateOverlayLayers() {
    let v = make()
    for _ in 0..<5 {
      v.setNeedsLayout()
      v.layoutIfNeeded()
    }
    XCTAssertEqual(v.layer.sublayers?.count, 1)
  }
  func testRotationRecentersTheScannerWindow() throws {
    let v = make()
    v.bounds.size = CGSize(width: 480, height: 320)
    v.setNeedsLayout()
    v.layoutIfNeeded()
    let path = try XCTUnwrap(overlay(v).path)
    XCTAssertFalse(path.contains(CGPoint(x: 240, y: 150), using: .evenOdd))
    XCTAssertTrue(path.contains(CGPoint(x: 160, y: 150), using: .evenOdd))
  }
}
