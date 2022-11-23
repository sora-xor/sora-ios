/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

//
//  NeumorphismTextField.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 10.09.2022.
//  Copyright © 2022 Ruslan Rezin. All rights reserved.
//

import Foundation
import UIKit

final class NeumorphismTextField: RoundTextField {

    lazy var gradient: CAGradientLayer = {
        let gradient = CAGradientLayer()
        gradient.type = .radial
        gradient.colors = [
            R.color.neumorphism.shadowLightGray()!.cgColor,
            R.color.neumorphism.shadowSuperLightGray()!.cgColor
        ]
        gradient.cornerRadius = 24
        gradient.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradient.locations = [ 0.5, 1 ]
        return gradient
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(gradient)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let endX = 1 + bounds.size.height / bounds.size.width
        gradient.endPoint = CGPoint(x: endX, y: 1)

        gradient.frame = bounds
    }
}
