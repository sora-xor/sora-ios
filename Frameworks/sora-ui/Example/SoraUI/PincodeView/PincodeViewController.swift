/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit
import SoraUI

final class PincodeViewController: UIViewController, AdaptiveDesignable {
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var pinView: PinView!

    @IBOutlet private var titleTop: NSLayoutConstraint!
    @IBOutlet private var pinViewTop: NSLayoutConstraint!

    override func viewDidLoad() {
        super.viewDidLoad()

        pinView.delegate = self

        adjustConstraints()
    }

    private func adjustConstraints() {
        if isAdaptiveHeightDecreased || isAdaptiveWidthDecreased {
            let scale = min(designScaleRatio.width, designScaleRatio.height)

            if let numpadView = pinView.numpadView {
                pinView.numpadView?.keyRadius *= scale

                if let titleFont = numpadView.titleFont {
                    numpadView.titleFont = UIFont(name: titleFont.fontName, size: scale * titleFont.pointSize)
                }
            }

            if let currentFieldsView = pinView.characterFieldsView {
                let font = currentFieldsView.fieldFont

                if let newFont = UIFont(name: font.fontName, size: scale * font.pointSize) {
                    currentFieldsView.fieldFont = newFont
                }
            }

            pinView.securedCharacterFieldsView?.fieldRadius *= scale
        }

        if isAdaptiveHeightDecreased {
            pinView.verticalSpacing *= designScaleRatio.height
            pinView.numpadView?.verticalSpacing *= designScaleRatio.height
            pinView.characterFieldsView?.fieldSize.height *= designScaleRatio.height
            pinView.securedCharacterFieldsView?.fieldSize.height *= designScaleRatio.height
        }

        if isAdaptiveWidthDecreased {
            pinView.numpadView?.horizontalSpacing *= designScaleRatio.width
            pinView.characterFieldsView?.fieldSize.width *= designScaleRatio.width
            pinView.securedCharacterFieldsView?.fieldSize.width *= designScaleRatio.width
        }

        titleTop.constant *= designScaleRatio.height
        pinViewTop.constant *= designScaleRatio.height
    }
}

extension PincodeViewController: PinViewDelegate {
    func didChange(pinView: PinView, from state: PinView.CreationState) {
        switch pinView.creationState {
        case .normal:
            titleLabel.text = "Enter pincode"
        case .confirm:
            titleLabel.text = "Confirm pincode"
        }
    }

    func didCompleteInput(pinView: PinView, result: String) {
        print("Save pincode now!")
    }

    func didSelectAccessoryControl(pinView: PinView) {
        print("Accessory button pressed!")
    }

    func didFailConfirmation(pinView: PinView) {
        print("Wrong input error!")
    }
}
