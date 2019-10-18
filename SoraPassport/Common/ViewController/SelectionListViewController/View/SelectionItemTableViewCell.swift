/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

@IBDesignable
final class SelectionItemTableViewCell: UITableViewCell {
    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var checkmarkImageView: UIImageView!

    @IBInspectable
    var titleColor: UIColor = UIColor.black {
        didSet {
            updateSelectionState()
        }
    }

    @IBInspectable
    var selectedTitleColor: UIColor = UIColor.black {
        didSet {
            updateSelectionState()
        }
    }

    @IBInspectable
    var checkmarkIcon: UIImage? {
        didSet {
            updateSelectionState()
        }
    }

    private(set) var viewModel: SelectionListViewModelProtocol?

    override func prepareForReuse() {
        viewModel?.removeObserver(self)
    }

    func bind(viewModel: SelectionListViewModelProtocol) {
        self.viewModel = viewModel

        titleLabel.text = viewModel.title
        updateSelectionState()

        viewModel.addObserver(self)
    }

    private func updateSelectionState() {
        guard let viewModel = viewModel else {
            return
        }

        if titleLabel != nil {
            titleLabel.textColor = viewModel.isSelected ? selectedTitleColor : titleColor
        }

        if checkmarkImageView != nil {
            checkmarkImageView.image = viewModel.isSelected ? checkmarkIcon : nil
        }
    }
}

extension SelectionItemTableViewCell: SelectionListViewModelObserver {
    func didChangeSelection() {
        updateSelectionState()
    }
}
