import UIKit
import Then
import SoraUI
import Anchorage
import SoraFoundation

final class FriendsViewController: UIViewController {
    var presenter: FriendsPresenterProtocol!

    @IBOutlet var containerView: GradientView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet weak var imageView: UIImageView!

    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    @IBOutlet var tableView: UITableView!
    @IBOutlet var enterLinkButton: NeumorphismButton!
    @IBOutlet var startInvitingButton: NeumorphismButton!

    private(set) var contentViewModels: [CellViewModel] = []

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

    @IBAction func startInvitingButtonPressed(_ sender: Any) {
        presenter.didSelectAction(.startInvite)
    }

    @IBAction func enterLinkButtonPressed(_ sender: Any) {
        presenter.didSelectAction(.enterLink)
    }
}

// MARK: - Private Functions

private extension FriendsViewController {

    func configureNew() {
        titleLabel.font = UIFont.styled(for: .title4)
        titleLabel.textColor = R.color.neumorphism.textDark()

        descriptionLabel.font = UIFont.styled(for: .paragraph1)
        descriptionLabel.textColor = R.color.neumorphism.textDark()

        enterLinkButton.setTitleColor(R.color.neumorphism.text(), for: .normal)
        setupTableView()
    }

    func setupLocalization() {
        title = R.string.localizable.referralToolbarTitle(preferredLanguages: localizationManager?.preferredLocalizations)

        titleLabel.text = R.string.localizable.referralTitle(preferredLanguages: languages)
        descriptionLabel.text = R.string.localizable.referralSubtitle(preferredLanguages: languages)

        startInvitingButton.buttonTitle = R.string.localizable.referralStartInviting(preferredLanguages: languages)
        enterLinkButton.buttonTitle = R.string.localizable.referralEnterLinkTitle(preferredLanguages: languages)
    }

    func setupTableView() {
        tableView.separatorInset = .zero
        tableView.separatorColor = .clear
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        tableView.backgroundColor = R.color.neumorphism.backgroundLightGrey()
        tableView.estimatedRowHeight = 100
        tableView.register(SpaceCell.self,
                           forCellReuseIdentifier: SpaceCell.reuseIdentifier)
        tableView.register(AvailableInvitationsCell.self,
                           forCellReuseIdentifier: AvailableInvitationsCell.reuseIdentifier)
        tableView.register(TotalRewardsCell.self,
                           forCellReuseIdentifier: TotalRewardsCell.reuseIdentifier)
        tableView.register(RewardRawCell.self,
                           forCellReuseIdentifier: RewardRawCell.reuseIdentifier)
        tableView.register(ReferrerCell.self,
                           forCellReuseIdentifier: ReferrerCell.reuseIdentifier)
        tableView.register(RewardFooterCell.self,
                           forCellReuseIdentifier: RewardFooterCell.reuseIdentifier)
        tableView.register(RewardSeparatorCell.self,
                           forCellReuseIdentifier: RewardSeparatorCell.reuseIdentifier)
        tableView.dataSource = self
        tableView.delegate = self
    }
}

// MARK: - FriendsViewProtocol

extension FriendsViewController: FriendsViewProtocol {
    func setup(with models: [CellViewModel]) {
        tableView.isHidden = false
        activityIndicator.isHidden = true
        activityIndicator.stopAnimating()

        contentViewModels = models
        tableView.reloadData()
    }

    func reloadScreen(with models: [CellViewModel], updatedIndexs: [Int], isExpanding: Bool) {
        contentViewModels = models

        let indexPaths = updatedIndexs.map { IndexPath(row: $0, section: 0) }

        if isExpanding {
            tableView.insertRows(at: indexPaths, with: .fade)
            tableView.scrollToRow(at: IndexPath(row: models.count - 1, section: 0), at: .bottom, animated: true)
        } else {
            tableView.deleteRows(at: indexPaths, with: .fade)
        }
    }

    func startInvitingScreen(with referrer: String) {
        activityIndicator.isHidden = true
        tableView.isHidden = true
        titleLabel.isHidden = false
        descriptionLabel.isHidden = false
        enterLinkButton.isHidden = false
        startInvitingButton.isHidden = false
        imageView.isHidden = false
        containerView.isHidden = false

        if !referrer.isEmpty {
            let title = R.string.localizable.referralYourReferrer(preferredLanguages: .currentLocale)
            enterLinkButton.setTitle(title, for: .normal)
        }
    }

    func showAlert(with text: String, image: UIImage?) {
        let alert = ModalAlertFactory.createAlert(text, image: image)
        present(alert, animated: true, completion: nil)
    }
}

extension FriendsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return contentViewModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let viewModel = contentViewModels[indexPath.row]
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: viewModel.cellReuseIdentifier, for: indexPath
        ) as? Reusable else {
            fatalError("Could not dequeue cell with identifier: \(viewModel.cellReuseIdentifier)")
        }
        cell.bind(viewModel: contentViewModels[indexPath.row])
        return cell
    }
}

extension FriendsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - Localizable

extension FriendsViewController: Localizable {
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
