/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

protocol ButtonViewModelProtocol: AnyObject {
    var title: String { get }
    var isEnabled: Bool { get }
    var delegate: ButtonCellDelegate { get }
    var titleColor: UIColor? { get }
    var backgroundColor: UIColor? { get }
}

class ButtonViewModel: ButtonViewModelProtocol {
    var title: String
    var titleColor: UIColor?
    var backgroundColor: UIColor?
    var isEnabled: Bool
    var delegate: ButtonCellDelegate

    init(title: String,
         isEnabled: Bool = true,
         titleColor: UIColor? = nil,
         backgroundColor: UIColor? = R.color.neumorphism.tint(),
         delegate: ButtonCellDelegate) {
        self.title = title
        self.isEnabled = isEnabled
        self.delegate = delegate
        self.titleColor = titleColor
        self.backgroundColor = backgroundColor
    }
}

extension ButtonViewModel: CellViewModel {
    var cellReuseIdentifier: String {
        ButtonCell.reuseIdentifier
    }
}
