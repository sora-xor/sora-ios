import UIKit
import SoraUIKit
import CommonWallet
import RobinHood

protocol ConfirmPassphraseViewModelProtocol {
    func setup()
}

final class ConfirmPassphraseViewModel {
    var setupItem: (([SoramitsuTableViewItemProtocol]) -> Void)?

    var wireframe: ConfirmPassphraseyWireframeProtocol?
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

    func didCompleteConfirmation() {
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
