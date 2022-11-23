/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import Then
import Anchorage

protocol ButtonCellDelegate {
    func buttonTapped()
}

final class ButtonCell: UITableViewCell {

    private var delegate: ButtonCellDelegate?

    // MARK: - Outlets
    private lazy var button: NeumorphismButton = {
        NeumorphismButton().then {
            $0.heightAnchor == 56
            $0.tintColor = R.color.brandWhite()
            $0.font = UIFont.styled(for: .button)
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)
        }
    }()

    // MARK: - Init

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configure()
    }

    @objc
    func buttonTapped() {
        delegate?.buttonTapped()
    }
}

extension ButtonCell: Reusable {
    func bind(viewModel: CellViewModel) {
        guard let model = viewModel as? ButtonViewModelProtocol else { return }
        button.setTitle(model.title, for: .normal)
        button.isEnabled = model.isEnabled
        button.color = model.backgroundColor ?? .white

        if let color = model.titleColor {
            button.setTitleColor(color, for: .normal)
        }

        self.delegate = model.delegate
    }
}

private extension ButtonCell {

    func configure() {
        selectionStyle = .none
        backgroundColor = .clear

        contentView.addSubview(button)

        button.do {
            $0.topAnchor == contentView.topAnchor
            $0.centerXAnchor == centerXAnchor
            $0.leadingAnchor == leadingAnchor + 24
            $0.heightAnchor == 56
            $0.bottomAnchor == contentView.bottomAnchor
        }
    }
}
