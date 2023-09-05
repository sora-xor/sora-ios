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

import Foundation
import SoraUIKit

public protocol SoramitsuNumpadDelegate: AnyObject {
    func numpadView(_ view: SoramitsuNumpadView, didSelectNumAt index: Int)
    func numpadViewDidSelectBackspace(_ view: SoramitsuNumpadView)
    func numpadViewDidSelectAccessoryControl(_ view: SoramitsuNumpadView)
}

public protocol SoramitsuNumpadAccessibilitySupportProtocol: AnyObject {
    func setupKeysAccessibilityIdWith(format: String?)
    func setupBackspace(accessibilityId: String?)
    func setupAccessory(accessibilityId: String?)
}

public class SoramitsuNumpadView: SoramitsuView {

    lazy var buttons: [SoramitsuButton] = {
        var buttons: [SoramitsuButton] = []
        for i in 0...10 {
            let text = SoramitsuTextItem(text: "\(i)",
                                         fontData: FontType.displayL,
                                         textColor: .fgSecondary,
                                         alignment: .center)
            let view = SoramitsuButton()
            view.translatesAutoresizingMaskIntoConstraints = false
            view.sora.tintColor = .fgSecondary
            view.sora.backgroundColor = .bgSurface
            view.sora.shadow = .small
            view.sora.attributedText = text
            view.sora.cornerRadius = .circle
            view.widthAnchor.constraint(equalToConstant: 80).isActive = true
            view.heightAnchor.constraint(equalToConstant: 80).isActive = true
            view.sora.addHandler(for: .touchUpInside) { [weak self] in
                guard let self = self else { return }
                self.delegate?.numpadView(self, didSelectNumAt: i)
            }
            buttons.append(view)
        }
        return buttons
    }()
    
    lazy var backspaceButton: SoramitsuButton = {
        let view = SoramitsuButton()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.sora.tintColor = .fgSecondary
        view.sora.backgroundColor = .bgSurface
        view.sora.shadow = .small
        view.sora.leftImage = R.image.wallet.delete()
        view.sora.imageSize = CGFloat(32)
        view.sora.cornerRadius = .circle
        view.widthAnchor.constraint(equalToConstant: 80).isActive = true
        view.heightAnchor.constraint(equalToConstant: 80).isActive = true
        view.setContentCompressionResistancePriority(.required, for: .horizontal)
        view.sora.addHandler(for: .touchUpInside) { [weak self] in
            guard let self = self else { return }
            self.delegate?.numpadViewDidSelectBackspace(self)
        }
        return view
    }()
    
    lazy var accessoryButton: SoramitsuButton = {
        let view = SoramitsuButton()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.sora.tintColor = .fgSecondary
        view.sora.backgroundColor = .bgSurface
        view.sora.shadow = .small
        view.sora.leftImage = R.image.wallet.faceId()
        view.sora.cornerRadius = .circle
        view.sora.imageSize = CGFloat(32)
        view.widthAnchor.constraint(equalToConstant: 80).isActive = true
        view.heightAnchor.constraint(equalToConstant: 80).isActive = true
        view.setContentCompressionResistancePriority(.required, for: .horizontal)
        view.sora.addHandler(for: .touchUpInside) { [weak self] in
            guard let self = self else { return }
            self.delegate?.numpadViewDidSelectAccessoryControl(self)
        }
        return view
    }()
    
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
        var mainStackView = SoramitsuStackView()
        mainStackView.sora.backgroundColor = .custom(uiColor: .clear)
        mainStackView.sora.axis = .vertical
        mainStackView.sora.distribution = .equalSpacing
        mainStackView.sora.alignment = .fill
        mainStackView.sora.clipsToBounds = false
        
        let firstRowStackView = SoramitsuStackView()
        firstRowStackView.translatesAutoresizingMaskIntoConstraints = false
        firstRowStackView.sora.backgroundColor = .custom(uiColor: .clear)
        firstRowStackView.sora.axis = .horizontal
        firstRowStackView.sora.distribution = .fillEqually
        firstRowStackView.sora.alignment = .fill
        firstRowStackView.sora.clipsToBounds = false
        firstRowStackView.spacing = 16
        firstRowStackView.heightAnchor.constraint(equalToConstant: 80).isActive = true
        firstRowStackView.addArrangedSubviews(Array(buttons[1...3]))
        
        let secondRowStackView = SoramitsuStackView()
        secondRowStackView.translatesAutoresizingMaskIntoConstraints = false
        secondRowStackView.sora.backgroundColor = .custom(uiColor: .clear)
        secondRowStackView.sora.axis = .horizontal
        secondRowStackView.sora.distribution = .fillEqually
        secondRowStackView.sora.alignment = .fill
        secondRowStackView.sora.clipsToBounds = false
        secondRowStackView.spacing = 16
        secondRowStackView.heightAnchor.constraint(equalToConstant: 80).isActive = true
        secondRowStackView.addArrangedSubviews(Array(buttons[4...6]))
        
        let thirdRowStackView = SoramitsuStackView()
        thirdRowStackView.translatesAutoresizingMaskIntoConstraints = false
        thirdRowStackView.sora.backgroundColor = .custom(uiColor: .clear)
        thirdRowStackView.sora.axis = .horizontal
        thirdRowStackView.sora.distribution = .fillEqually
        thirdRowStackView.sora.alignment = .fill
        thirdRowStackView.sora.clipsToBounds = false
        thirdRowStackView.spacing = 16
        thirdRowStackView.heightAnchor.constraint(equalToConstant: 80).isActive = true
        thirdRowStackView.addArrangedSubviews(Array(buttons[7...9]))
        
        let forthRowStackView = SoramitsuStackView()
        forthRowStackView.translatesAutoresizingMaskIntoConstraints = false
        forthRowStackView.sora.backgroundColor = .custom(uiColor: .clear)
        forthRowStackView.sora.axis = .horizontal
        forthRowStackView.sora.distribution = .fillEqually
        forthRowStackView.sora.alignment = .fill
        forthRowStackView.spacing = 16
        forthRowStackView.sora.clipsToBounds = false
        forthRowStackView.heightAnchor.constraint(equalToConstant: 80).isActive = true
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
                button.accessibilityTraits = UIAccessibilityTraits.none
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
