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
