/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import Foundation

protocol InvitationInputViewProtocol: ControllerBackedProtocol, LoadableViewProtocol, ErrorPresentable {}

protocol InvitationInputPresenterProtocol: class {
    func process(viewModel: CodeInputViewModelProtocol)
}

protocol InvitationInputWireframeProtocol: AlertPresentable, ErrorPresentable {
    func continueOnboarding(from view: InvitationInputViewProtocol?,
                            with applicationForm: ApplicationFormData?,
                            invitationCode: String)
}

protocol InvitationInputInteractorProtocol: class {
    var isProcessing: Bool { get }

    func process(code: String)
}

protocol InvitationInputInteractorOutputProtocol: class {
    func didStartProcessing(code: String)
    func didSuccessfullProcess(code: String, received applicationForm: ApplicationFormData?)
    func didReceiveProcessing(error: Error, for code: String)
}

protocol InvitationInputViewFactoryProtocol {
    static func createQRInputView() -> InvitationInputViewProtocol?
    static func createManualInputView() -> InvitationInputViewProtocol?
}
