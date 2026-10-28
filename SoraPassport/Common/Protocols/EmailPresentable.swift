// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import MessageUI

typealias EmailComposerCompletion = (Bool) -> Void

protocol EmailPresentable {
    @discardableResult
    func writeEmail(with message: SocialMessage,
                    from view: ControllerBackedProtocol,
                    completionHandler: EmailComposerCompletion?) -> Bool
}

extension EmailPresentable {
    @discardableResult
    func writeEmail(with message: SocialMessage,
                    from view: ControllerBackedProtocol,
                    completionHandler: EmailComposerCompletion?) -> Bool {
        return MFEmailPresenter.shared.presentComposer(with: message,
                                                       from: view,
                                                       completionBlock: completionHandler)
    }
}

private class MFEmailPresenter: NSObject, MFMailComposeViewControllerDelegate {
    static let shared = MFEmailPresenter()

    private(set) var completionBlock: EmailComposerCompletion?
    private(set) var message: SocialMessage?

    private override init() {}

    func presentComposer(with message: SocialMessage,
                         from view: ControllerBackedProtocol,
                         completionBlock: EmailComposerCompletion?) -> Bool {
        guard self.message == nil else {
            return false
        }

        guard MFMailComposeViewController.canSendMail() else {
            return false
        }

        self.message = message
        self.completionBlock = completionBlock

        let emailComposer = MFMailComposeViewController()

        if let subject = message.subject {
            emailComposer.setSubject(subject)
        }

        if let body = message.body {
            emailComposer.setMessageBody(body, isHTML: false)
        }

        if message.recepients.count > 0 {
            emailComposer.setToRecipients(message.recepients)
        }

        emailComposer.mailComposeDelegate = self

        view.controller.present(emailComposer,
                                animated: true,
                                completion: nil)

        return true
    }

    func mailComposeController(_ controller: MFMailComposeViewController,
                               didFinishWith result: MFMailComposeResult,
                               error: Error?) {

        controller.presentingViewController?.dismiss(animated: true) {
            let completionBlock = self.completionBlock

            self.clearContext()

            switch result {
            case .cancelled, .failed:
                completionBlock?(false)
            case .saved, .sent:
                completionBlock?(true)
            @unknown default:
                completionBlock?(false)
            }
        }
    }

    private func clearContext() {
        message = nil
        completionBlock = nil
    }
}
