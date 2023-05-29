import UIKit
import Then
import SoraUI
import Anchorage
import SoraFoundation
import SoraUIKit

final class NodesViewController: SoramitsuViewController, AlertPresentable {
    var presenter: NodesPresenterProtocol!

    private lazy var tableView: SoramitsuTableView = {
        let tableView = SoramitsuTableView(type: .grouped)
        tableView.sora.backgroundColor = .bgPage
        tableView.sora.estimatedRowHeight = UITableView.automaticDimension
        return tableView
    }()

    private lazy var activityIndicator: UIActivityIndicatorView = {
        return UIActivityIndicatorView(style: .large)
    }()

    private(set) var contentViewModels: [SectionViewModel] = []

    // MARK: - Vars

    /// Used to correction the distance to the top of the screen
    private var statusBarHeightCorrection: CGFloat {
        UIApplication.shared.statusBarFrame.size.height + 10
    }

    /// Used to correction the middle position of the pull-up controller
    /// and prevent moving content of the main view on animation to the upper state
    private var navigationBarHeightCorrection: CGFloat {
        statusBarHeightCorrection + (navigationController?.navigationBar.frame.size.height ?? 0)
    }

    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        activityIndicator.startAnimating()

        presenter.setup()

        setupLocalization()
        configureNew()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationItem.largeTitleDisplayMode = .never
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.navigationBar.prefersLargeTitles = true
    }
}

// MARK: - Private Functions

private extension NodesViewController {

    func configureNew() {
        setupTableView()
    }

    func setupLocalization() {
        title = R.string.localizable.commonSelectNode(preferredLanguages: localizationManager?.preferredLocalizations)
        navigationItem.rightBarButtonItem?.title = R.string.localizable.selectNodeAddNode(preferredLanguages: languages)
    }

    func setupTableView() {
        tableView.separatorInset = .zero
        tableView.separatorColor = .clear
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        tableView.sora.delaysContentTouches = true
        tableView.backgroundColor = .clear
        tableView.register(NodesCell.self, forCellReuseIdentifier: NodesCell.reuseIdentifier)
        tableView.dataSource = self
        tableView.delegate = self
    }
}

// MARK: - NodesViewProtocol

extension NodesViewController: NodesViewProtocol {
    func setup(with models: [SectionViewModel]) {
        view.addSubviews(tableView)
        
        setupConstraints()
        setupNavbar()
        activityIndicator.isHidden = true
        activityIndicator.stopAnimating()

        contentViewModels = models
        tableView.reloadData()
    }

    private func setupNavbar() {

        let addButton = UIBarButtonItem(title: R.string.localizable.selectNodeAddNode(preferredLanguages: languages), style: .plain, target: self, action: #selector(editTapped))
        addButton.setTitleTextAttributes([ .font: UIFont.systemFont(ofSize: 13, weight: .bold), .foregroundColor: UIColor(hex: "#EE2233")],
                                          for: .normal)

        self.navigationItem.rightBarButtonItem = addButton

    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.soraSafeTopAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.soraSafeBottomAnchor)
        ])
    }

    func reloadScreen(with models: [SectionViewModel], updatedIndexs: [Int], isExpanding: Bool) {

        contentViewModels = models

        let indexPaths = updatedIndexs.map { IndexPath(row: $0, section: 0) }

        if isExpanding {
            tableView.insertRows(at: indexPaths, with: .fade)
            tableView.scrollToRow(at: IndexPath(row: models.count - 1, section: 0), at: .bottom, animated: true)
        } else {
            tableView.deleteRows(at: indexPaths, with: .fade)
        }
    }

    @objc
    func editTapped() {
        (presenter as! ButtonCellDelegate).buttonTapped()
    }
}

extension NodesViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return contentViewModels.count
    }


    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return nil
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let viewModel = contentViewModels[indexPath.row].models
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: viewModel.cellReuseIdentifier, for: indexPath
        ) as? Reusable else {
            fatalError("Could not dequeue cell with identifier: ChangeAccountTableViewCell")
        }
        cell.bind(viewModel: viewModel)
        return cell
    }
}

extension NodesViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - Localizable

extension NodesViewController: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}
