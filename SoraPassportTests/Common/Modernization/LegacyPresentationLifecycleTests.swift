// SPDX-License-Identifier: BSD-4-Clause
import Combine
import RobinHood
import SoraUIKit
import UIKit
import XCTest
@testable import SoraPassport

@MainActor
final class LegacyPresentationLifecycleTests: XCTestCase {
    private func descendants<T: UIView>(_ type: T.Type, in view: UIView) -> [T] {
        ((view as? T).map { [$0] } ?? []) + view.subviews.flatMap { descendants(type, in: $0) }
    }
    func testSearchProgressIsIdempotentAndDoesNotReplaceTheQuery() throws {
        let bar = UISearchBar(); bar.text = "SORA"; bar.setLeftImage(UIImage(color: .red), tintColor: .blue)
        XCTAssertFalse(bar.isLoading); bar.isLoading = true
        let spinner = try XCTUnwrap(bar.activityIndicator); XCTAssertTrue(spinner.isAnimating)
        bar.isLoading = true; XCTAssertTrue(bar.activityIndicator === spinner)
        XCTAssertEqual(bar.text, "SORA"); bar.isLoading = false; XCTAssertNil(bar.activityIndicator)
        bar.isLoading = false; XCTAssertEqual(bar.text, "SORA")
    }
    func testSearchIconPaddingAndTintAreAppliedWithoutChangingText() throws {
        let bar = UISearchBar(); bar.text = "VAL"; let icon = UIImage(color: .red, size: CGSize(width: 4, height: 4))
        bar.setLeftImage(icon, with: 12, tintColor: .green)
        let stack = try XCTUnwrap(bar.textField?.leftView as? UIStackView)
        XCTAssertEqual(stack.arrangedSubviews.count, 2)
        let image = try XCTUnwrap(stack.arrangedSubviews.last as? UIImageView); XCTAssertTrue(image.image === icon); XCTAssertEqual(image.tintColor, .green)
        bar.setLeftImage(icon, tintColor: .blue); XCTAssertTrue(bar.textField?.leftView is UIImageView); XCTAssertEqual(bar.text, "VAL")
    }
    func testSearchBookmarkConfiguresBothImageStates() throws {
        let bar = UISearchBar(); bar.showsBookmarkButton = true
        let button = UIButton(); bar.searchTextField.rightView = button
        let normal = UIImage(color: .red), highlighted = UIImage(color: .blue)
        bar.setRightImage(normalImage: normal, highLightedImage: highlighted)
        XCTAssertTrue(bar.showsBookmarkButton); XCTAssertTrue(button.image(for: .normal) === normal); XCTAssertTrue(button.image(for: .highlighted) === highlighted)
    }
    func testSearchStylingPreservesPlaceholderAndEnteredText() {
        let bar = UISearchBar(); bar.placeholder = "Search assets"; bar.text = "XOR"; bar.layoutIfNeeded()
        bar.clearBackgroundColor(); bar.changePlaceholderColor(.red)
        XCTAssertEqual(bar.placeholder, "Search assets"); XCTAssertEqual(bar.text, "XOR"); XCTAssertTrue(bar.textField === bar.searchTextField)
    }
    func testSolidColorImageHasTheRequestedRenderableSize() {
        let image = UIImage(color: .purple, size: CGSize(width: 8, height: 5))
        XCTAssertEqual(image.size, CGSize(width: 8, height: 5)); XCTAssertNotNil(image.cgImage)
        XCTAssertEqual(CGFloat(image.cgImage!.width), 8 * image.scale); XCTAssertEqual(CGFloat(image.cgImage!.height), 5 * image.scale)
    }
    func testToastRendersUpdatedMessagesAndRoundedClipping() throws {
        let toast = AppEventView(frame: CGRect(x: 0, y: 0, width: 240, height: 60))
        toast.fill(via: .init(title: NSAttributedString(string: "Saved"))); toast.layoutIfNeeded()
        let label = try XCTUnwrap(descendants(SoramitsuLabel.self, in: toast).first)
        XCTAssertEqual(label.sora.text, "Saved"); XCTAssertEqual(toast.layer.cornerRadius, 6); XCTAssertTrue(toast.clipsToBounds)
        toast.fill(via: .init(title: NSAttributedString(string: "Try again"))); XCTAssertEqual(label.sora.text, "Try again")
    }
    func testToastControllerTransitionsBetweenShownAndHiddenConstraints() async throws {
        let controller = AppEventViewController(style: .custom(.init(title: NSAttributedString(string: "Public notification"))))
        controller.loadViewIfNeeded(); controller.view.frame = CGRect(x: 0, y: 0, width: 320, height: 640)
        let toast = try XCTUnwrap(controller.view.subviews.first as? AppEventView)
        controller.show(); controller.view.layoutIfNeeded()
        XCTAssertLessThanOrEqual(toast.frame.maxY, controller.view.bounds.height - 16)
        let hidden = expectation(description: "hidden"); controller.hide { hidden.fulfill() }
        await fulfillment(of: [hidden], timeout: 2); controller.view.layoutIfNeeded()
        XCTAssertGreaterThanOrEqual(toast.frame.minY, controller.view.bounds.height)
        XCTAssertEqual(descendants(SoramitsuLabel.self, in: toast).first?.sora.text, "Public notification")
    }
    func testProfileLoginRequestsInitialDataAndAppliesLaterTitles() throws {
        let presenter = LegacyLoginPresenter(), controller = ProfileLoginView(); presenter.view = controller; controller.presenter = presenter
        controller.loadViewIfNeeded(); XCTAssertEqual(presenter.reloads, 1)
        let item = EditViewItem(), first = ProfileLoginModel(title: "Security", sections: [SoramitsuTableViewSection(rows: [EditViewItem()])])
        controller.update(model: first); XCTAssertEqual(controller.navigationItem.title, "Security")
        controller.update(model: ProfileLoginModel(title: "Sign-in settings", sections: [SoramitsuTableViewSection(rows: [item])]))
        XCTAssertEqual(controller.navigationItem.title, "Sign-in settings")
        XCTAssertNotNil(descendants(SoramitsuTableView.self, in: controller.view).first)
    }
    func testWalletEditCellPreservesItsTapCallbackAcrossStyleChanges() throws {
        let cell = EditViewCell(style: .default, reuseIdentifier: "fixture"), item = EditViewItem(); var taps = 0; item.onTap = { taps += 1 }
        cell.set(item: item, context: nil); cell.frame = CGRect(x: 0, y: 0, width: 320, height: 56); cell.layoutIfNeeded()
        let button = try XCTUnwrap(descendants(SoramitsuButton.self, in: cell).first)
        cell.styleDidChange(options: .palette)
        XCTAssertFalse(button.sora.isUserInteractionEnabled); item.itemActionTap(with: nil); XCTAssertEqual(taps, 1)
        XCTAssertFalse(item.clipsToBounds); XCTAssertEqual(ObjectIdentifier(item.cellType), ObjectIdentifier(EditViewCell.self))
    }
}
private final class LegacyLoginPresenter: ProfileLoginPresenterProtocol {
    weak var view: ProfileLoginView?
    var reloads = 0
    func reload() { reloads += 1 }
}

@MainActor
final class ErrorPresentationBoundaryTests: XCTestCase {
    private let locale = Locale(identifier: "en")
    func testConvertibleErrorUsesReviewedContentInsteadOfRawErrorText() {
        let presenter = ErrorAlertRecorder()
        XCTAssertTrue(presenter.present(error: ContentError(), from: nil, locale: locale))
        XCTAssertEqual(presenter.messages, ["Safe message"]); XCTAssertEqual(presenter.titles, ["Safe title"])
    }
    func testOperationFailureHasLocalizedActionableContent() {
        let presenter = ErrorAlertRecorder()
        XCTAssertTrue(presenter.present(error: BaseOperationError.parentOperationCancelled, from: nil, locale: locale))
        XCTAssertEqual(presenter.titles, [R.string.localizable.operationErrorTitle(preferredLanguages: ["en"])])
        XCTAssertEqual(presenter.messages, [R.string.localizable.operationErrorMessage(preferredLanguages: ["en"])])
    }
    func testURLFailureUsesConnectionContentWithoutExposingTheFailingURL() {
        let presenter = ErrorAlertRecorder(), secret = "https://fixture.invalid/private-account"
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: [NSLocalizedDescriptionKey: secret])
        XCTAssertTrue(presenter.present(error: error, from: nil, locale: locale))
        XCTAssertEqual(presenter.titles, [R.string.localizable.connectionErrorTitle(preferredLanguages: ["en"])])
        XCTAssertFalse(presenter.messages.joined().contains(secret))
    }
    func testUnknownErrorIsLeftForItsCallingFlowToHandle() {
        let presenter = ErrorAlertRecorder()
        XCTAssertFalse(presenter.present(error: NSError(domain: "unknown", code: 1), from: nil, locale: nil))
        XCTAssertTrue(presenter.titles.isEmpty)
    }
    func testCompletionIsDeferredUntilTheRecognizedAlertCloses() {
        for error: Error in [ContentError(), BaseOperationError.parentOperationCancelled, NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)] {
            let presenter = ErrorAlertRecorder(); var completions = 0
            XCTAssertTrue(presenter.present(error: error, from: nil, locale: locale) { completions += 1 })
            XCTAssertEqual(completions, 0); XCTAssertEqual(presenter.titles.count, 1)
            presenter.completion?(); XCTAssertEqual(completions, 1)
        }
    }
    func testUnknownErrorDoesNotCaptureOrExecuteAnAlertCompletion() {
        let presenter = ErrorAlertRecorder()
        XCTAssertFalse(presenter.present(error: NSError(domain: "unknown", code: 1), from: nil, locale: nil) { XCTFail("No alert was presented") })
        XCTAssertNil(presenter.completion); XCTAssertTrue(presenter.titles.isEmpty)
    }
    func testAlertActionStylesPreserveDestructiveAndCancelSemantics() {
        XCTAssertEqual(AlertPresentableAction.Style.normal.uialertStyle, .default)
        XCTAssertEqual(AlertPresentableAction.Style.destructive.uialertStyle, .destructive)
        XCTAssertEqual(AlertPresentableAction.Style.cancel.uialertStyle, .cancel)
    }
}
private struct ContentError: Error, ErrorContentConvertible {
    func toErrorContent(for locale: Locale?) -> ErrorContent { ErrorContent(title: "Safe title", message: "Safe message") }
}
private final class ErrorAlertRecorder: ErrorPresentable, AlertPresentable {
    var titles: [String] = [], messages: [String] = []; var completion: (() -> Void)?
    func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?) { titles.append(title ?? ""); messages.append(message ?? ""); XCTAssertFalse((closeAction ?? "").isEmpty) }
    func present(message: String?, title: String?, closeAction: String?, from view: ControllerBackedProtocol?, completion: @escaping () -> Void) { present(message: message, title: title, closeAction: closeAction, from: view); self.completion = completion }
    func present(viewModel: AlertPresentableViewModel, style: UIAlertController.Style, from view: ControllerBackedProtocol?) { XCTFail("Unexpected custom alert") }
}
