// SPDX-License-Identifier: Apache-2.0
import UIKit
import XCTest
@testable import SoraPassport

@MainActor
final class ExtendedNavigationFlowTests:XCTestCase {
    private var windows = [UIWindow]()
    override func tearDown(){windows.forEach{$0.isHidden = true;$0.rootViewController = nil};windows = [];super.tearDown()}
    private func make(_ root:UIViewController? = nil)->ExtensibleBarNavigationController {let n = ExtensibleBarNavigationController(rootViewController:root ?? ExtendedScreen());n.loadViewIfNeeded();n.view.frame = CGRect(x:0,y:0,width:390,height:844);n.view.layoutIfNeeded();return n}
    private func descendants<T:UIView>(_ type:T.Type,_ root:UIView)->[T]{((root as? T).map{[$0]} ?? [])+root.subviews.flatMap{descendants(type,$0)}}
    func testExtensionAddsOnlyItsHeightToAnOptedInScreen(){let n = make(),extensionView = UIView();n.setNavigationBarExtensionView(extensionView,forHeight:50);XCTAssertEqual(n.topViewController?.additionalSafeAreaInsets.top,50);XCTAssertNotNil(extensionView.superview)}
    func testAnOrdinaryScreenDoesNotReserveExtensionSpace(){let n = make(UIViewController());n.setNavigationBarExtensionView(UIView(),forHeight:50);XCTAssertEqual(n.topViewController?.additionalSafeAreaInsets,.zero)}
    func testAnOptedOutScreenDoesNotReserveExtensionSpace(){let r = ExtendedScreen();r.shouldExtendNavigationBar = false;let n = make(r);n.setNavigationBarExtensionView(UIView(),forHeight:50);XCTAssertEqual(r.additionalSafeAreaInsets,.zero)}
    func testChangingExtensionHeightReplacesTheSafeAreaInset(){let n = make();n.setNavigationBarExtensionView(UIView(),forHeight:50);n.setNavigationBarExtensionView(UIView(),forHeight:24);XCTAssertEqual(n.topViewController?.additionalSafeAreaInsets.top,24)}
    func testRemovingExtensionRestoresTheSafeArea(){let n = make();n.setNavigationBarExtensionView(UIView(),forHeight:50);n.setNavigationBarExtensionView(nil);XCTAssertEqual(n.topViewController?.additionalSafeAreaInsets,.zero)}
    func testReplacingExtensionDetachesTheOldContent(){let n = make(),first = UIView();n.setNavigationBarExtensionView(first,forHeight:50);let oldContainer = first.superview;n.setNavigationBarExtensionView(UIView(),forHeight:50);XCTAssertNil(oldContainer?.superview)}
    func testRepeatedReplacementDoesNotAccumulateToolbarViews(){let n = make();n.setNavigationBarExtensionView(UIView(),forHeight:50);let count = descendants(UIToolbar.self,n.view).count;for _ in 0..<5{n.setNavigationBarExtensionView(UIView(),forHeight:50)};XCTAssertEqual(descendants(UIToolbar.self,n.view).count,count)}
    func testPushingAnOptedOutScreenRemovesExtensionInset(){let n = make();n.setNavigationBarExtensionView(UIView(),forHeight:50);let next = UIViewController();n.pushViewController(next,animated:false);XCTAssertEqual(next.additionalSafeAreaInsets,.zero)}
    func testPushingAnOptedInScreenAppliesExtensionInset(){let n = make(UIViewController());n.setNavigationBarExtensionView(UIView(),forHeight:50);let next = ExtendedScreen();n.pushViewController(next,animated:false);XCTAssertEqual(next.additionalSafeAreaInsets.top,50)}
    func testNonanimatedPushIsReportedAsNonanimatedToDelegate() async throws {
        let root = ExtendedScreen(),n = make(root),d = ExtendedDelegate()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap{$0 as? UIWindowScene}.first)
        let window = UIWindow(windowScene:scene);window.frame = scene.coordinateSpace.bounds;window.rootViewController = n;windows.append(window);window.makeKeyAndVisible()
        for _ in 0..<100 {if root.appeared {break};try? await Task.sleep(nanoseconds:10_000_000)}
        XCTAssertTrue(root.appeared)
        n.navigationControllerDelegate = d;n.pushViewController(UIViewController(),animated:false)
        for _ in 0..<100 {if !d.animations.isEmpty {break};try? await Task.sleep(nanoseconds:10_000_000)}
        XCTAssertEqual(d.animations.last,false)
    }
    func testDelegateReceivesTheExactWillShowController(){let n = make(),d = ExtendedDelegate(),next = UIViewController();n.navigationControllerDelegate = d;n.navigationController(n,willShow:next,animated:false);XCTAssertTrue(d.screens.last === next)}
    func testDelegateReplacementStopsCallbacksToTheOldDelegate(){let n = make(),first = ExtendedDelegate(),last = ExtendedDelegate();n.navigationControllerDelegate = first;n.navigationControllerDelegate = last;n.navigationController(n,willShow:UIViewController(),animated:false);XCTAssertTrue(first.screens.isEmpty);XCTAssertEqual(last.screens.count,1)}
    func testNavigationDelegateIsWeaklyOwned(){let n = make();var d:ExtendedDelegate? = ExtendedDelegate();weak var observed = d;n.navigationControllerDelegate = d;d = nil;XCTAssertNil(observed);XCTAssertNil(n.navigationControllerDelegate)}
    func testUnimplementedOptionalSelectorIsForwardedToDelegate(){let n = make(),d = ExtendedDelegate();n.navigationControllerDelegate = d;let selector = #selector(UINavigationControllerDelegate.navigationController(_:didShow:animated:));XCTAssertTrue(n.responds(to:selector));XCTAssertTrue(n.forwardingTarget(for:selector) as AnyObject === d)}
    func testOptionalSelectorIsNotAdvertisedWithoutDelegate(){let n = make();let selector = #selector(UINavigationControllerDelegate.navigationController(_:didShow:animated:));XCTAssertFalse(n.responds(to:selector))}
    func testShowingOptedInScreenEnablesExtensionInteraction(){let root = ExtendedScreen(),n = make(root),content = UIButton();n.setNavigationBarExtensionView(content,forHeight:40);n.navigationController(n,willShow:root,animated:false);XCTAssertEqual(content.superview?.superview?.isUserInteractionEnabled,true)}
    func testShowingOrdinaryScreenDisablesHiddenExtensionInteraction(){let n = make(),content = UIButton();n.setNavigationBarExtensionView(content,forHeight:40);n.navigationController(n,willShow:UIViewController(),animated:false);XCTAssertEqual(content.superview?.superview?.isUserInteractionEnabled,false)}
    func testZeroHeightExtensionDoesNotAddSafeArea(){let n = make();n.setNavigationBarExtensionView(UIView(),forHeight:0);XCTAssertEqual(n.topViewController?.additionalSafeAreaInsets,.zero)}
    func testRemovedExtensionContentIsReleased() async {let n = make();var content:UIView? = UIView();weak var observed = content;n.setNavigationBarExtensionView(content,forHeight:40);content = nil;n.setNavigationBarExtensionView(nil);n.view.layoutIfNeeded();for _ in 0..<100 {if observed == nil {break};try? await Task.sleep(nanoseconds:10_000_000)};XCTAssertNil(observed)}
    func testCustomTopInsetSurvivesAddingChangingAndRemovingTheExtension(){let r = ExtendedScreen(),n = make(r);r.additionalSafeAreaInsets.top = 7;n.setNavigationBarExtensionView(UIView(),forHeight:40);XCTAssertEqual(r.additionalSafeAreaInsets.top,47);n.setNavigationBarExtensionView(UIView(),forHeight:20);XCTAssertEqual(r.additionalSafeAreaInsets.top,27);n.setNavigationBarExtensionView(nil);XCTAssertEqual(r.additionalSafeAreaInsets.top,7)}
    func testWillShowDoesNotApplyExtensionInsetTwice(){let r = ExtendedScreen(),n = make(r);n.setNavigationBarExtensionView(UIView(),forHeight:40);n.navigationController(n,willShow:r,animated:false);n.navigationController(n,willShow:r,animated:false);XCTAssertEqual(r.additionalSafeAreaInsets.top,40)}
    func testExistingSideAndBottomSafeAreaInsetsSurviveExtensionChange(){let r = ExtendedScreen(),n = make(r);r.additionalSafeAreaInsets = UIEdgeInsets(top:0,left:4,bottom:8,right:6);n.setNavigationBarExtensionView(UIView(),forHeight:40);XCTAssertEqual(r.additionalSafeAreaInsets,UIEdgeInsets(top:40,left:4,bottom:8,right:6))}
}
private final class ExtendedScreen:UIViewController,ExtensibleBarProvider {var shouldExtendNavigationBar = true;var appeared = false;override func viewDidAppear(_ animated:Bool){super.viewDidAppear(animated);appeared = true}}
private final class ExtendedDelegate:NSObject,UINavigationControllerDelegate {var screens = [UIViewController](),animations = [Bool]();func navigationController(_ navigationController:UINavigationController,willShow viewController:UIViewController,animated:Bool){screens.append(viewController);animations.append(animated)};func navigationController(_ navigationController:UINavigationController,didShow viewController:UIViewController,animated:Bool){} }
