// SPDX-License-Identifier: Apache-2.0
import SoraUIKit
import UIKit
import XCTest
@testable import SoraPassport

@MainActor
final class WalletRenderingBoundaryTests: XCTestCase {
    private func pixel(_ image: UIImage, x: Int, y: Int) throws -> [UInt8] {
        let source = try XCTUnwrap(image.cgImage), width = source.width, height = source.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let context = try XCTUnwrap(CGContext(data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
        return Array(bytes[(y * width + x) * 4..<(y * width + x) * 4 + 4])
    }
    private func stripes(tall: Bool) -> UIImage {
        let size = tall ? CGSize(width: 20, height: 60) : CGSize(width: 60, height: 20)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            for (index, color) in [UIColor.red, .green, .blue].enumerated() {
                color.setFill(); context.fill(CGRect(x: tall ? 0 : index * 20, y: tall ? index * 20 : 0, width: 20, height: 20))
            }
        }
    }
    func testAspectFillCropKeepsTheCenterForBothWideAndTallImages() throws {
        for tall in [false, true] {
            let image = try XCTUnwrap(stripes(tall: tall).crop(targetSize: CGSize(width: 20, height: 20), cornerRadius: 0, contentScale: 1))
            XCTAssertEqual(image.size, CGSize(width: 20, height: 20)); XCTAssertEqual(image.scale, 1)
            XCTAssertEqual(try pixel(image, x: 10, y: 10), [0, 255, 0, 255])
            XCTAssertEqual(try pixel(image, x: 1, y: 10), [0, 255, 0, 255])
        }
    }
    func testRoundedCropPreservesTransparencyAndRequestedPixelDensity() throws {
        let source = try XCTUnwrap(UIImage.background(from: .red, size: CGSize(width: 20, height: 20)))
        let image = try XCTUnwrap(source.crop(targetSize: CGSize(width: 20, height: 20), cornerRadius: 10, contentScale: 2))
        XCTAssertEqual(image.cgImage?.width, 40); XCTAssertEqual(image.scale, 2)
        XCTAssertEqual(try pixel(image, x: 0, y: 0)[3], 0); XCTAssertEqual(try pixel(image, x: 20, y: 20), [255, 0, 0, 255])
    }
    func testInvalidCropDimensionsReturnNoImageWithoutStartingAGraphicsContext() {
        XCTAssertNil(UIImage().crop(targetSize: CGSize(width: 20, height: 20), cornerRadius: 0, contentScale: 1))
        let image = stripes(tall: false)
        for size in [CGSize.zero, CGSize(width: -1, height: 20), CGSize(width: 20, height: 0)] { XCTAssertNil(image.crop(targetSize: size, cornerRadius: 0, contentScale: 1)) }
    }
    func testTintChangesOnlyVisiblePixelsAndPreservesRoundedAlpha() throws {
        let source = try XCTUnwrap(UIImage.background(from: .red, size: CGSize(width: 20, height: 20), cornerRadius: 10, contentScale: 1))
        let tinted = try XCTUnwrap(source.tinted(with: .blue))
        XCTAssertEqual(tinted.size, source.size); XCTAssertEqual(try pixel(tinted, x: 0, y: 0)[3], 0)
        XCTAssertEqual(try pixel(tinted, x: 10, y: 10), [0, 0, 255, 255])
    }
    private func labels(_ root: UIView) -> [UILabel] { ((root as? UILabel).map { [$0] } ?? []) + root.subviews.flatMap(labels) }
    private func layout(_ view: MnemonicDisplayView) {
        view.frame = CGRect(origin: .zero, size: CGSize(width: 800, height: max(1, view.intrinsicContentSize.height)))
        view.layoutIfNeeded(); view.subviews.forEach { $0.layoutIfNeeded() }
    }
    func testMnemonicColumnsKeepEveryWordPairedWithItsOneBasedIndex() {
        let view = MnemonicDisplayView(frame: .zero), words = (1...12).map { "public-word-\($0)" }
        view.bind(words: words, columnsCount: 2); layout(view)
        XCTAssertEqual(view.subviews.count, 2)
        for (columnIndex, column) in view.subviews.enumerated() {
            let values = labels(column).compactMap(\.text)
            for index in (columnIndex * 6 + 1)...(columnIndex * 6 + 6) { XCTAssertTrue(values.contains(String(index))); XCTAssertTrue(values.contains("public-word-\(index)")) }
            let wordLabels = labels(column).filter { $0.text?.hasPrefix("public-word-") == true }.sorted { $0.frame.minY < $1.frame.minY }
            for index in 1..<wordLabels.count { XCTAssertGreaterThanOrEqual(wordLabels[index].frame.minY, wordLabels[index - 1].frame.maxY) }
        }
        XCTAssertGreaterThan(view.intrinsicContentSize.width, 0); XCTAssertGreaterThan(view.intrinsicContentSize.height, 0)
    }
    func testMnemonicRebindingRemovesOldWordsAndShrinksTheColumnInventory() {
        let view = MnemonicDisplayView(frame: .zero); view.bind(words: (1...24).map { "old-\($0)" }, columnsCount: 3); layout(view)
        view.bind(words: ["new-a", "new-b", "new-c", "new-d"], columnsCount: 1); layout(view)
        XCTAssertEqual(view.subviews.count, 1); XCTAssertEqual(labels(view).compactMap(\.text).count, 8)
        XCTAssertFalse(labels(view).contains { $0.text?.hasPrefix("old-") == true })
        view.bind(words: [], columnsCount: 1); layout(view); XCTAssertTrue(labels(view).isEmpty)
    }
    func testBlankMnemonicSlotsHideBothWordAndIndexAndInvalidColumnCountsPreserveTheCurrentPhrase() {
        let view = MnemonicDisplayView(frame: .zero); view.bind(words: ["public-a", "", "public-c", "public-d"], columnsCount: 2); layout(view)
        let before = labels(view).compactMap(\.text).sorted(); XCTAssertFalse(before.contains("2")); XCTAssertFalse(before.contains(""))
        view.bind(words: ["wrong"], columnsCount: 2); view.bind(words: ["wrong"], columnsCount: 0); layout(view)
        XCTAssertEqual(labels(view).compactMap(\.text).sorted(), before)
    }
    func testMnemonicStyleAndSpacingChangesPropagateToEveryColumn() {
        let view = MnemonicDisplayView(frame: .zero); view.bind(words: ["one", "two", "three", "four"], columnsCount: 2); layout(view)
        let initial = view.intrinsicContentSize
        view.horizontalSpacingInColumn = 25; view.verticalSpacingInColumn = 12; view.columnsSpacing = 40
        view.indexFontInColumn = FontType.textS; view.wordFontInColumn = FontType.textBoldL
        view.indexTitleColorInColumn = .fgSecondary; view.wordTitleColorInColumn = .fgPrimary; layout(view)
        XCTAssertEqual(view.horizontalSpacingInColumn, 25); XCTAssertEqual(view.verticalSpacingInColumn, 12)
        XCTAssertGreaterThan(view.intrinsicContentSize.height, initial.height)
        XCTAssertEqual(view.subviews[1].frame.minX - view.subviews[0].frame.maxX, 40, accuracy: 0.01)
    }
}
