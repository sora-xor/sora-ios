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
import SoraFoundation
import AudioToolbox

private extension PincodeViewController {
    struct Constants {
        static let navigationBarMargin: CGFloat = 44
        static let pinViewMargin: CGFloat = 60
    }

    struct AccessibilityId {
        static let mainView     = "MainViewAccessibilityId"
        static let inputField   = "InputFieldAccessibilityId"
        static let keyPrefix    = "KeyPrefixAccessibilityId"
        static let backspace    = "BackspaceAccessibilityId"
    }
}

public enum PincodeMode: Int8 {
    case create = 0
    case securedInput = 1
    case unsecuredInput = 2
}


final class PincodeViewController: SoramitsuViewController {
    
    var presenter: PinSetupPresenterProtocol!

    var mode: PincodeMode = .create

    var cancellable: Bool = false

    private let formatter: DateComponentsFormatter = {
        var calendar = Calendar.current
        calendar.locale = LocalizationManager.shared.selectedLocale

        let formatter = DateComponentsFormatter()
        formatter.calendar = calendar
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
    
    var numpadView: SoramitsuNumpadView = {
        let view = SoramitsuNumpadView()
        view.accessoryButton.alpha = 0
        view.backspaceButton.alpha = 0
        return view
    }()
    
    // MARK: - Controls
    
    private let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline2
        label.sora.textColor = .fgPrimary
        label.sora.alignment = .center
        return label
    }()
    
    private let containerView: SoramitsuView = {
        var view = SoramitsuView()
        view.sora.backgroundColor = .custom(uiColor: .clear)
        return view
    }()
    
    private let circlesStackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.sora.axis = .horizontal
        view.sora.distribution = .equalCentering
        view.sora.alignment = .center
        view.spacing = 8
        view.sora.clipsToBounds = false
        view.heightAnchor.constraint(equalToConstant: 24).isActive = true
        return view
    }()
    
    private var circleViews: [SoramitsuView] = []

    private var timer: Timer?
    private var cooldownDate: Date = .init()
    private var errorAnimationDuration: CGFloat = 0.5
    private var errorAnimationAmplitude: CGFloat = 20.0
    private var errorAnimationDamping: CGFloat = 0.4
    private var errorAnimationInitialVelocity: CGFloat = 1.0
    private var errorAnimationAnimationOptions: UIView.AnimationOptions = .curveEaseInOut

    // MARK: - View Setup

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()

        setupLocalization()
        setupAccessibilityIdentifiers()

        presenter.start()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        timer?.invalidate()
        timer = nil
    }
}

private extension PincodeViewController {

    // MARK: - Configure

    func configure() {

        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        
        numpadView.delegate = self
        
        view.addSubview(containerView)
        view.addSubview(numpadView)
        
        containerView.addSubviews(titleLabel, circlesStackView)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: numpadView.topAnchor),
            
            numpadView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 48),
            numpadView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            numpadView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -18),
            numpadView.heightAnchor.constraint(equalToConstant: 368),
            
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            
            circlesStackView.leadingAnchor.constraint(greaterThanOrEqualTo: containerView.leadingAnchor, constant: 10),
            circlesStackView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            circlesStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
        ])
        
    }

    func updateTitleLabelState() {
        guard cooldownDate.timeIntervalSinceNow <= 0 else { return }
        
        if mode == .create {
            titleLabel.sora.text = R.string.localizable.pincodeSetYourPinCode(preferredLanguages: .currentLocale).capitalized
        } else {
            titleLabel.sora.text = R.string.localizable.pincodeEnterPinCode(preferredLanguages: .currentLocale).capitalized
        }
    }

    func setupLocalization() {
        updateTitleLabelState()
    }

    // MARK: - Accessibility

    func setupAccessibilityIdentifiers() {
        view.accessibilityIdentifier = AccessibilityId.mainView
//        pinViewStack.setupInputField(accessibilityId: AccessibilityId.inputField)
//        pinViewStack.numpad.setupKeysAccessibilityIdWith(format: AccessibilityId.keyPrefix)
//        pinViewStack.numpad.setupBackspace(accessibilityId: AccessibilityId.backspace)
    }
}

extension PincodeViewController: PinSetupViewProtocol {
    func resetTitleColor() {
        titleLabel.sora.textColor = .fgPrimary
    }
    
    func showLastChanceAlert() {
        var calendar = Calendar.current
        calendar.locale = LocalizationManager.shared.selectedLocale

        let formatter = DateComponentsFormatter()
        formatter.calendar = calendar
        formatter.unitsStyle = .abbreviated

        let time = formatter.string(from: TimeInterval(60)) ?? ""

        let title = R.string.localizable.pincodeLastTryTitle(preferredLanguages: .currentLocale)
        let message = R.string.localizable.pincodeLastTrySubtitle(time, preferredLanguages: .currentLocale)
        let alertView = UIAlertController(title: title, message: message, preferredStyle: .alert)

        let useAction = UIAlertAction(
            title: R.string.localizable.commonOk(preferredLanguages: .currentLocale),
            style: .default) { (_: UIAlertAction) -> Void in
        }

        alertView.addAction(useAction)

        self.present(alertView, animated: true, completion: nil)
    }

    func blockUserInputUntil(date: Date) {
        self.cooldownDate = date
        numpadView.isUserInteractionEnabled = false

        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { [weak self] _ in
            guard let self = self else { return }

            let secondsLeft = self.cooldownDate.timeIntervalSinceNow

            let cooldownText = self.formatter.string(from: secondsLeft) ?? ""
            self.titleLabel.text = R.string.localizable.pincodeLockedTitle(cooldownText, preferredLanguages: .currentLocale)

            guard secondsLeft <= 0 else { return }
            self.updateTitleLabelState()
            self.numpadView.isUserInteractionEnabled = true
            self.timer?.invalidate()
            self.timer = nil
        })
        self.timer = timer
        RunLoop.current.add(timer, forMode: .common)
    }

    func didRequestBiometryUsage(biometryType: AvailableBiometryType, completionBlock: @escaping (Bool) -> Void) {
        var title: String?
        var message: String?

        switch biometryType {
        case .touchId:
            title = R.string.localizable.askTouchidTitle(preferredLanguages: .currentLocale)
            message = R.string.localizable.askTouchidMessage(preferredLanguages: .currentLocale)
        case .faceId:
            title = R.string.localizable.askFaceidTitle(preferredLanguages: .currentLocale)
            message = R.string.localizable.askFaceidMessage(preferredLanguages: .currentLocale)
        case .none:
            completionBlock(true)
            return
        }

        let alertView = UIAlertController(title: title, message: message, preferredStyle: .alert)

        let useAction = UIAlertAction(
            title: R.string.localizable.commonOk(preferredLanguages: .currentLocale),
            style: .default) { (_: UIAlertAction) -> Void in
            completionBlock(true)
        }

        let skipAction = UIAlertAction(
            title: R.string.localizable.commonDonotallow(preferredLanguages: .currentLocale),
            style: .cancel) { (_: UIAlertAction) -> Void in
            completionBlock(false)
        }

        alertView.addAction(useAction)
        alertView.addAction(skipAction)

        self.present(alertView, animated: true, completion: nil)
    }

    func didReceiveWrongPincode() {}

    func didChangeAccessoryState(enabled: Bool) {
        numpadView.accessoryButton.alpha = enabled ? 1 : 0
    }
    
    func updatePinCodeSymbolsCount(with count: Int) {
        circlesStackView.removeArrangedSubviews()
        circleViews = []
        for _ in 0..<count {
            let view = SoramitsuView()
            view.sora.backgroundColor = .bgSurfaceVariant
            view.sora.cornerRadius = .circle
            view.widthAnchor.constraint(equalToConstant: 24).isActive = true
            view.heightAnchor.constraint(equalToConstant: 24).isActive = true
            circlesStackView.addArrangedSubview(view)
            circleViews.append(view)
        }
    }
    
    func showUpdatePinRequestView() {
        let title = R.string.localizable.pincodeLengthInfoTitle(preferredLanguages: .currentLocale)
        let message = R.string.localizable.pincodeLengthInfoMessage(preferredLanguages: .currentLocale)
        let alertView = UIAlertController(title: title, message: message, preferredStyle: .alert)

        let actionTitle = R.string.localizable.pincodeLengthInfoButtonText(preferredLanguages: .currentLocale)
        let action = UIAlertAction(title: actionTitle, style: .default) { [weak self] (_: UIAlertAction) -> Void in
            self?.presenter.updatePinButtonTapped()
        }

        alertView.addAction(action)

        self.present(alertView, animated: true, completion: nil)
    }
    
    func updateInputedCircles(with count: Int) {
        for (index, view) in circleViews.enumerated() {
            view.sora.backgroundColor = index < count ? .accentPrimary : .bgSurfaceVariant
        }
    }
    
    func setupDeleteButton(isHidden: Bool) {
        numpadView.backspaceButton.alpha = isHidden ? 0 : 1
    }
    
    func setupTitleLabel(text: String) {
        titleLabel.sora.text = text
    }
    
    
    func animateWrongInputError(with completion: @escaping (Bool) -> Void) {
        titleLabel.sora.textColor = .statusError
        titleLabel.sora.text = R.string.localizable.commonWrongPin(preferredLanguages: .currentLocale)
        (circlesStackView.subviews as? [SoramitsuView])?.forEach { $0.sora.backgroundColor = .statusError }
        circlesStackView.transform = CGAffineTransform(translationX: errorAnimationAmplitude, y: 0)
        UIView.animate(withDuration: TimeInterval(errorAnimationDuration),
                       delay: 0,
                       usingSpringWithDamping: errorAnimationDamping,
                       initialSpringVelocity: errorAnimationInitialVelocity,
                       options: errorAnimationAnimationOptions,
                       animations: { [weak self] in
            self?.circlesStackView.transform = CGAffineTransform.identity
        }, completion: completion)
        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
    }
    
    func update(mode: PincodeMode) {
        self.mode = mode
    }
}

extension PincodeViewController: SoramitsuNumpadDelegate {
    func numpadView(_ view: SoramitsuNumpadView, didSelectNumAt index: Int) {
        presenter.padButtonTapped(with: "\(index)")
    }
    
    func numpadViewDidSelectBackspace(_ view: SoramitsuNumpadView) {
        presenter.deleteButtonTapped()
    }
    
    func numpadViewDidSelectAccessoryControl(_ view: SoramitsuNumpadView) {
        presenter.activateBiometricAuth()
    }
}
