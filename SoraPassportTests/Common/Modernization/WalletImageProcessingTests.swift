// SPDX-License-Identifier: BSD-4-Clause
import Foundation
import Kingfisher
import UIKit
import XCTest
@testable import SoraPassport

@MainActor
final class WalletImageProcessingTests: XCTestCase {
    private var keys = [(String, String)]()
    override func tearDown() { for (key, processor) in keys { KingfisherManager.shared.cache.removeImage(forKey: key, processorIdentifier: processor, fromDisk: false) }; keys = []; super.tearDown() }
    private func make() -> ImageViewModel { ImageViewModel(url: URL(string: "https://image-fixture.test/\(UUID().uuidString).png")!) }
    private func original() -> UIImage { let format = UIGraphicsImageRendererFormat(); format.scale = 1; return UIGraphicsImageRenderer(size: CGSize(width: 40, height: 20), format: format).image { context in UIColor.red.setFill(); context.fill(CGRect(x: 0, y: 0, width: 20, height: 20)); UIColor.blue.setFill(); context.fill(CGRect(x: 20, y: 0, width: 20, height: 20)) } }
    private func process(_ model: ImageViewModel, image: UIImage? = nil) throws -> UIImage { try XCTUnwrap(model.process(item: .image(image ?? original()), options: KingfisherParsedOptionsInfo([.scaleFactor(1)]))) }
    func testUntransformedImageIsPreserved() throws { let model = make(), input = original(); XCTAssertTrue(try process(model, image: input) === input) }
    func testPNGBytesDecodeWithoutTransformation() throws { let model = make(); let data = try XCTUnwrap(original().pngData()); let output = try XCTUnwrap(model.process(item: .data(data), options: KingfisherParsedOptionsInfo([]))); XCTAssertEqual(output.size, CGSize(width: 40, height: 20)) }
    func testMalformedImageBytesFailWithoutAPlaceholder() { XCTAssertNil(make().process(item: .data(Data("not an image".utf8)), options: KingfisherParsedOptionsInfo([]))) }
    func testResizeAndCropProduceTheRequestedSquare() throws { let model = make(); model.targetSize = CGSize(width: 12, height: 12); XCTAssertEqual(try process(model).size, CGSize(width: 12, height: 12)) }
    func testResizeAndCropProduceTheRequestedRectangle() throws { let model = make(); model.targetSize = CGSize(width: 30, height: 8); XCTAssertEqual(try process(model).size, CGSize(width: 30, height: 8)) }
    func testResizeAndCropProduceTheRequestedTallRectangle() throws { let model = make(); model.targetSize = CGSize(width: 7, height: 30); XCTAssertEqual(try process(model).size, CGSize(width: 7, height: 30)) }
    func testNonpositiveAndNonfiniteTargetSizesFailWithoutRendering() {
        let model = make()
        for size in [CGSize(width: 0, height: 10), CGSize(width: -1, height: 10), CGSize(width: 10, height: CGFloat.infinity), CGSize(width: CGFloat.nan, height: 10)] {
            model.targetSize = size
            XCTAssertNil(model.process(item: .image(original()), options: KingfisherParsedOptionsInfo([])))
        }
    }
    func testCornersCanBeRoundedWithoutResizing() throws { let model = make(); model.cornerRadius = 5; let output = try process(model); XCTAssertEqual(output.size, CGSize(width: 40, height: 20)); XCTAssertNotNil(output.cgImage) }
    func testResizeThenRoundPreservesTheTargetSize() throws { let model = make(); model.targetSize = CGSize(width: 10, height: 10); model.cornerRadius = 2; XCTAssertEqual(try process(model).size, CGSize(width: 10, height: 10)) }
    func testInvalidBytesCannotBeResized() { let model = make(); model.targetSize = CGSize(width: 10, height: 10); XCTAssertNil(model.process(item: .data(Data([0,1,2])), options: KingfisherParsedOptionsInfo([]))) }
    func testInvalidBytesCannotBeRounded() { let model = make(); model.cornerRadius = 2; XCTAssertNil(model.process(item: .data(Data([0,1,2])), options: KingfisherParsedOptionsInfo([]))) }
    func testEquivalentRequestsHaveEqualIdentity() { let url = URL(string: "https://image-fixture.test/same.png")!; let first = ImageViewModel(url: url), second = ImageViewModel(url: url); first.targetSize = CGSize(width: 10, height: 20); second.targetSize = first.targetSize; first.cornerRadius = 3; second.cornerRadius = 3; XCTAssertTrue(first.isEqual(to: second)); XCTAssertEqual(first.identifier, second.identifier) }
    func testDifferentURLsAreNotTheSameRequest() { XCTAssertFalse(make().isEqual(to: make())) }
    func testDifferentSizesAreNotTheSameRequest() { let url = URL(string: "https://image-fixture.test/same.png")!; let first = ImageViewModel(url: url), second = ImageViewModel(url: url); first.targetSize = CGSize(width: 10, height: 20); XCTAssertFalse(first.isEqual(to: second)) }
    func testDifferentRadiiAreNotTheSameRequest() { let url = URL(string: "https://image-fixture.test/same.png")!; let first = ImageViewModel(url: url), second = ImageViewModel(url: url); first.cornerRadius = 1; XCTAssertFalse(first.isEqual(to: second)) }
    func testFractionalSizesDoNotCollideInTheProcessedImageCache() { let first = make(), second = make(); first.targetSize = CGSize(width: 10.25, height: 10); second.targetSize = CGSize(width: 10.75, height: 10); XCTAssertNotEqual(first.identifier, second.identifier) }
    func testFractionalRadiiDoNotCollideInTheProcessedImageCache() { let first = make(), second = make(); first.cornerRadius = 1.25; second.cornerRadius = 1.75; XCTAssertNotEqual(first.identifier, second.identifier) }
    func testUncachedImageRemainsUnavailable() { XCTAssertNil(make().image) }
    func testProcessedMemoryCacheIsReadUsingTheFullTransformationIdentity() {
        let key = "https://image-fixture.test/\(UUID().uuidString).png", image = original(); let model = ImageViewModel(url: URL(string: key)!); model.targetSize = CGSize(width: 12, height: 12)
        KingfisherManager.shared.cache.store(image, forKey: key, processorIdentifier: model.identifier, toDisk: false); keys.append((key, model.identifier))
        XCTAssertTrue(model.image === image); model.targetSize = CGSize(width: 8, height: 8); XCTAssertNil(model.image)
    }
    func testLoadingAPreviouslyCachedImageCompletesOnMainWithoutNetwork() async {
        let key = "https://image-fixture.test/\(UUID().uuidString).png", input = original(); let model = ImageViewModel(url: URL(string: key)!)
        KingfisherManager.shared.cache.store(input, forKey: key, processorIdentifier: model.identifier, toDisk: false); keys.append((key, model.identifier))
        let done = expectation(description: "memory cache callback")
        model.loadImage { image, error in XCTAssertTrue(Thread.isMainThread); XCTAssertNil(error); XCTAssertNotNil(image); done.fulfill() }
        await fulfillment(of: [done], timeout: 2); model.cancel(); model.cancel()
    }
}
