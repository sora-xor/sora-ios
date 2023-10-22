// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import UIKit

public protocol ExtensibleBarProvider {
    var shouldExtendNavigationBar: Bool { get }
}

public class ExtensibleBarNavigationController: UINavigationController {

    // isTranslucent property does not work with iOS 12. Use this property
    // to set isTranslucent to the custom navigationBar with iOS 12
    @available(iOS, deprecated: 13.0, message: "Use appearance instead of this property")
    public static var isTranslucentBar: Bool = true

    private var navBarExtensionView: UIView?
    private lazy var navBarExtensionContainerView: UIView = self.initNavbarExtensionContainerView()

    private var navBarExtensionContainerBottomConstraint: NSLayoutConstraint?
    private var navBarExtensionBottomConstraint: NSLayoutConstraint?
    private var navBarExtensionTopConstraint: NSLayoutConstraint?
    private var toolbarBottomConstraint: NSLayoutConstraint?

    private var navBarAdditionalSize: CGFloat = 0 {
        didSet {
            let needsToShowExtension = self.needsToShowExtension(for: topViewController)
            navBarExtensionBottomConstraint?.constant = !needsToShowExtension ? -navBarAdditionalSize : 0
            navBarExtensionTopConstraint?.constant = -navBarAdditionalSize
            navBarExtensionContainerBottomConstraint?.constant = navBarAdditionalSize
            toolbarBottomConstraint?.constant = -navBarAdditionalSize
            topViewController?.additionalSafeAreaInsets = extensionSafeAreaInsets
        }
    }

    /// Extension view additional safe area insets
    private var extensionSafeAreaInsets: UIEdgeInsets {
        let needsToShowExtension = self.needsToShowExtension(for: topViewController)
        return needsToShowExtension ?
            UIEdgeInsets(top: navBarAdditionalSize, left: 0, bottom: 0, right: 0) : .zero
    }

    public var extensionAppearingIsAnimatable = false

    /// All calls from `UINavigationControllerDelegate` methods are forwarded to this object
    public weak var navigationControllerDelegate: UINavigationControllerDelegate? {
        didSet {
            // Make the navigationController reevaluate respondsToSelector
            // for UINavigationControllerDelegate methods
            delegate = nil
            delegate = self
        }
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }

    // MARK: - NSObject

    override public func responds(to aSelector: Selector!) -> Bool {
        if shouldForwardSelector(aSelector) {
            return navigationControllerDelegate?.responds(to: aSelector) ?? false
        }
        return super.responds(to: aSelector)
    }

    override public func forwardingTarget(for aSelector: Selector!) -> Any? {
        if shouldForwardSelector(aSelector) {
            return navigationControllerDelegate
        }
        return super.forwardingTarget(for: aSelector)
    }

    // MARK: - ExtensibleBarNavigationController

    public func setNavigationBarExtensionView(_ view: UIView?, forHeight height: CGFloat = 0) {
        navBarExtensionView?.removeFromSuperview()
        guard let view = view else {
            self.navBarExtensionView = nil
            navBarAdditionalSize = height
            updateShadowImage()
            return
        }
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let toolBar = UIToolbar()
        toolBar.setShadowImage(UIImage(), forToolbarPosition: .any)
        toolBar.isTranslucent = Self.isTranslucentBar
        toolBar.barTintColor = .white

        container.addSubview(toolBar)
        toolBar.translatesAutoresizingMaskIntoConstraints = false
        toolBar.topAnchor.constraint(equalTo: container.topAnchor).isActive = true
        toolBar.bottomAnchor.constraint(equalTo: container.bottomAnchor).isActive = true
        toolBar.leadingAnchor.constraint(equalTo: container.leadingAnchor).isActive = true
        toolBar.trailingAnchor.constraint(equalTo: container.trailingAnchor).isActive = true

        container.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.topAnchor.constraint(equalTo: container.topAnchor).isActive = true
        view.bottomAnchor.constraint(equalTo: container.bottomAnchor).isActive = true
        view.leadingAnchor.constraint(equalTo: container.leadingAnchor).isActive = true
        view.trailingAnchor.constraint(equalTo: container.trailingAnchor).isActive = true

        container.clipsToBounds = true

        navBarExtensionView = container
        navBarExtensionContainerView.addSubview(container)
        container.leadingAnchor.constraint(equalTo: navBarExtensionContainerView.leadingAnchor).isActive = true
        container.trailingAnchor.constraint(equalTo: navBarExtensionContainerView.trailingAnchor).isActive = true

        navBarExtensionTopConstraint = container.topAnchor
            .constraint(equalTo: navBarExtensionContainerView.bottomAnchor, constant: -navBarAdditionalSize)
        navBarExtensionTopConstraint?.isActive = true

        navBarExtensionBottomConstraint = container.bottomAnchor
            .constraint(equalTo: navBarExtensionContainerView.bottomAnchor)
        navBarExtensionBottomConstraint?.isActive = true

        navBarAdditionalSize = height

        updateShadowImage()
    }

    // MARK: - UINavigationController

    override public func pushViewController(_ viewController: UIViewController, animated: Bool) {
        super.pushViewController(viewController, animated: true)
        viewController.additionalSafeAreaInsets = extensionSafeAreaInsets
    }

    // MARK: - Private

    private func setup() {

        delegate = self

        view.backgroundColor = R.color.baseBackground()

        view.addSubview(navBarExtensionContainerView)
        navBarExtensionContainerView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        navBarExtensionContainerBottomConstraint = navBarExtensionContainerView.bottomAnchor
            .constraint(equalTo: navigationBar.bottomAnchor, constant: navBarAdditionalSize)
        navBarExtensionContainerBottomConstraint?.isActive = true
        navBarExtensionContainerView.translatesAutoresizingMaskIntoConstraints = false
        navBarExtensionContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        navBarExtensionContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true

        view.bringSubviewToFront(navigationBar)
    }

    private func initNavbarExtensionContainerView() -> UIView {

        let view = UIView()
        view.isUserInteractionEnabled = false
        view.translatesAutoresizingMaskIntoConstraints = false

        let toolBar = UIToolbar()
        toolBar.setShadowImage(UIImage(), forToolbarPosition: .any)
        toolBar.isTranslucent = Self.isTranslucentBar
        toolBar.barTintColor = .white

        view.addSubview(toolBar)
        toolBar.translatesAutoresizingMaskIntoConstraints = false
        toolBar.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        toolBar.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
        toolBar.topAnchor.constraint(equalTo: view.topAnchor, constant: -40).isActive = true

        toolbarBottomConstraint = toolBar.bottomAnchor
            .constraint(equalTo: view.bottomAnchor, constant: -navBarAdditionalSize)
        toolbarBottomConstraint?.isActive = true

        return view
    }

    private func shouldForwardSelector(_ aSelector: Selector!) -> Bool {
        let description = protocol_getMethodDescription(UINavigationControllerDelegate.self, aSelector, false, true)
        return
            description.name != nil // belongs to UINavigationControllerDelegate
                && class_getInstanceMethod(type(of: self), aSelector) == nil // self does not implement aSelector
    }

    private func needsToShowExtension(for viewController: UIViewController?) -> Bool {
        return navBarExtensionView != nil
        && ((viewController as? ExtensibleBarProvider)?.shouldExtendNavigationBar ?? false)
    }

    private func updateShadowImage() {
        navigationBar.shadowIsHidden = true
    }
}

extension ExtensibleBarNavigationController: UINavigationControllerDelegate {

    // MARK: - UINavigationControllerDelegate

    public func navigationController(_ navigationController: UINavigationController,
                                     willShow viewController: UIViewController, animated: Bool) {

        navigationControllerDelegate?.navigationController?(
            navigationController, willShow: viewController, animated: animated
        )

        let needsToShowExtension = self.needsToShowExtension(for: viewController)
        updateShadowImage()

        navBarExtensionContainerView.isUserInteractionEnabled = needsToShowExtension
        navBarExtensionBottomConstraint?.constant = !needsToShowExtension ? -navBarAdditionalSize : 0

        if extensionAppearingIsAnimatable && animated {
            let previousHeightConstraintConstant = navBarExtensionBottomConstraint?.constant ?? 0
            let animationBlock: (UIViewControllerTransitionCoordinatorContext) -> Void = { [weak self] _ in
                self?.navBarExtensionContainerView.layoutIfNeeded()
            }
            transitionCoordinator?.animate(alongsideTransition: animationBlock) { [weak self] context in
                if context.isCancelled {
                    self?.navBarExtensionBottomConstraint?.constant = previousHeightConstraintConstant
                }
            }
        } else {
            navBarExtensionContainerView.layoutIfNeeded()
        }
    }
}
