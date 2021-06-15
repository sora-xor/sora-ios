import UIKit
import Then
import Anchorage
import SoraFoundation
import SoraUI

protocol RewardsSuperviewProtocol: class {
    var maximumHeightLimit: CGFloat { get }
    var middleHeightLimit: CGFloat { get }
    var minimumHeightLimit: CGFloat { get }
    var prefferedSize: CGSize { get }
}

extension RewardsSuperviewProtocol {
    var maximumHeightLimit: CGFloat { return .zero }
    var middleHeightLimit: CGFloat { return .zero }
    var minimumHeightLimit: CGFloat { return .zero }
    var prefferedSize: CGSize { return .zero }
}

final class RewardsViewController: PullUpController {

    weak var superview: RewardsSuperviewProtocol?

    // MARK: - Controls

    private lazy var containerView: UIView = {
        RoundedView().then {
            $0.fillColor = .white

            $0.cornerRadius = 24
            $0.roundingCorners = [.topLeft, .topRight]

            $0.shadowRadius = 3
            $0.shadowOpacity = 0.3
            $0.shadowOffset = CGSize(width: 0, height: -1)
            $0.shadowColor = UIColor(white: 0, alpha: 0.3)
        }
    }()

    private lazy var titleLabel: UILabel = {
        UILabel().then {
            $0.textColor = R.color.baseContentPrimary()
            $0.font = UIFont.styled(for: .paragraph2, isBold: true)
        }
    }()

    private lazy var topBarView: UIView = {
        RoundedView().then {
            $0.fillColor = .white

            $0.cornerRadius = 24
            $0.roundingCorners = [.topLeft, .topRight]

            $0.shadowOpacity = 0
            $0.shadowColor = .clear

            $0.heightAnchor == 48
        }
    }()

    private lazy var separatorView: UIView = {
        UIView().then {
            $0.backgroundColor = R.color.baseBorderPrimary()
            $0.layer.cornerRadius = 1.5
            $0.widthAnchor == 36
            $0.heightAnchor == 3
        }
    }()

    private lazy var tableView: UITableView = {
        UITableView().then {
            $0.tableFooterView = UIView()
            $0.backgroundColor = .clear
            $0.separatorStyle = .none
            $0.rowHeight = 56
            $0.register(
                RewardsTableViewCell.self,
                forCellReuseIdentifier: RewardsTableViewCell.reuseIdentifier
            )
            $0.dataSource = self
            $0.delegate = self
        }
    }()

    // MARK: - Private Vars

    private var bottomConstraint: NSLayoutConstraint!

    private var isFullScreen: Bool = false {
        didSet {
            if oldValue != isFullScreen {
                navigationController?
                    .setNavigationBarHidden(isFullScreen, animated: true)
            }
        }
    }

    private var maximumHeightLimit: CGFloat {
        return superview?.maximumHeightLimit ?? view.frame.height
    }

    private var middleHeightLimit: CGFloat {
        return superview?.middleHeightLimit ?? .zero
    }

    private var minimumHeightLimit: CGFloat {
        return superview?.minimumHeightLimit ?? .zero
    }

    private(set) var rewardsViewModels: [RewardsViewModelProtocol] = []

    // MARK: - Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setupLocalization()
        configure()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        updatePosition()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        bottomConstraint.constant = -minimumHeightLimit
        //updatePosition()
    }

    func bind(rewardsViewModels: [RewardsViewModelProtocol]) {
        self.rewardsViewModels = rewardsViewModels
        self.tableView.reloadData()
        updateEmptyState(animated: true)
    }

    // MARK: - PullUpController

    override func pullUpControllerWillMove(to stickyPoint: CGFloat) {
        //print("will move to \(stickyPoint)")
    }

    override func pullUpControllerDidMove(to stickyPoint: CGFloat) {
        //print("did move to \(stickyPoint)")
    }

    override func pullUpControllerDidDrag(to point: CGFloat) {
        //print("did drag to \(point)")
        isFullScreen = (point >= maximumHeightLimit) ? true : false
    }

    override var pullUpControllerPreferredSize: CGSize {
        guard let superview = superview else {
            return CGSize(
                width: UIScreen.main.bounds.width,
                height: view.frame.maxY
            )
        }

        return superview.prefferedSize
    }

    override var pullUpControllerMiddleStickyPoints: [CGFloat] {
        return [middleHeightLimit/*, topBarView.frame.height + minimumHeightLimit*/]
    }
}

// MARK: - Private Methods

private extension RewardsViewController {

    func configure() {

        containerView.do {
            view.addSubview($0)
            $0.topAnchor == view.topAnchor
            $0.bottomAnchor == view.bottomAnchor
            $0.leadingAnchor == view.leadingAnchor
            $0.trailingAnchor == view.trailingAnchor
        }

        topBarView.do {
            containerView.addSubview($0)
            $0.topAnchor == containerView.topAnchor
            $0.leadingAnchor == containerView.leadingAnchor
            $0.trailingAnchor == containerView.trailingAnchor
        }

        titleLabel.do {
            topBarView.addSubview($0)
            $0.leadingAnchor == topBarView.leadingAnchor + 16
            $0.centerYAnchor == topBarView.centerYAnchor
        }

        separatorView.do {
            topBarView.addSubview($0)
            $0.topAnchor == topBarView.topAnchor + 4
            $0.centerXAnchor == topBarView.centerXAnchor
        }

        tableView.do {
            containerView.addSubview($0)
            $0.topAnchor == topBarView.bottomAnchor
            $0.leadingAnchor == containerView.leadingAnchor
            $0.trailingAnchor == containerView.trailingAnchor
            bottomConstraint = ($0.bottomAnchor == containerView.bottomAnchor)
            $0.attach(to: self)
        }
    }

    func updatePosition() {
        pullUpControllerMoveToVisiblePoint(
            middleHeightLimit,
            animated: false, completion: nil
        )
    }

    func setupLocalization() {

        titleLabel.attributedText = R.string.localizable
            .inviteAcceptedInvitationsTitle(preferredLanguages: languages)
            .styled(.paragraph2)
    }
}

// MARK: - Table View

extension RewardsViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rewardsViewModels.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: RewardsTableViewCell.reuseIdentifier, for: indexPath
        ) as? RewardsTableViewCell else {
            fatalError("Could not dequeue cell with identifier: RewardsTableViewCell")
        }

        cell.bind(viewModel: rewardsViewModels[indexPath.row])

        return cell
    }

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - EmptyState

extension RewardsViewController: EmptyStateDelegate {
    var shouldDisplayEmptyState: Bool {
        return rewardsViewModels.isEmpty
    }
}

extension RewardsViewController: EmptyStateDataSource {
    var trimStrategyForEmptyState: EmptyStateView.TrimStrategy {
        return .none
    }

    var viewForEmptyState: UIView? {
        return nil
    }

    var imageForEmptyState: UIImage? {
        return R.image.emptyStateIcon()//invitationsEmptyIconV2()
    }

    var titleForEmptyState: String? {
        return R.string.localizable
            .inviteAcceptedEmptyStateTitle(preferredLanguages: languages)
    }

    var titleColorForEmptyState: UIColor? {
        return R.color.baseContentTertiary()
    }

    var titleFontForEmptyState: UIFont? {
        return UIFont.styled(for: .paragraph2)
    }

    var verticalSpacingForEmptyState: CGFloat? {
        return 16.0
    }

    var appearanceAnimatorForEmptyState: ViewAnimatorProtocol? {
        return TransitionAnimator(type: .fade)
    }
}

extension RewardsViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate {
        return self
    }

    var emptyStateDataSource: EmptyStateDataSource {
        return self
    }

    var contentViewForEmptyState: UIView {
        return containerView
    }

    var displayInsetsForEmptyState: UIEdgeInsets {
        return UIEdgeInsets(top: 80.0, left: 0.0, bottom: 0.0, right: 0.0)
    }
}

// MARK: - Localizable

extension RewardsViewController: Localizable {
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
