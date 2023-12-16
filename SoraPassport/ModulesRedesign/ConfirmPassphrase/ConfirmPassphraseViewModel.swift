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
import SoraUIKit
import CommonWallet
import RobinHood

protocol ConfirmPassphraseViewModelProtocol {
    func setup()
}

final class ConfirmPassphraseViewModel {
    var setupItem: (([SoramitsuTableViewItemProtocol]) -> Void)?

    var wireframe: ConfirmPassphraseWireframeProtocol?
    var items: [SoramitsuTableViewItemProtocol] = []
    var view: ConfirmPassphraseViewProtocol?
    var currentStage: Int = 0
    var numbersItem: WordNumberItem?
    var quiz: Quiz?
    let mnemonic: [String]
    var interactor: AccountConfirmInteractorInputProtocol!
    
    init(mnemonic: [String]) {
        self.mnemonic = mnemonic
    }
}

extension ConfirmPassphraseViewModel: ConfirmPassphraseViewModelProtocol {
    func setup() {
        let quiz = Quiz(words: mnemonic)
        self.quiz = quiz

        let numbersItem = WordNumberItem()
        numbersItem.variants = quiz.quizArray[currentStage]
        numbersItem.index = quiz.correctAnswers[currentStage]
        numbersItem.tryHandler = { [weak self] variant in
            guard let self = self, let quiz = self.quiz else { return }
            let correctVariant = self.mnemonic[quiz.correctAnswers[self.currentStage] - 1]
            if variant == correctVariant {
                self.currentStage += 1

                if self.currentStage < quiz.quizArray.count {
                    numbersItem.variants = quiz.quizArray[self.currentStage]
                    numbersItem.index = quiz.correctAnswers[self.currentStage]
                }

                numbersItem.currentStage = self.currentStage
                self.view?.update(items: [numbersItem])
                
                if self.currentStage == 3 {
                    self.interactor.skipConfirmation()
                }
            } else {
                self.showErrorAlert(with: self.mnemonic)
            }
        }
        
        self.numbersItem = numbersItem
        view?.setup(items: [numbersItem])
    }
}

extension ConfirmPassphraseViewModel: AccountConfirmInteractorOutputProtocol {
    func didReceive(words: [String], afterConfirmationFail: Bool) {
        
    }

    func didCompleteConfirmation(for account: AccountItem) {
        wireframe?.proceed(on: view?.controller)
    }

    func didReceive(error: Error) {
        
    }
}

private extension ConfirmPassphraseViewModel {
    func showErrorAlert(with words: [String]) {
        let title = R.string.localizable.passphraseConfirmationErrorTitle(preferredLanguages: .currentLocale)
        let message = R.string.localizable.passphraseConfirmationErrorMessage(preferredLanguages: .currentLocale)
        let closeActionText = R.string.localizable.commonOk(preferredLanguages: .currentLocale)
        
        let closeAction = AlertPresentableAction(title: closeActionText) { [weak self] in
            guard let self = self, let item = self.numbersItem else { return }
            self.currentStage = 0
            let quiz = Quiz(words: words)
            self.quiz = quiz
            self.numbersItem?.variants = quiz.quizArray[self.currentStage]
            self.numbersItem?.index = quiz.correctAnswers[self.currentStage]
            self.numbersItem?.currentStage = self.currentStage
            self.view?.update(items: [item])
        }
        
        let viewModel = AlertPresentableViewModel(title: title, message: message, actions: [closeAction], closeAction: nil)
        wireframe?.present(viewModel: viewModel, style: .alert, from: view)
    }
}
