import SoraFoundation
import SoraKeystore
import SoraUIKit

protocol ProfileLoginPresenterProtocol: AnyObject {
    var view: ProfileLoginView? { get set }

    func reload()
}


final class ProfileLoginPresenter: ProfileLoginPresenterProtocol, AuthorizationPresentable {
    weak var view: ProfileLoginView?

    func reload() {
        let model = createModel()
        view?.update(model: model)
    }

    private func createModel() -> ProfileLoginModel {
        var sections: [SoramitsuTableViewSection] = []
        sections.append(firstSection())
        return ProfileLoginModel(title: R.string.localizable.settingsLoginTitle(preferredLanguages: languages),
                             sections: sections)
    }

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

    func applyLocalization() {
        let model = createModel()
        view?.update(model: model)
    }
}
