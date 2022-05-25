import CommonWallet
import SnapKit
import UIKit

class PolkaswapPoolDetailsView: UIView {
    private let titleLabel: UILabel = {
        let view = UILabel()
        view.font = UIFont.styled(for: .paragraph1)!
        view.textColor = R.color.baseContentPrimary()!
        return view
    }()

    private let rightTitleLabel: UILabel = {
        let view = UILabel()
        view.textAlignment = .right
        view.font = UIFont.styled(for: .paragraph1, isBold: true)!
        view.textColor = R.color.baseContentPrimary()!
        return view
    }()

    private let rightSubtitleLabel: UILabel = {
        let view = UILabel()
        view.textAlignment = .right
        view.font = UIFont.styled(for: .paragraph1, isBold: true)!
        view.textColor = R.color.baseContentQuaternary()!
        return view
    }()

    private let separator: UIView = {
        let view = UIView()
        view.backgroundColor = R.color.neumorphism.tableSeparator()!
        return view
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
        backgroundColor = .clear
    }

    private func setupLayout() {
        snp.makeConstraints {
            $0.height.equalTo(44)
        }

        addSubview(titleLabel)
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        titleLabel.snp.makeConstraints {
            $0.leading.top.equalToSuperview()
        }

        let textContainer = UIView()
        textContainer.addSubview(rightTitleLabel)
        textContainer.addSubview(rightSubtitleLabel)

        rightTitleLabel.snp.makeConstraints {
            $0.leading.trailing.top.equalToSuperview()
            $0.bottom.equalTo(textContainer.snp.centerY)
        }
        rightSubtitleLabel.snp.makeConstraints {
            $0.top.equalTo(textContainer.snp.centerY)
            $0.leading.trailing.bottom.equalToSuperview()
        }

        addSubview(textContainer)
        textContainer.snp.makeConstraints {
            $0.trailing.top.bottom.equalToSuperview()
            $0.leading.greaterThanOrEqualTo(titleLabel.snp.trailing).offset(4)
        }

        addSubview(separator)
        separator.snp.makeConstraints {
            $0.trailing.leading.bottom.equalToSuperview()
            $0.height.equalTo(1)
        }
    }

    func configure(titleLabel: String, rightTitle: String, rightSubtitle: String) {
        self.titleLabel.text = titleLabel.uppercased()
        rightTitleLabel.text = rightTitle
        rightSubtitleLabel.text = rightSubtitle
    }
}
