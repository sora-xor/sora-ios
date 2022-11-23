import SnapKit
import CommonWallet
import UIKit

class LiquidityHistoryCell: UITableViewCell {
    static let cellId = "LiquidityHistoryCell"

    private let iconImageView = UIImageView()
    private let baseAssetImageView = UIImageView()
    private let targetAssetImageView = UIImageView()

    private var titleLabel = UILabel()

    private var rightTitleLabel: UILabel = {
        let view = UILabel()
        view.textAlignment = .right
        return view
    }()

    private var rightSubtitleLabel: UILabel = {
        let view = UILabel()
        view.textAlignment = .right
        return view
    }()

    internal var viewModel: WalletViewModelProtocol?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        backgroundColor = .clear
        selectionStyle = .none
    }

    private func setupLayout() {
        contentView.snp.makeConstraints {
            $0.height.equalTo(54)
            $0.edges.equalToSuperview()
        }

        contentView.addSubview(iconImageView)
        iconImageView.snp.makeConstraints {
            $0.leading.equalToSuperview().inset(16)
            $0.centerY.equalToSuperview()
            $0.width.equalTo(14)
            $0.height.equalTo(20)
        }

        contentView.addSubview(titleLabel)
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        titleLabel.snp.makeConstraints {
            $0.leading.equalTo(iconImageView.snp.trailing).offset(8)
            $0.centerY.equalToSuperview()
        }

        contentView.addSubview(baseAssetImageView)
        baseAssetImageView.snp.makeConstraints {
            $0.leading.equalTo(titleLabel.snp.trailing).offset(4)
            $0.centerY.equalToSuperview()
            $0.size.equalTo(14)
        }

        contentView.addSubview(targetAssetImageView)
        targetAssetImageView.snp.makeConstraints {
            $0.leading.equalTo(baseAssetImageView.snp.trailing).offset(4)
            $0.centerY.equalToSuperview()
            $0.size.equalTo(14)
        }

        let textContainer = UIView()
        textContainer.addSubview(rightTitleLabel)
        textContainer.addSubview(rightSubtitleLabel)

        rightTitleLabel.snp.makeConstraints {
            $0.leading.trailing.top.equalToSuperview()
        }
        rightSubtitleLabel.snp.makeConstraints {
            $0.top.equalTo(rightTitleLabel.snp.bottom)
            $0.leading.trailing.bottom.equalToSuperview()
        }

        contentView.addSubview(textContainer)
        textContainer.snp.makeConstraints {
            $0.trailing.equalToSuperview().inset(16)
            $0.centerY.equalToSuperview()
            $0.leading.greaterThanOrEqualTo(targetAssetImageView.snp.trailing).offset(4)
        }
    }
}

extension LiquidityHistoryCell: WalletViewProtocol {
    func bind(viewModel: WalletViewModelProtocol) {
        guard let viewModel = viewModel as? LiquidityHistoryViewModel else { return }

        titleLabel.attributedText = viewModel.title
        rightTitleLabel.attributedText = viewModel.rightTitle
        rightSubtitleLabel.attributedText = viewModel.rightSubtitle
        iconImageView.image = viewModel.image

        viewModel.baseAssetImage.loadImage { [weak baseAssetImageView] image, error in
            if error == nil {
                baseAssetImageView?.image = image
            } else {
                print(error!.localizedDescription)
            }
        }

        viewModel.targetAssetImage.loadImage { [weak targetAssetImageView] image, error in
            if error == nil {
                targetAssetImageView?.image = image
            } else {
                print(error!.localizedDescription)
            }
        }
    }
}
