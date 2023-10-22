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

struct AlertPresentableAction {
    enum Style {
        case normal
        case destructive
        case cancel
    }

    var title: String
    var handler: (() -> Void)?
    var style: Style

    init(title: String, style: Style = .normal, handler: @escaping () -> Void) {
        self.title = title
        self.handler = handler
        self.style = style
    }

    init(title: String, style: Style = .normal) {
        self.title = title
        self.style = style
    }
}

struct AlertPresentableViewModel {
    let title: String?
    let message: String?
    let actions: [AlertPresentableAction]
    let closeAction: String?
}

protocol AlertPresentable: AnyObject {
    func present(message: String?, title: String?,
                 closeAction: String?,
                 from view: ControllerBackedProtocol?)
    
    func present(message: String?, title: String?,
                 closeAction: String?,
                 from view: ControllerBackedProtocol?,
                 completion: @escaping () -> Void)

    func present(viewModel: AlertPresentableViewModel,
                 style: UIAlertController.Style,
                 from view: ControllerBackedProtocol?)
}

extension AlertPresentableAction.Style {
    var uialertStyle: UIAlertAction.Style {
        switch self {
        case .normal:
            return .default
        case .cancel:
            return .cancel
        case .destructive:
            return .destructive
        }
    }
}

extension AlertPresentable {
    func present(message: String?, title: String?,
                 closeAction: String?,
                 from view: ControllerBackedProtocol?) {

        var currentController = view?.controller

        if currentController == nil {
            currentController = UIApplication.shared.delegate?.window??.rootViewController
        }

        guard let controller = currentController else {
            return
        }

        UIAlertController.present(message: message,
                                  title: title,
                                  closeAction: closeAction,
                                  with: controller)
    }
    
    func present(message: String?, title: String?,
                 closeAction: String?,
                 from view: ControllerBackedProtocol?,
                 completion: @escaping () -> Void) {

        var currentController = view?.controller

        if currentController == nil {
            currentController = UIApplication.shared.delegate?.window??.rootViewController
        }

        guard let controller = currentController else {
            return
        }

        UIAlertController.present(message: message,
                                  title: title,
                                  closeAction: closeAction,
                                  with: controller,
                                  completion: completion)
    }

    func present(viewModel: AlertPresentableViewModel,
                 style: UIAlertController.Style,
                 from view: ControllerBackedProtocol?) {

        var currentController = view?.controller

        if currentController == nil {
            currentController = UIApplication.shared.delegate?.window??.rootViewController
        }

        guard let controller = currentController else {
            return
        }

        let alertView = UIAlertController(title: viewModel.title,
                                          message: viewModel.message,
                                          preferredStyle: style)

        viewModel.actions.forEach { action in
            let alertAction = UIAlertAction(title: action.title, style: action.style.uialertStyle) { _ in
                action.handler?()
            }

            alertView.addAction(alertAction)
        }

        if let closeAction = viewModel.closeAction {
            let action = UIAlertAction(title: closeAction,
                                       style: .cancel,
                                       handler: nil)
            alertView.addAction(action)
        }

        controller.present(alertView, animated: true, completion: nil)
    }
}

extension UIAlertController {
    public static func present(message: String?, title: String?,
                               closeAction: String?, with presenter: UIViewController, completion: (() -> Void)? = nil) {
        let alertView = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let action = UIAlertAction(title: closeAction, style: .cancel, handler: { _ in
            completion?()
        })
        alertView.addAction(action)
        presenter.present(alertView, animated: true, completion: nil)
    }
}
