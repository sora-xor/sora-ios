import CommonWallet
import SnapKit
import UIKit

class PolkaswapPoolCell: UITableViewCell {
    static let cellId = "PolkaswapPoolCell"

    private let iconImageView = UIImageView()
    private let baseAssetImageView = UIImageView()
    private let targetAssetImageView = UIImageView()

    private var titleLabel: UILabel = {
        let view = UILabel()
        view.font = UIFont.styled(for: .paragraph1, isBold: true)!
        view.textColor = R.color.baseContentPrimary()!
        return view
    }()

    private lazy var expandButton = NeumorphismButton().then {
        $0.setImage(R.image.arrowDown(), for: .normal)
        $0.addTarget(self, action: #selector(onExpandTap), for: .touchUpInside)
    }

    private var stackView: UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        return view
    }()

    private let detailsViews: [PolkaswapPoolDetailsView] = [
        PolkaswapPoolDetailsView(),
        PolkaswapPoolDetailsView(),
        PolkaswapPoolDetailsView(),
        PolkaswapPoolDetailsView()
    ]

    private lazy var addButton = NeumorphismButton().then {
        $0.tintColor = R.color.brandWhite()
        $0.color = R.color.brandPolkaswapPink()!
        $0.addTarget(self, action: #selector(onAddTap), for: .touchUpInside)
    }

    private lazy var removeButton = NeumorphismButton().then {
        $0.tintColor = R.color.brandWhite()
        $0.color = R.color.brandPolkaswapPink()!
        $0.addTarget(self, action: #selector(onRemoveTap), for: .touchUpInside)
    }

    private lazy var addRemoveButtons: UIView = {
        let view = UIStackView(arrangedSubviews: [addButton, removeButton])
        view.distribution = .fillEqually
        view.spacing = 16
        view.isLayoutMarginsRelativeArrangement = true
        view.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 20, leading: 0, bottom: 20, trailing: 0)
        return view
    }()

    private let separator: UIView = {
        let view = UIView()
        view.backgroundColor = R.color.neumorphism.tableSeparator()!
        return view
    }()

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
        contentView.addSubview(baseAssetImageView)
        baseAssetImageView.snp.makeConstraints {
            $0.top.equalToSuperview().inset(20)
            $0.leading.equalToSuperview().inset(16)
            $0.size.equalTo(32)
        }

        contentView.addSubview(targetAssetImageView)
        targetAssetImageView.snp.makeConstraints {
            $0.top.equalToSuperview().inset(35)
            $0.leading.equalToSuperview().inset(32)
            $0.size.equalTo(32)
        }

        contentView.addSubview(titleLabel)
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        titleLabel.snp.makeConstraints {
            $0.top.equalToSuperview().inset(30)
            $0.leading.equalToSuperview().inset(72)
        }

        contentView.addSubview(expandButton)
        expandButton.snp.makeConstraints {
            $0.top.trailing.equalToSuperview().inset(16)
            $0.size.equalTo(40)
        }

        contentView.addSubview(stackView)
        stackView.snp.makeConstraints {
            $0.top.equalToSuperview().inset(80)
            $0.leading.trailing.equalToSuperview().inset(32)
            $0.bottom.equalToSuperview()
        }

        contentView.addSubview(separator)
        separator.snp.makeConstraints {
            $0.trailing.leading.equalToSuperview().inset(32)
            $0.bottom.equalToSuperview()
            $0.height.equalTo(1)
        }
    }

    func configure(viewModel: PolkaswapPoolCellModel) {
        titleLabel.text = viewModel.title

        addButton.setTitle(R.string.localizable.poolButtonAdd(preferredLanguages: .currentLocale), for: .normal)
        removeButton.setTitle(R.string.localizable.poolButtonRemove(preferredLanguages: .currentLocale), for: .normal)

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

        let baseTitle = "\(viewModel.baseAssetSymbol) \(R.string.localizable.poolTokenPooled(preferredLanguages: .currentLocale))"
        let targetTitle = "\(viewModel.targetAssetSymbol) \(R.string.localizable.poolTokenPooled(preferredLanguages: .currentLocale))"

        detailsViews[0].configure(
            titleLabel: R.string.localizable.poolShareTitle1(preferredLanguages: .currentLocale),
            rightTitle: viewModel.poolShare,
            rightSubtitle: ""
        )
        detailsViews[1].configure(
            titleLabel: R.string.localizable.poolApyTitle(preferredLanguages: .currentLocale),
            rightTitle: viewModel.bonusApy,
            rightSubtitle: ""
        )
        detailsViews[2].configure(titleLabel: baseTitle, rightTitle: viewModel.baseAssetPoolded, rightSubtitle: viewModel.baseAssetFee)
        detailsViews[3].configure(titleLabel: targetTitle, rightTitle: viewModel.targetAssetPooled, rightSubtitle: viewModel.targetAssetFee)

        setExpanded(viewModel.isExpanded)

        onExpand = { [unowned viewModel, unowned self] in
            viewModel.onExpand { [unowned self] isExpanded in
                self.setExpanded(isExpanded)
            }
        }

        onAdd = {
            viewModel.onAdd()
        }

        onRemove = {
            viewModel.onRemove()
        }
    }

    private func setExpanded(_ isExpanded: Bool) {
        let image = isExpanded ? R.image.arrowUp() : R.image.arrowDown()
        expandButton.setImage(image, for: .normal)

        for view in detailsViews {
            if isExpanded {
                stackView.addArrangedSubview(view)
            } else {
                stackView.removeArrangedSubview(view)
                view.removeFromSuperview()
            }
        }

        if isExpanded {
            stackView.addArrangedSubview(addRemoveButtons)
        } else {
            stackView.removeArrangedSubview(addRemoveButtons)
            addRemoveButtons.removeFromSuperview()
        }
    }

    private var onExpand: (() -> Void)?
    @objc private func onExpandTap() {
        onExpand?()
    }

    private var onAdd: (() -> Void)?
    @objc private func onAddTap() {
        onAdd?()
    }

    private var onRemove: (() -> Void)?
    @objc private func onRemoveTap() {
        onRemove?()
    }
}
