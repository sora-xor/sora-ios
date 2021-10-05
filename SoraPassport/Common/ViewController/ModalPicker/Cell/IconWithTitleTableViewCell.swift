/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

class IconWithTitleTableViewCell: UITableViewCell, ModalPickerCellProtocol {
    typealias Model = IconWithTitleViewModel

    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var iconImageView: UIImageView!
    @IBOutlet private var checkmarkImageView: UIImageView!

    var checkmarked: Bool {
        get {
            !checkmarkImageView.isHidden
        }

        set {
            checkmarkImageView.isHidden = !newValue
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = R.color.themeAccent()!.withAlphaComponent(0.3)
        self.selectedBackgroundView = selectedBackgroundView
    }

    func bind(model: Model) {
        titleLabel.text = model.title
        iconImageView.image = model.icon
    }
}

class LoadingIconWithTitleTableViewCell: UITableViewCell, ModalPickerCellProtocol {
    typealias Model = LoadingIconWithTitleViewModel

    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var iconImageView: UIImageView!
    @IBOutlet private var checkmarkImageView: UIImageView!

    var checkmarked: Bool {
        get {
            !checkmarkImageView.isHidden
        }

        set {
            checkmarkImageView.isHidden = !newValue
        }
    }

    var toggle: UISwitch? = UISwitch()

    override func awakeFromNib() {
        super.awakeFromNib()

        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = R.color.themeAccent()!.withAlphaComponent(0.3)
        self.selectedBackgroundView = selectedBackgroundView
        self.editingAccessoryView = toggle
        self.iconImageView.image = nil
    }

    func bind(model: Model) {
        titleLabel.text = model.title
        model.iconViewModel?.loadImage { [weak self] (icon, _) in
            self?.iconImageView.image = icon
        }
        toggle?.isOn = model.toggle
    }
}
