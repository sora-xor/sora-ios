import SoraFoundation
import SoraUI
import UIKit

class PolkaswapPoolView: UIView, Localizable {
    var onAddPool: () -> Void = {}

    let tableView: UITableView = {
        let view = UITableView()
        view.backgroundColor = .clear
        view.separatorStyle = .none
        view.contentInset = .init(top: 0, left: 0, bottom: 100, right: 0)
        return view
    }()

    lazy var addButton: UIButton = {
        let view = UIButton()
        view.setImage(R.image.enabled(), for: .normal)
        view.addTarget(self, action: #selector(onAddPoolTap), for: .touchUpInside)
        return view
    }()

    let emptyView: UIView = {
        let title = UILabel()
        title.text = R.string.localizable.polkaswapSwapEmptyList(preferredLanguages: .currentLocale)
        title.font = .styled(for: .paragraph1)
        title.textColor = R.color.neumorphism.text()
        title.textAlignment = .center
        title.numberOfLines = 0

        let icon = UIImageView(image: UIImage(named: R.image.emptyStateArrow.name)!)

        let view = UIView()
        view.addSubview(title)
        title.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
        }

        view.addSubview(icon)
        icon.snp.makeConstraints {
            $0.top.equalTo(title.snp.bottom).offset(16)
            $0.leading.equalTo(title.snp.centerX)
            $0.bottom.equalToSuperview().inset(24)
        }

        return view
    }()

    var loadingView: PageLoadingView = PageLoadingView()

    override init(frame: CGRect) {
        super.init(frame: .zero)
        setup()
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        backgroundColor = R.color.neumorphism.base()
        emptyView.isHidden = true
    }

    private func setupLayout() {
        addSubview(tableView)
        tableView.snp.makeConstraints {
            $0.edges.equalToSuperview()
        }

        addSubview(emptyView)
        emptyView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(safeAreaLayoutGuide).inset(16)
        }

        addSubview(addButton)
        addButton.snp.makeConstraints {
            $0.size.equalTo(56)
            $0.trailing.equalToSuperview().inset(16)
            $0.bottom.equalTo(safeAreaLayoutGuide).inset(16)
        }

        addSubview(loadingView)
        loadingView.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.size.equalTo(72)
        }
    }

    @objc private func onAddPoolTap() {
        onAddPool()
    }

    func applyLocalization() {
        tableView.reloadData()
    }
}
