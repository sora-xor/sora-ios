import Foundation
import SoraSwiftUI
import UIKit

final class AssetHeaderView: SoramitsuControl {
    private let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline2
        label.sora.textColor = .fgPrimary
        return label
    }()

    private let imageView: SoramitsuImageView = {
        let image = SoramitsuImageView()
        image.transform = CGAffineTransform.identity
        image.sora.picture = .icon(image: R.image.arrow()!, color: .fgPrimary)
        return image
    }()

    init() {
        super.init(frame: .zero)
        setup()
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        sora.backgroundColor = .custom(uiColor: .clear)
        addSubview(titleLabel)
        addSubview(imageView)
    }

    private func setupLayout() {
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            imageView.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 10),
            imageView.heightAnchor.constraint(equalToConstant: 16),
            imageView.widthAnchor.constraint(equalToConstant: 16),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    func configure(title: String, isExpand: Bool) {
        titleLabel.sora.text = title

        UIView.animate(withDuration: 0.3) {
            self.imageView.transform = isExpand ? CGAffineTransform.identity : CGAffineTransform(rotationAngle: .pi)
        }
    }
}
