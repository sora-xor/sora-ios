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
        guard let view = view else { return }
        authorize(animated: true, cancellable: true, inView: nil) { (isAuthorized) in
            if isAuthorized {
                
                let view: UIViewController?
                let auhorizeView = PinViewFactory.createRedesignPinEditView()
                view = BlurViewController()
                view?.modalPresentationStyle = .overFullScreen
                view?.add(auhorizeView?.controller)

                guard let pinView = view else {
                    return
                }
                pinView.hidesBottomBarWhenPushed = true
                pinView.modalTransitionStyle = .crossDissolve
                pinView.modalPresentationStyle = .overFullScreen

                guard let presentingController = UIApplication.shared.keyWindow?
                    .rootViewController?.topModalViewController else {
                    return
                }

                presentingController.present(pinView, animated: false)
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
