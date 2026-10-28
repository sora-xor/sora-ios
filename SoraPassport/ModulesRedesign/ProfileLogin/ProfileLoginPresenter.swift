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

import SoraFoundation
import SoraKeystore
import SoraUIKit

protocol ProfileLoginPresenterProtocol: AnyObject {
    var view: ProfileLoginView? { get set }

    func reload()
}


final class ProfileLoginPresenter: ProfileLoginPresenterProtocol, AuthorizationPresentable {
    weak var view: ProfileLoginView?

    @MainActor
    func reload() {
        let model = createModel()
        view?.update(model: model)
    }

    @MainActor
    private func createModel() -> ProfileLoginModel {
        var sections: [SoramitsuTableViewSection] = []
        sections.append(firstSection())
        return ProfileLoginModel(title: R.string.localizable.settingsLoginTitle(preferredLanguages: languages),
                             sections: sections)
    }

    @MainActor
    private func firstSection() -> SoramitsuTableViewSection {
        var items: [AppSettingsItem] = []
        let pin = AppSettingsItem(title: R.string.localizable.changePin(preferredLanguages: languages),
                                         picture: .icon(image: R.image.profile.changePin()!,
                                                      color: .fgSecondary),
                                       rightItem: .arrow,
                                        onTap: { self.showPin() }
        )
        let biometryIsOn = SettingsManager.shared.biometryEnabled ?? false
        let biometrySwitcherState: AppSettingsItem.SwitcherState
        biometrySwitcherState = biometryIsOn ? .on : .off
        let biometry = AppSettingsItem(title: R.string.localizable.profileBiometryTitle(preferredLanguages: languages),
                                       picture: .icon(image: R.image.profile.biometry()!,
                                                      color: .fgSecondary),
                                       rightItem: .switcher(state: biometrySwitcherState),
                                       onSwitch: { isOn in
            self.switchBiometry(isOn: isOn)
        }
        )
        items.append(pin)
        items.append(biometry)
        let card = AppSettingsCardItem(title: nil, menuItems: items)
        return SoramitsuTableViewSection(rows: [card])
    }

    @MainActor
    private func showPin() {
        guard let controller = UIApplication.shared.keyWindow?.rootViewController?.topModalViewController else { return }
        WalletPinPrompt.present(on: controller, message: WalletUX.text("Enter your current app PIN to change it.")) { pin in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = Result {
                    let ownerPIN = WalletOwnerPIN(keystore: Keychain(), settings: SettingsManager.shared)
                    return try ownerPIN.authenticateCurrent(pin, currentAccounts: { try WalletAccountAddresses.accounts() })
                }
                DispatchQueue.main.async {
                    switch result {
                    case let .success(authorization):
                        guard let editor = PinViewFactory.createRedesignPinEditView(authorization: authorization) else { return }
                        let view = BlurViewController()
                        view.modalPresentationStyle = .overFullScreen
                        view.add(editor.controller)
                        controller.present(view, animated: false)
                    case let .failure(error):
                        let alert = UIAlertController(title: WalletUX.text("PIN not changed"),
                            message: WalletPinPrompt.message(for: error), preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: WalletUX.text("OK"), style: .default))
                        controller.present(alert, animated: true)
                    }
                }
            }
        }
    }

    private func switchBiometry(isOn: Bool) {
        SettingsManager.shared.biometryEnabled = isOn
    }
}

extension ProfileLoginPresenter: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    @MainActor
    func applyLocalization() {
        let model = createModel()
        view?.update(model: model)
    }
}
