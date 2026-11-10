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
import SoraFoundation
import SSFUtils
import RobinHood

enum AccountImportContext: String {
    case sourceType
    case cryptoType
    case addressType
}

final class AccountImportPresenter {
    static let maxMnemonicLength: Int = 250
    static let maxMnemonicSize: Int = 24
    static let maxRawSeedLength: Int = 66
    static let maxKeystoreLength: Int = 4000

    weak var view: AccountImportViewProtocol?
    var wireframe: AccountImportWireframeProtocol!
    var interactor: AccountImportInteractorInputProtocol!

    private(set) var metadata: AccountImportMetadata?

    private(set) var selectedSourceType: AccountImportSource?
    private(set) var selectedCryptoType: CryptoType?
    private(set) var selectedNetworkType: Chain?
    private var isRawSeedWarningShown: Bool = false
    private var expectedAddress: String?
    private struct ValidationReview: Equatable {
        let sourceType: AccountImportSource
        let cryptoType: CryptoType
        let networkType: Chain
        let source: String
        let username: String
        let password: String
        let derivationPath: String
        let expectedAddress: String?
    }
    private var pendingValidation: (id: UUID, review: ValidationReview)?

    private func currentValidationReview() -> ValidationReview? {
        guard let sourceType = selectedSourceType, let cryptoType = selectedCryptoType,
              let networkType = selectedNetworkType, let sourceViewModel, let usernameViewModel else { return nil }
        // A keystore declares its signing scheme. Bind validation to that
        // declaration before validateAccount updates the visible selection.
        let reviewedCrypto: CryptoType
        if sourceType == .keystore,
           let data = sourceViewModel.inputHandler.value.data(using: .utf8),
           let definition = try? JSONDecoder().decode(KeystoreDefinition.self, from: data),
           let declared = try? AccountImportJsonFactory().createInfo(from: definition).cryptoType {
            reviewedCrypto = declared
        } else {
            reviewedCrypto = cryptoType
        }
        return ValidationReview(sourceType: sourceType, cryptoType: reviewedCrypto, networkType: networkType,
                                source: sourceViewModel.inputHandler.value, username: usernameViewModel.inputHandler.value,
                                password: passwordViewModel?.inputHandler.value ?? "",
                                derivationPath: derivationPathViewModel?.inputHandler.value ?? "", expectedAddress: expectedAddress)
    }

    private(set) var sourceViewModel: InputViewModelProtocol?
    private(set) var usernameViewModel: InputViewModelProtocol?
    private(set) var passwordViewModel: InputViewModelProtocol?
    private(set) var derivationPathViewModel: InputViewModelProtocol?
    private let config: ApplicationConfigProtocol

    private lazy var jsonDeserializer = JSONSerialization()
    
    init(sourceType: AccountImportSource? = nil, config: ApplicationConfigProtocol) {
        self.selectedSourceType = sourceType
        self.config = config
    }

    private func applySourceType(_ value: String = "", preferredInfo: AccountImportPreferredInfo? = nil) {
        guard let selectedSourceType = selectedSourceType, let metadata = metadata else {
            return
        }

        if let preferredInfo = preferredInfo {
            selectedCryptoType = preferredInfo.cryptoType

            if let preferredNetwork = preferredInfo.networkType,
               metadata.availableNetworks.contains(preferredNetwork) {
                selectedNetworkType = preferredInfo.networkType
            } else {
                selectedNetworkType = metadata.defaultNetwork
            }

        } else {
            selectedCryptoType = selectedCryptoType ?? metadata.defaultCryptoType
            selectedNetworkType = selectedNetworkType ?? metadata.defaultNetwork
        }

        view?.setSource(type: selectedSourceType)

        applySourceTextViewModel(value)

        let username = preferredInfo?.username ?? ""
        applyUsernameViewModel(username)
        applyPasswordViewModel()
        applyAdvanced(preferredInfo)

        if let preferredInfo = preferredInfo {
            showUploadWarningIfNeeded(preferredInfo)
        }
    }

    private func applySourceTextViewModel(_ value: String = "") {
        guard let selectedSourceType = selectedSourceType else {
            return
        }

        let viewModel: InputViewModelProtocol

        let locale = localizationManager?.selectedLocale ?? Locale.current

        switch selectedSourceType {
        case .mnemonic:
            let placeholder = R.string.localizable
                .recoveryMnemonicPassphrase(preferredLanguages: locale.rLanguages)
            let inputHandler = InputHandler(value: value,
                                            maxLength: AccountImportPresenter.maxMnemonicLength,
                                            validCharacterSet: CharacterSet.englishMnemonic,
                                            predicate: NSPredicate.notEmpty,
                                            processor: MneminicProcessor(),
                                            normalizer: MneminicProcessor())
            viewModel = InputViewModel(inputHandler: inputHandler, placeholder: placeholder)
        case .seed:
            let placeholder: String = R.string.localizable.recoveryInputRawSeedHint(preferredLanguages: locale.rLanguages)
            let inputHandler = InputHandler(
                value: value,
                maxLength: AccountImportPresenter.maxRawSeedLength,
                predicate: NSPredicate.seed
            )
            viewModel = InputViewModel(inputHandler: inputHandler, placeholder: placeholder)
        default: viewModel = InputViewModel(inputHandler: InputHandler(value: value))
        }

        sourceViewModel = viewModel

        view?.setSource(viewModel: viewModel)
    }

    private func applyUsernameViewModel(_ username: String = "") {
        let processor = ByteLengthProcessor.username
        let processedUsername = processor.process(text: username)

        let inputHandler = InputHandler(value: processedUsername,
                                        required: false,
                                        predicate: NSPredicate.notEmpty,
                                        processor: processor)

        let viewModel = InputViewModel(inputHandler: inputHandler)
        usernameViewModel = viewModel

        view?.setName(viewModel: viewModel)
    }

    private func applyPasswordViewModel() {
        guard let selectedSourceType = selectedSourceType else {
            return
        }

        switch selectedSourceType {
        case .mnemonic, .seed:
            passwordViewModel = nil
        case .keystore:
            let viewModel = InputViewModel(inputHandler: InputHandler(required: false))
            passwordViewModel = viewModel

            view?.setPassword(viewModel: viewModel)
        }
    }

    private func showUploadWarningIfNeeded(_ preferredInfo: AccountImportPreferredInfo) {
        guard let metadata = metadata else {
            return
        }

        if preferredInfo.networkType == nil {
            let locale = localizationManager?.selectedLocale
            let message = "accountImportJsonNoNetwork"//R.string.localizable.accountImportJsonNoNetwork(preferredLanguages: locale?.rLanguages)
            view?.setUploadWarning(message: message)
            return
        }

        if let preferredNetwork = preferredInfo.networkType,
           !metadata.availableNetworks.contains(preferredNetwork) {
            let locale = localizationManager?.selectedLocale ?? Locale.current
            let message = "accountImportWrongNetwork"//R.string.localizable
                //.accountImportWrongNetwork(preferredNetwork.titleForLocale(locale),
                     //                      metadata.defaultNetwork.titleForLocale(locale))
            view?.setUploadWarning(message: message)
            return
        }
    }

    private func applyAdvanced(_ preferredInfo: AccountImportPreferredInfo?) {
        guard let selectedSourceType = selectedSourceType else {
            let locale = localizationManager?.selectedLocale
            let warning = "accountImportJsonNoNetwork"//R.string.localizable.accountImportJsonNoNetwork(preferredLanguages: locale?.rLanguages)
            view?.setUploadWarning(message: warning)
            return
        }

        switch selectedSourceType {
        case .mnemonic, .seed:
            if let selectedCryptoType, let metadata {
                view?.setCryptoType(selectedCryptoType, available: metadata.availableCryptoTypes)
            }
            applyDerivationPathViewModel()
//            applyNetworkTypeViewModel(preferredInfo)
        case .keystore:
//            applyCryptoTypeViewModel(preferredInfo)
            derivationPathViewModel = nil
//            applyNetworkTypeViewModel(preferredInfo)
        }
    }

    private func applyDerivationPathViewModel() {
        guard let cryptoType = selectedCryptoType else {
            return
        }

        guard let sourceType = selectedSourceType else {
            return
        }

        let predicate: NSPredicate
        let placeholder: String

        if cryptoType == .sr25519 {
            if sourceType == .mnemonic {
                predicate = NSPredicate.deriviationPathHardSoftPassword
                placeholder = DerivationPathConstants.hardSoftPasswordPlaceholder
            } else {
                predicate = NSPredicate.deriviationPathHardSoft
                placeholder = DerivationPathConstants.hardSoftPlaceholder
            }
        } else {
            if sourceType == .mnemonic {
                predicate = NSPredicate.deriviationPathHardPassword
                placeholder = DerivationPathConstants.hardPasswordPlaceholder
            } else {
                predicate = NSPredicate.deriviationPathHard
                placeholder = DerivationPathConstants.hardPlaceholder
            }
        }

        let inputHandling = InputHandler(value: derivationPathViewModel?.inputHandler.value ?? "",
                                        required: false, predicate: predicate)

        let viewModel = InputViewModel(inputHandler: inputHandling,
                                       placeholder: placeholder)

        self.derivationPathViewModel = viewModel

        view?.setDerivationPath(viewModel: viewModel)
    }

    private func presentDerivationPathError(sourceType: AccountImportSource,
                                            cryptoType: CryptoType) {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        switch cryptoType {
        case .sr25519:
            if sourceType == .mnemonic {
                _ = wireframe.present(error: AccountCreationError.invalidDerivationHardSoftPassword,
                                      from: view,
                                      locale: locale) { [weak self] in
                    self?.view?.resetFocus()
                }
            } else {
                _ = wireframe.present(error: AccountCreationError.invalidDerivationHardSoft,
                                      from: view,
                                      locale: locale) { [weak self] in
                    self?.view?.resetFocus()
                }
            }

        case .ed25519, .ecdsa:
            if sourceType == .mnemonic {
                _ = wireframe.present(error: AccountCreationError.invalidDerivationHardPassword,
                                      from: view,
                                      locale: locale) { [weak self] in
                    self?.view?.resetFocus()
                }
            } else {
                _ = wireframe.present(error: AccountCreationError.invalidDerivationHard,
                                      from: view,
                                      locale: locale) { [weak self] in
                    self?.view?.resetFocus()
                }
            }
        }
    }

    func validateSourceViewModel() -> Error? {
        guard let viewModel = sourceViewModel, let selectedSourceType = selectedSourceType else {
            return nil
        }

        switch selectedSourceType {
        case .mnemonic:
            return validateMnemonic(value: viewModel.inputHandler.value)
        case .seed:
            return viewModel.inputHandler.completed ? nil : AccountCreateError.invalidSeed
        case .keystore:
            return validateKeystore(value: viewModel.inputHandler.value)
        }
    }

    func validateMnemonic(value: String) -> Error? {
        let mnemonicSize = value.components(separatedBy: CharacterSet.whitespaces).count
        return mnemonicSize > AccountImportPresenter.maxMnemonicSize ?
            AccountCreateError.invalidMnemonicSize : nil
    }

    func validateKeystore(value: String) -> Error? {
        guard let data = value.data(using: .utf8) else {
            return AccountCreateError.invalidKeystore
        }

        do {
            _ = try JSONSerialization.jsonObject(with: data)
            return nil
        } catch {
            return AccountCreateError.invalidKeystore
        }
    }
}

extension AccountImportPresenter: AccountImportPresenterProtocol {

    func setup() {
        interactor.setup()
    }

    func selectCryptoType(_ type: CryptoType) {
        guard metadata?.availableCryptoTypes.contains(type) == true,
              selectedSourceType != .keystore else { return }
        selectedCryptoType = type
        applyAdvanced(nil)
    }
    
    func validateAccount(completion: ((Result<AccountItem?, Swift.Error>?) -> Void)?) {
        guard 
            let sourceType = selectedSourceType,
            let cryptoType = selectedCryptoType,
            let networkType = selectedNetworkType,
            let sourceViewModel = sourceViewModel,
            let usernameViewModel = usernameViewModel else {
            completion?(.failure(ImportAccountError.unexpectedError))
            return
        }
              
        switch sourceType {
        case .mnemonic:
            let mnemonic = sourceViewModel.inputHandler.value
            let username = usernameViewModel.inputHandler.value
            let derivationPath = derivationPathViewModel?.inputHandler.value ?? ""
            let request = AccountImportMnemonicRequest(mnemonic: mnemonic,
                                                       username: username,
                                                       networkType: networkType,
                                                       derivationPath: derivationPath,
                                                       cryptoType: cryptoType,
                                                       expectedAddress: expectedAddress)
            interactor.validateAccountWithMnemonic(request: request, completion: completion)
        case .seed:
            let seed = sourceViewModel.inputHandler.value
            let username = usernameViewModel.inputHandler.value
            let derivationPath = derivationPathViewModel?.inputHandler.value ?? ""
            let request = AccountImportSeedRequest(seed: seed,
                                                   username: username,
                                                   networkType: networkType,
                                                   derivationPath: derivationPath,
                                                   cryptoType: cryptoType)
            interactor.validateAccountWithSeed(request: request, completion: completion)
        case .keystore:
            let keystore = sourceViewModel.inputHandler.value
            guard let data = keystore.data(using: .utf8),
                  let definition = try? JSONDecoder().decode(KeystoreDefinition.self, from: data),
                  let info = try? AccountImportJsonFactory().createInfo(from: definition),
                  let jsonCrypto = info.cryptoType else {
                completion?(.failure(AccountCreateError.invalidKeystore))
                return
            }
            selectedCryptoType = jsonCrypto
            let password = passwordViewModel?.inputHandler.value ?? ""
            let username = usernameViewModel.inputHandler.value
            let request = AccountImportKeystoreRequest(keystore: keystore,
                                                       password: password,
                                                       username: username,
                                                       networkType: networkType,
                                                       cryptoType: jsonCrypto)

            interactor.validateAccountWithKeystore(request: request, completion: completion)
        }
    }

    func proceed() {
        guard
            let selectedSourceType = selectedSourceType,
            let selectedCryptoType = selectedCryptoType,
            let sourceViewModel = sourceViewModel,
            let usernameViewModel = usernameViewModel else {
            return
        }

        if let error = validateSourceViewModel() {
            _ = wireframe.present(error: error,
                                  from: view,
                                  locale: localizationManager?.selectedLocale) { [weak self] in
                self?.view?.resetFocus()
            }
            return
        }

        guard let selectedNetworkType = selectedNetworkType else {
            return
        }
        
        if
            let derivationPathViewModel = derivationPathViewModel,
            !derivationPathViewModel.inputHandler.completed {
            presentDerivationPathError(sourceType: selectedSourceType, cryptoType: selectedCryptoType)
            return
        }
        
        let isShortPhrase = selectedSourceType == .mnemonic &&
            WalletMnemonicWordPolicy.retainedShortWordCounts.contains(
                sourceViewModel.inputHandler.value.split(whereSeparator: { $0.isWhitespace }).count)
        if isShortPhrase && expectedAddress == nil {
            wireframe.requestKnownAddress(from: view) { [weak self] address in
                guard let self, let address else { return }
                self.expectedAddress = address
                self.proceed()
            }
            return
        }
        if !isShortPhrase { expectedAddress = nil }

        guard let review = currentValidationReview(), pendingValidation?.review != review else { return }
        let requestId = UUID()
        pendingValidation = (requestId, review)
        validateAccount { [weak self] result in
            let apply = { [weak self] in
                guard self?.pendingValidation?.id == requestId else { return }
                self?.pendingValidation = nil
                guard self?.currentValidationReview() == review else { return }
            switch result {
            case .success(let existing):
                if let existing, let self, let controller = self.view?.controller {
                    let repairSource: WalletCredentialRepair.Source
                    switch selectedSourceType {
                    case .mnemonic: repairSource = .phrase
                    case .seed: repairSource = .seed
                    case .keystore: repairSource = .json
                    }
                    Task { @MainActor in
                        guard self.currentValidationReview() == review else { return }
                        WalletAccountCapability.presentRepair(account: existing, from: controller,
                            configure: { repair in
                                repair.setSuppliedMaterial(source: repairSource,
                                    text: review.source,
                                    derivationPath: review.derivationPath,
                                    backupPassword: review.password)
                            })
                    }
                    return
                }
                self?.wireframe.proceed(from: self?.view,
                                        sourceType: selectedSourceType,
                                        cryptoType: self?.selectedCryptoType ?? selectedCryptoType,
                                        networkType: selectedNetworkType,
                                        sourceViewModel: sourceViewModel,
                                        usernameViewModel: usernameViewModel,
                                        passwordViewModel: self?.passwordViewModel,
                                        derivationPathViewModel: self?.derivationPathViewModel,
                                        expectedAddress: self?.expectedAddress)
            case .failure(let error):
                self?.didReceiveAccountImport(error: error)
            case .none:
                let error = BaseOperationError.parentOperationCancelled
                self?.didReceiveAccountImport(error: error)
            }
            }
            if Thread.isMainThread { apply() }
            else { DispatchQueue.main.async(execute: apply) }
        }
    }

    func activateURL(_ url: URL) {
        if let view = view {
            wireframe.showWeb(url: url,
                              from: view,
                              style: .modal)
        }
    }
}

extension AccountImportPresenter: AccountImportInteractorOutputProtocol {
    func didReceiveAccountImport(metadata: AccountImportMetadata) {
        self.metadata = metadata
        selectedSourceType = selectedSourceType ?? metadata.defaultSource
        selectedCryptoType = metadata.defaultCryptoType
        selectedNetworkType = metadata.defaultNetwork

        applySourceType()
    }

    func didCompleteAccountImport() {}

    func didReceiveAccountImport(error: Error) {
        expectedAddress = nil
        let locale = localizationManager?.selectedLocale ?? Locale.current

        guard !wireframe.present(error: error, from: view, locale: locale, completion: { [weak self] in
            self?.view?.resetFocus()
        }) else {
            return
        }

        _ = wireframe.present(error: CommonError.undefined,
                              from: view,
                              locale: locale) { [weak self] in
            self?.view?.resetFocus()
        }
    }

    func didSuggestKeystore(text: String, preferredInfo: AccountImportPreferredInfo?) {
        selectedSourceType = .keystore

        applySourceType(text, preferredInfo: preferredInfo)
    }
}

extension AccountImportPresenter: Localizable {
    func applyLocalization() {
        if let view = view, view.isSetup {
            let source = sourceViewModel?.inputHandler.value ?? ""
            let password = passwordViewModel?.inputHandler.value ?? ""
            let preferred = AccountImportPreferredInfo(username: usernameViewModel?.inputHandler.value,
                                                        networkType: selectedNetworkType,
                                                        cryptoType: selectedCryptoType,
                                                        networkTypeConfirmed: true)
            applySourceType(source, preferredInfo: preferred)
            passwordViewModel?.inputHandler.changeValue(to: password)
        }
    }
}
