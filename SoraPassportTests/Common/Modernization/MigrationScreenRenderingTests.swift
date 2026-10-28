// SPDX-License-Identifier: BSD-4-Clause
import Nantes
import SoraUIKit
import UIKit
import XCTest
@testable import SoraPassport

@MainActor
final class MigrationScreenRenderingTests:XCTestCase {
    private func make()->MigrationRedesignViewController {let v = MigrationRedesignViewController();v.loadViewIfNeeded();return v}
    private func descendants<T:UIView>(_ type:T.Type,_ root:UIView)->[T]{((root as? T).map{[$0]} ?? [])+root.subviews.flatMap{descendants(type,$0)}}
    func testInitialScreenShowsConfirmationAndHidesProgress() throws {let v = make();XCTAssertFalse(try XCTUnwrap(descendants(SoramitsuButton.self,v.view).first).isHidden);XCTAssertTrue(v.loadingView.isHidden);XCTAssertTrue(v.titleLabel.isHidden)}
    func testInitialScreenExplainsTheMigration(){let v = make();XCTAssertFalse(v.subtitleLabel.text?.isEmpty ?? true);XCTAssertEqual(v.subtitleLabel.textAlignment,.left);XCTAssertTrue(v.headerLabel.attributedText?.string.contains("SORA v2") ?? false)}
    func testLoadingStateReplacesConfirmationWithProgress() throws {let v = make();v.state = .loading;XCTAssertTrue(try XCTUnwrap(descendants(SoramitsuButton.self,v.view).first).isHidden);XCTAssertFalse(v.loadingView.isHidden);XCTAssertFalse(v.titleLabel.isHidden)}
    func testLoadingStateShowsCenteredStatusAndExplanation(){let v = make();let initial = v.subtitleLabel.text;v.state = .loading;XCTAssertEqual(v.subtitleLabel.textAlignment,.center);XCTAssertFalse(v.titleLabel.text?.isEmpty ?? true);XCTAssertNotEqual(v.subtitleLabel.text,initial)}
    func testResetRestoresAVisibleRetryAction() throws {let v = make();v.state = .loading;v.resetState();XCTAssertFalse(try XCTUnwrap(descendants(SoramitsuButton.self,v.view).first).isHidden);XCTAssertTrue(v.loadingView.isHidden);XCTAssertTrue(v.titleLabel.isHidden);XCTAssertEqual(v.subtitleLabel.textAlignment,.left)}
    func testResetCanBeCalledRepeatedlyWithoutLosingTheExplanation(){let v = make(),expected = v.subtitleLabel.text;v.state = .loading;v.resetState();v.resetState();XCTAssertEqual(v.subtitleLabel.text,expected);XCTAssertFalse(v.subtitleLabel.text?.isEmpty ?? true)}
    func testLoadingStateAssignedBeforeViewLoadRemainsVisible(){let v = MigrationRedesignViewController();v.state = .loading;v.loadViewIfNeeded();XCTAssertFalse(v.loadingView.isHidden);XCTAssertFalse(v.titleLabel.isHidden)}
    func testNormalStateAssignedBeforeViewLoadKeepsProgressHidden(){let v = MigrationRedesignViewController();v.resetState();v.loadViewIfNeeded();XCTAssertTrue(v.loadingView.isHidden);XCTAssertTrue(v.titleLabel.isHidden)}
    func testMigrationScreenUsesCompactNavigationChrome(){let v = make();XCTAssertEqual(v.navigationItem.largeTitleDisplayMode,.never);XCTAssertEqual(v.navigationItem.backButtonTitle,"")}
    func testSupportContactTextIsVisibleAndOwnsTheLinkDelegate(){let v = make();XCTAssertFalse(v.privacyLabel.attributedText?.string.isEmpty ?? true);XCTAssertTrue(v.privacyLabel.delegate === v)}
    func testSupportLabelCanBeDecoratedWithNoText(){let v = make(),label = NantesLabel();label.text = nil;v.decorate(label:label);XCTAssertEqual(label.attributedText?.string,"");XCTAssertTrue(label.delegate === v)}
    func testContentLayoutHasNoAmbiguousFramesAtPhoneWidth(){let v = make();v.view.frame = CGRect(x:0,y:0,width:390,height:844);v.view.layoutIfNeeded();XCTAssertGreaterThan(v.containerView.bounds.width,0);XCTAssertGreaterThan(v.subtitleLabel.bounds.height,0);XCTAssertFalse(v.containerView.hasAmbiguousLayout)}
    func testLoadingTransitionsDoNotDuplicateProgressViews(){let v = make();for _ in 0..<5 {v.state = .loading;v.resetState()};XCTAssertEqual(v.loadingView.subviews.filter{$0 === v.loadingImageView}.count,1);XCTAssertEqual(descendants(SoramitsuButton.self,v.view).count,1)}
    func testProgressAnimationStopsWhenReturningToNormal(){let v = make();v.state = .loading;XCTAssertFalse(v.loadingView.layer.animationKeys()?.isEmpty ?? true);v.resetState();XCTAssertTrue(v.loadingView.layer.animationKeys()?.isEmpty ?? true)}
    func testSupportTextDecorationPreservesVisibleText(){let v = make(),label = NantesLabel();label.text = "Need help?";v.decorate(label:label);XCTAssertEqual(label.attributedText?.string,"Need help?")}
}
