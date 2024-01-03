//
//  ExploreSectionHeader.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 1/3/24.
//  Copyright © 2024 Soramitsu. All rights reserved.
//

import SoraUIKit

final class ExploreSectionHeader: UITableViewHeaderFooterView {
    //MARK: - Properties
    static var reuseIdentifier: String {
        return String(describing: self)
    }

    private let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline4
        label.sora.textColor = .fgSecondary
        label.sora.numberOfLines = 0
        return label
    }()

    //MARK: - Init
    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        contentView.backgroundColor = SoramitsuUI.shared.theme.palette.color(.bgSurface)
        contentView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
        ])
        
        SoramitsuUI.updates.addObserver(self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    //MARK: - Configure
    func configure(with title: String) {
        titleLabel.sora.text = title.uppercased()
    }
}

extension ExploreSectionHeader: SoramitsuObserver {
    func styleDidChange(options: UpdateOptions) {
        contentView.backgroundColor = SoramitsuUI.shared.theme.palette.color(.bgSurface)
    }
}
