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

public protocol SoramitsuNumpadDelegate: AnyObject {
    func numpadView(_ view: SoramitsuNumpadView, didSelectNumAt index: Int)
    func numpadViewDidSelectBackspace(_ view: SoramitsuNumpadView)
    func numpadViewDidSelectAccessoryControl(_ view: SoramitsuNumpadView)
    func numpadViewDidClearInput(_ view: SoramitsuNumpadView)
}

public protocol SoramitsuNumpadAccessibilitySupportProtocol: AnyObject {
    func setupKeysAccessibilityIdWith(format: String?)
    func setupBackspace(accessibilityId: String?)
    func setupAccessory(accessibilityId: String?)
}

public class SoramitsuNumpadView: SoramitsuView {

    lazy var buttons: [NeumorphicControl] = {
        (0...9).map { i in
            let view = makeKey()
            view.tag = i
            view.accessibilityLabel = "\(i)"
            let label = SoramitsuLabel()
            label.sora.text = "\(i)"
            label.sora.font = FontType.pinDigit
            label.sora.textColor = .fgPrimary
            label.sora.alignment = .center
            label.isAccessibilityElement = false
            view.contentView.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: view.contentView.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: view.contentView.centerYAnchor)
            ])
            view.addAction(UIAction { [weak self] _ in
                guard let self = self else { return }
                self.delegate?.numpadView(self, didSelectNumAt: i)
            }, for: .touchUpInside)
            return view
        }
    }()
    
    lazy var backspaceButton: NeumorphicControl = {
        let view = makeKey(image: R.image.wallet.delete(), color: .fgSecondary, imageSize: 24)
        view.accessibilityLabel = R.string.localizable.commonDelete(preferredLanguages: .currentLocale)
        view.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.numpadViewDidSelectBackspace(self)
        }, for: .touchUpInside)
        let hold = UILongPressGestureRecognizer(target: self, action: #selector(clearInput(_:)))
        hold.minimumPressDuration = 0.5
        view.addGestureRecognizer(hold)
        view.accessibilityCustomActions = [UIAccessibilityCustomAction(
            name: R.string.localizable.neonPinClear(preferredLanguages: .currentLocale),
            actionHandler: { [weak self] _ in
                guard let self else { return false }
                self.delegate?.numpadViewDidClearInput(self)
                return true
            })]
        return view
    }()
    
    lazy var accessoryButton: NeumorphicControl = {
        let view = makeKey(image: R.image.wallet.faceId(), color: .statusInfo, imageSize: 28)
        view.accessibilityLabel = R.string.localizable.profileBiometryTitle(preferredLanguages: .currentLocale)
        view.addAction(UIAction { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.numpadViewDidSelectAccessoryControl(self)
        }, for: .touchUpInside)
        return view
    }()

    private func makeKey(image: UIImage? = nil, color: SoramitsuColor = .fgPrimary,
                         imageSize: CGFloat = 28) -> NeumorphicControl {
        let key = NeumorphicControl(frame: .zero)
        key.translatesAutoresizingMaskIntoConstraints = false
        key.isAccessibilityElement = true
        key.accessibilityTraits = .button
        key.isFlat = image != nil
        key.widthAnchor.constraint(equalTo: key.heightAnchor).isActive = true
        if let image {
            let icon = SoramitsuImageView()
            icon.sora.picture = .icon(image: image, color: color)
            icon.isAccessibilityElement = false
            key.contentView.addSubview(icon)
            NSLayoutConstraint.activate([
                icon.centerXAnchor.constraint(equalTo: key.contentView.centerXAnchor),
                icon.centerYAnchor.constraint(equalTo: key.contentView.centerYAnchor),
                icon.widthAnchor.constraint(equalToConstant: imageSize),
                icon.heightAnchor.constraint(equalToConstant: imageSize)
            ])
        }
        return key
    }

    @objc private func clearInput(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        delegate?.numpadViewDidClearInput(self)
    }
    
    private var accessoryButtonId: String?

    public weak var delegate: SoramitsuNumpadDelegate?

    init() {
        super.init(frame: .zero)
        setupView()
        setupConstraint()
    }

    func setupView() {
        sora.backgroundColor = .custom(uiColor: .clear)
        sora.clipsToBounds = false
    }
    
    func setupConstraint() {
        let mainStackView = SoramitsuStackView()
        mainStackView.sora.backgroundColor = .custom(uiColor: .clear)
        mainStackView.sora.axis = .vertical
        mainStackView.sora.distribution = .fillEqually
        mainStackView.spacing = 16
        mainStackView.sora.alignment = .fill
        mainStackView.sora.clipsToBounds = false
        
        let firstRowStackView = SoramitsuStackView()
        firstRowStackView.translatesAutoresizingMaskIntoConstraints = false
        firstRowStackView.sora.backgroundColor = .custom(uiColor: .clear)
        firstRowStackView.sora.axis = .horizontal
        firstRowStackView.sora.distribution = .fillEqually
        firstRowStackView.sora.alignment = .fill
        firstRowStackView.sora.clipsToBounds = false
        firstRowStackView.spacing = 24
        firstRowStackView.addArrangedSubviews(Array(buttons[1...3]))
        
        let secondRowStackView = SoramitsuStackView()
        secondRowStackView.translatesAutoresizingMaskIntoConstraints = false
        secondRowStackView.sora.backgroundColor = .custom(uiColor: .clear)
        secondRowStackView.sora.axis = .horizontal
        secondRowStackView.sora.distribution = .fillEqually
        secondRowStackView.sora.alignment = .fill
        secondRowStackView.sora.clipsToBounds = false
        secondRowStackView.spacing = 24
        secondRowStackView.addArrangedSubviews(Array(buttons[4...6]))
        
        let thirdRowStackView = SoramitsuStackView()
        thirdRowStackView.translatesAutoresizingMaskIntoConstraints = false
        thirdRowStackView.sora.backgroundColor = .custom(uiColor: .clear)
        thirdRowStackView.sora.axis = .horizontal
        thirdRowStackView.sora.distribution = .fillEqually
        thirdRowStackView.sora.alignment = .fill
        thirdRowStackView.sora.clipsToBounds = false
        thirdRowStackView.spacing = 24
        thirdRowStackView.addArrangedSubviews(Array(buttons[7...9]))
        
        let forthRowStackView = SoramitsuStackView()
        forthRowStackView.translatesAutoresizingMaskIntoConstraints = false
        forthRowStackView.sora.backgroundColor = .custom(uiColor: .clear)
        forthRowStackView.sora.axis = .horizontal
        forthRowStackView.sora.distribution = .fillEqually
        forthRowStackView.sora.alignment = .fill
        forthRowStackView.spacing = 24
        forthRowStackView.sora.clipsToBounds = false
        forthRowStackView.addArrangedSubviews([accessoryButton, buttons[0], backspaceButton])
        
        mainStackView.addArrangedSubviews(firstRowStackView, secondRowStackView, thirdRowStackView, forthRowStackView)
        
        addSubview(mainStackView)
        
        NSLayoutConstraint.activate([
            mainStackView.topAnchor.constraint(equalTo: topAnchor),
            mainStackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            mainStackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            mainStackView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
}

extension SoramitsuNumpadView: SoramitsuNumpadAccessibilitySupportProtocol {

    public func setupKeysAccessibilityIdWith(format: String?) {
        for button in buttons {
            if let existingFormat = format {
                button.accessibilityIdentifier = existingFormat + "\(button.tag)"
                button.accessibilityTraits = UIAccessibilityTraits.button
            } else {
                button.accessibilityIdentifier = nil
                button.accessibilityTraits = UIAccessibilityTraits.button
            }
        }
    }

    public func setupBackspace(accessibilityId: String?) {
        backspaceButton.accessibilityIdentifier = accessibilityId
    }

    public func setupAccessory(accessibilityId: String?) {
        accessoryButtonId = accessibilityId
        accessoryButton.accessibilityIdentifier = accessibilityId
    }
}
