import Foundation
import SoraUIKit

class IconTitleIconView: SoramitsuView {

    private static let iconSize: CGFloat = 24

    let leftImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .center
        imageView.layer.cornerRadius = IconTitleIconView.iconSize / 2
        imageView.clipsToBounds = true
        return imageView
    }()

    let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.numberOfLines = 1
        label.textAlignment = .left
        label.backgroundColor = .clear
        label.sora.font = FontType.textM
        label.sora.textColor = .fgPrimary
        return label
    }()

    let rightImageView: SoramitsuImageView = {
        let imageView = SoramitsuImageView()
        return imageView
    }()

    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setupInitialLayout()
    }

    private func setupInitialLayout() {

        addSubview(leftImageView) {
            $0.leading.equalToSuperview().inset(24)
            $0.centerY.equalToSuperview()
            $0.size.equalTo(Self.iconSize)
        }

        addSubview(titleLabel) {
            $0.top.bottom.equalToSuperview().inset(20)
            $0.leading.equalTo(leftImageView.snp.trailing).offset(8)
        }

        addSubview(rightImageView) {
            $0.leading.equalTo(self.titleLabel.snp.trailing).offset(8)
            $0.trailing.equalToSuperview().inset(16)
            $0.trailing.centerY.equalToSuperview()
            $0.size.equalTo(24)
        }
    }
}
