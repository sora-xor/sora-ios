import UIKit

typealias AuthorizationCompletionBlock = (Bool) -> Void

protocol AuthorizationPresentable: ScreenAuthorizationWireframeProtocol {
    func authorize(animated: Bool,
                   cancellable: Bool,
                   inView: UINavigationController?,
                   with completionBlock: @escaping AuthorizationCompletionBlock)
}

protocol AuthorizationAccessible {
    var isAuthorizing: Bool { get }
}

private let authorization = UUID().uuidString

private struct AuthorizationConstants {
    static var completionBlockKey: String = "co.jp.sora.auth.delegate"
    static var authorizationViewKey: String = "co.jp.sora.auth.view"
    static var inViewKey: String = "co.jp.sora.auth.inView"
}

extension AuthorizationAccessible {
    var isAuthorizing: Bool {
        let view = objc_getAssociatedObject(authorization,
                                            &AuthorizationConstants.authorizationViewKey)
            as? PinSetupViewProtocol

        return view != nil
    }
}

extension AuthorizationPresentable {
    private var completionBlock: AuthorizationCompletionBlock? {
        get {
            return objc_getAssociatedObject(authorization, &AuthorizationConstants.completionBlockKey)
                as? AuthorizationCompletionBlock
        }

        set {
            objc_setAssociatedObject(authorization,
                                     &AuthorizationConstants.completionBlockKey,
                                     newValue,
                                     .OBJC_ASSOCIATION_RETAIN)
        }
    }

    private var authorizationView: PinSetupViewProtocol? {
        get {
            return objc_getAssociatedObject(authorization, &AuthorizationConstants.authorizationViewKey)
                as? PinSetupViewProtocol
        }

        set {
            objc_setAssociatedObject(authorization,
                                     &AuthorizationConstants.authorizationViewKey,
                                     newValue,
                                     .OBJC_ASSOCIATION_RETAIN)
        }
    }

    private var inView: UINavigationController? {
        get {
            return objc_getAssociatedObject(authorization, &AuthorizationConstants.inViewKey)
                as? UINavigationController
        }

        set {
            objc_setAssociatedObject(authorization,
                                     &AuthorizationConstants.inViewKey,
                                     newValue,
                                     .OBJC_ASSOCIATION_RETAIN)
        }
    }

    private var isAuthorizing: Bool {
        return authorizationView != nil
    }
}

extension AuthorizationPresentable {
    func authorize(animated: Bool, with completionBlock: @escaping AuthorizationCompletionBlock) {
        authorize(animated: animated, cancellable: false, inView: nil, with: completionBlock)
    }

    func authorize(animated: Bool,
                   cancellable: Bool,
                   inView: UINavigationController?,
                   with completionBlock: @escaping AuthorizationCompletionBlock) {

        guard let presentingController = UIApplication.shared.keyWindow?
            .rootViewController?.topModalViewController else {
            return
        }

        guard let authorizationView = PinViewFactory.createScreenAuthorizationView(
            with: self,
            cancellable: cancellable)
        else {
            completionBlock(false)
            return
        }

        self.completionBlock = completionBlock
        self.authorizationView = authorizationView
        self.inView = inView

        authorizationView.controller.modalTransitionStyle = .crossDissolve
        authorizationView.controller.modalPresentationStyle = .fullScreen

        if let inView = inView {
            authorizationView.controller.hidesBottomBarWhenPushed = true
            inView.pushViewController(authorizationView.controller, animated: animated)
        } else {
            presentingController.present(authorizationView.controller, animated: animated, completion: nil)
        }
    }

    func removeExistingAuthViewIfPresented(completion: @escaping ()->()) {
        if let authorizationView = authorizationView {
            dismissAuthorizationView(authorizationView, completionBlock: completionBlock, result: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                completion()
            }
        } else {
            completion()
        }
    }
}

extension AuthorizationPresentable {
    func showAuthorizationCompletion(with result: Bool) {
        guard let completionBlock = completionBlock else {
            return
        }

        self.completionBlock = nil

        guard let authorizationView = authorizationView else {
            return
        }

        dismissAuthorizationView(authorizationView, completionBlock: completionBlock, result: result)
    }

    func dismissAuthorizationView(_ authorizationView:  PinSetupViewProtocol, completionBlock: AuthorizationCompletionBlock?, result: Bool) {
        if let inView = self.inView {

            completionBlock?(result)
            let controllerToRemove = inView.viewControllers.remove(at: 1)
            self.authorizationView?.controller.dismiss(animated: false)

            self.authorizationView = nil
            self.inView = nil

        } else {
            authorizationView.controller.presentingViewController?.dismiss(animated: true) {
                self.authorizationView = nil
                completionBlock?(result)
            }
        }
    }
}
