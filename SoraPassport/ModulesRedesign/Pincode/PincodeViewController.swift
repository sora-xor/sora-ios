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

    /// The sensor this device unlocks with, read when the unlock key is shown.
    var biometryType: () -> AvailableBiometryType = { BiometryAuth().availableBiometryType }

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
        label.sora.dynamicTextStyle = .headline
        label.sora.textColor = .fgPrimary
        label.sora.alignment = .center
        label.sora.numberOfLines = 0
        label.sora.lineBreakMode = .byWordWrapping
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
    
    private var circleViews: [PincodeDotView] = []
    private var enteredDigits = 0

    /// The planet in its ring, where the launch flight sets it down. The ring is the lock: each digit
    /// draws one more of its circles. Screens too short for it and the title both go without.
    let emblemView = SacredEmblemView()
    private var hasEntered = false

    // One page or two, by the window's size (see `layoutPages`).
    private var stackedConstraints: [NSLayoutConstraint] = []
    private var pagedConstraints: [NSLayoutConstraint] = []
    private(set) var isPaged = false
    private lazy var pagedContainerTrailing = containerView.trailingAnchor.constraint(equalTo: view.leadingAnchor)
    private lazy var pagedNumpadCentreX = numpadView.centerXAnchor.constraint(equalTo: view.leadingAnchor)
    private lazy var pagedTitleCentreY = titleLabel.centerYAnchor.constraint(equalTo: view.topAnchor)

    var cooldownTimerFactory: (TimeInterval, @escaping @Sendable (Timer) -> Void) -> Timer = { interval, block in
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true, block: block)
    }
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

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        guard !hasEntered else { return }
        hasEntered = true
        guard FxPolicy.current.litMotion else { return }
        LitMotion.rise(titleLabel, by: 8)
        LitMotion.rise(circlesStackView, by: 8, after: 0.03)
        LitMotion.rise(numpadView, by: 18, after: 0.05)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        layoutPages()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutEmblem()
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
        
        view.addSubview(emblemView)
        view.addSubview(containerView)
        view.addSubview(numpadView)
        
        containerView.addSubviews(titleLabel, circlesStackView)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),

            numpadView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 48),
            numpadView.heightAnchor.constraint(equalToConstant: 368),
            
            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            titleLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            
            circlesStackView.leadingAnchor.constraint(greaterThanOrEqualTo: containerView.leadingAnchor, constant: 10),
            circlesStackView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            circlesStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
        ])

        // One page, as on every phone: the title and the dots above the keypad.
        stackedConstraints = [
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.bottomAnchor.constraint(equalTo: numpadView.topAnchor),
            numpadView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            numpadView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -18),
            titleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
        ]
        // Two pages (an unfolded screen in landscape): the emblem, the title and the dots on the
        // left page, the keypad in the middle of the right one. Nothing sits on the fold.
        pagedConstraints = [
            pagedContainerTrailing,
            containerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            pagedNumpadCentreX,
            numpadView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            pagedTitleCentreY,
        ]
        NSLayoutConstraint.activate(stackedConstraints)
    }

    /// Chooses one page or two for the window's size. The digits entered so far, the title and a
    /// cooldown are untouched: only the constraints change when the window does.
    func layoutPages() {
        let pages = WalletDisplay.pages(in: view)
        if (pages != nil) != isPaged {
            isPaged = pages != nil
            NSLayoutConstraint.deactivate(isPaged ? stackedConstraints : pagedConstraints)
            NSLayoutConstraint.activate(isPaged ? pagedConstraints : stackedConstraints)
        }
        guard let pages else { return }
        let place = SacredEmblemLayout.pagedPinPlacement(page: pages.left, safeArea: view.safeAreaInsets)
        pagedContainerTrailing.constant = pages.left.maxX
        pagedNumpadCentreX.constant = pages.right.midX
        pagedTitleCentreY.constant = SacredEmblemLayout.pagedPinTitleCentreY(under: place)
    }

    func emblemPlacement() -> SacredEmblemLayout.Placement? {
        if let pages = WalletDisplay.pages(in: view) {
            return SacredEmblemLayout.pagedPinPlacement(page: pages.left, safeArea: view.safeAreaInsets)
        }
        return SacredEmblemLayout.pinPlacement(bounds: view.bounds, safeArea: view.safeAreaInsets)
    }

    func layoutEmblem() {
        // Once unlocking has taken it across to the home it is no longer this screen's to place.
        guard emblemView.superview === view else { return }
        guard let place = emblemPlacement() else {
            emblemView.isHidden = true
            return
        }
        emblemView.frame = place.frame
        // A title that wraps grows upwards into the emblem's room; the words win.
        emblemView.isHidden = place.frame.maxY > titleLabel.convert(titleLabel.bounds, to: view).minY - 6
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
        circlesStackView.isAccessibilityElement = true
        circlesStackView.accessibilityIdentifier = AccessibilityId.inputField
        numpadView.setupKeysAccessibilityIdWith(format: AccessibilityId.keyPrefix)
        numpadView.setupBackspace(accessibilityId: AccessibilityId.backspace)
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
        timer?.invalidate()
        timer = nil
        self.cooldownDate = date
        guard date.timeIntervalSinceNow > 0 else {
            updateTitleLabelState()
            numpadView.isUserInteractionEnabled = true
            return
        }
        numpadView.isUserInteractionEnabled = false
        titleLabel.sora.textColor = .fgPrimary

        let timer = cooldownTimerFactory(1.0, { [weak self] _ in
            guard let self = self else { return }

            let secondsLeft = self.cooldownDate.timeIntervalSinceNow

            let cooldownText = self.formatter.string(from: secondsLeft) ?? ""
            self.titleLabel.sora.text = R.string.localizable.pincodeLockedTitle(cooldownText, preferredLanguages: .currentLocale)

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
        // The unlock key shows the sensor this device has: a fingerprint where it is Touch ID.
        if enabled { numpadView.setBiometry(biometryType()) }
        numpadView.accessoryButton.alpha = enabled ? 1 : 0
    }
    
    func updatePinCodeSymbolsCount(with count: Int) {
        circlesStackView.removeArrangedSubviews()
        circleViews = []
        for _ in 0..<count {
            let view = PincodeDotView()
            view.widthAnchor.constraint(equalToConstant: 24).isActive = true
            view.heightAnchor.constraint(equalToConstant: 24).isActive = true
            view.isAccessibilityElement = false
            circlesStackView.addArrangedSubview(view)
            circleViews.append(view)
        }
        updateInputedCircles(with: 0)
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
        enteredDigits = min(max(count, 0), circleViews.count)
        circlesStackView.accessibilityValue = R.string.localizable.neonPinCount(
            enteredDigits, circleViews.count, preferredLanguages: .currentLocale
        )
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .announcement, argument: circlesStackView.accessibilityValue)
        }
        let palette = SoramitsuUI.shared.theme.palette
        for (index, view) in circleViews.enumerated() {
            view.setFilled(index < count, color: palette.color(.accentPrimary))
        }
        emblemView.setShare(circleViews.isEmpty ? 0 : CGFloat(enteredDigits) / CGFloat(circleViews.count),
                            animated: true)
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
        let errorColor = SoramitsuUI.shared.theme.palette.color(.statusError)
        circleViews.forEach { $0.setFilled(true, color: errorColor) }
        emblemView.showError(color: errorColor)
        if FxPolicy.current.reduceMotion {
            circlesStackView.transform = .identity
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { completion(true) }
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            return
        }
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
    
    func askBiometryPermission() {
        let title = R.string.localizable.biometryAuthAccess(preferredLanguages: .currentLocale)
        let message = R.string.localizable.askBiometryAccessSetting(preferredLanguages: .currentLocale)
        askOpenApplicationSettings(with: message, title: title, from: self, locale: Locale.current)
    }
}

extension PincodeViewController: SoramitsuNumpadDelegate {
    func numpadView(_ view: SoramitsuNumpadView, didSelectNumAt index: Int) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        presenter.padButtonTapped(with: "\(index)")
    }
    
    func numpadViewDidSelectBackspace(_ view: SoramitsuNumpadView) {
        presenter.deleteButtonTapped()
    }
    
    func numpadViewDidSelectAccessoryControl(_ view: SoramitsuNumpadView) {
        presenter.activateBiometricAuth()
    }

    func numpadViewDidClearInput(_ view: SoramitsuNumpadView) {
        for _ in 0..<enteredDigits { presenter.deleteButtonTapped() }
    }
}

/// One PIN digit: a small well pressed into the page; a lit bead drops into it when the digit is entered.
final class PincodeDotView: SoramitsuView {
    private let well = LitWellLayer()
    private let bead = LitLEDView(diameter: 15)
    private(set) var isFilled = false

    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        sora.useAutoresizingMask = false
        well.cornerRadiusValue = 12
        well.depth = 2
        layer.addSublayer(well)
        bead.isHidden = true
        bead.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bead)
        NSLayoutConstraint.activate([
            bead.centerXAnchor.constraint(equalTo: centerXAnchor),
            bead.centerYAnchor.constraint(equalTo: centerYAnchor),
            bead.widthAnchor.constraint(equalToConstant: 15),
            bead.heightAnchor.constraint(equalToConstant: 15)
        ])
    }

    func setFilled(_ filled: Bool, color: UIColor) {
        let appeared = filled && !isFilled
        isFilled = filled
        bead.setColor(color)
        bead.isHidden = !filled
        guard appeared, LitMotion.allowed else { return }
        bead.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
        UIView.animate(withDuration: 0.34, delay: 0, usingSpringWithDamping: 0.55, initialSpringVelocity: 0,
                       options: [.allowUserInteraction]) {
            self.bead.transform = .identity
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        well.place(in: bounds)
    }
}
