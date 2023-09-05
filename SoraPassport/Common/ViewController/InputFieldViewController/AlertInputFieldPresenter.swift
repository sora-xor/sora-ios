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

final class AlertInputFieldPresenter: NSObject {
    let viewModel: InputFieldViewModelProtocol

    init(viewModel: InputFieldViewModelProtocol) {
        self.viewModel = viewModel
    }

    private weak var doneAction: UIAlertAction?

    func present(from viewController: UIViewController) {
        let alertController = UIAlertController(title: viewModel.title,
                                                message: nil,
                                                preferredStyle: .alert)

        alertController.addTextField { [weak self] textField in
            guard let strongSelf = self else {
                return
            }

            textField.placeholder = strongSelf.viewModel.hint
            textField.delegate = strongSelf
            textField.autocapitalizationType = .none

            textField.addTarget(strongSelf,
                                action: #selector(strongSelf.actionTextChanged(textField:)),
                                for: .editingChanged)
        }

        let cancelAction = UIAlertAction(title: viewModel.cancelActionTitle, style: .cancel) { _ in
            self.viewModel.delegate?.inputFieldDidCancelInput(to: self.viewModel)
        }

        let doneAction = UIAlertAction(title: viewModel.doneActionTitle, style: .default) { _ in
            self.viewModel.delegate?.inputFieldDidCompleteInput(to: self.viewModel)
        }

        alertController.addAction(cancelAction)
        alertController.addAction(doneAction)

        alertController.preferredAction = doneAction

        doneAction.isEnabled = viewModel.isComplete

        self.doneAction = doneAction

        viewController.present(alertController, animated: true, completion: nil)
    }

    @objc private func actionTextChanged(textField: UITextField) {
        if textField.text?.count != viewModel.value.count {
            /*
             * prevent app from crash if text field changes without
             * notifying delegate (like smart replacement)
            */

            textField.text = viewModel.value
        }
    }
}

extension AlertInputFieldPresenter: UITextFieldDelegate {
    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {

        defer {
            doneAction?.isEnabled = viewModel.isComplete
        }

        if !viewModel.didReceive(replacement: string, in: range) {
            textField.text = viewModel.value
            return false
        }

        return true
    }
}
