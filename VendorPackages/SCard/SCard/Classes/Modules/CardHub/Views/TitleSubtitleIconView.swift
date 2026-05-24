import Foundation
import SoraUIKit

class TitleSubtitleIconView: SoramitsuView {

    let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.numberOfLines = 1
        label.textAlignment = .left
        label.backgroundColor = .clear
        label.sora.font = FontType.textM
        label.sora.textColor = .fgPrimary
        return label
    }()

    let subtitleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.numberOfLines = 1
        label.textAlignment = .left
        label.backgroundColor = .clear
        label.sora.font = FontType.textBoldXS
        label.sora.textColor = .fgSecondary
        label.sora.isHidden = true
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
        addSubview(titleLabel) {
            $0.top.equalToSuperview().inset(16)
            $0.leading.equalToSuperview()
        }

        addSubview(subtitleLabel) {
            $0.top.equalTo(titleLabel.snp.bottom).offset(4)
            $0.bottom.equalToSuperview().inset(16)
            $0.leading.equalToSuperview()
        }

        addSubview(rightImageView) {
            $0.leading.equalTo(self.titleLabel.snp.trailing).offset(20)
            $0.trailing.centerY.equalToSuperview()
            $0.size.equalTo(24)
        }
    }
}
