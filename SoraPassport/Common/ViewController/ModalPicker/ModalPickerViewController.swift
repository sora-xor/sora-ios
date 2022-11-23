import UIKit
import SoraUI
import SoraFoundation

protocol ModalPickerViewControllerDelegate: class {
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?)
    func modalPickerDidCancel(context: AnyObject?)
    func modalPickerDidSelectAction(context: AnyObject?)
    func modalPickerDidMoveItem(from: Int, to index: Int)
    func modalPickerDidToggle(itemIndex: Int)
    func modalPickerDone(context: AnyObject?)
}

extension ModalPickerViewControllerDelegate {
    func modalPickerDidCancel(context: AnyObject?) {}
    func modalPickerDidSelectAction(context: AnyObject?) {}
    func modalPickerDone(context: AnyObject?) {}
    func modalPickerDidMoveItem(from: Int, to index: Int) {}
    func modalPickerDidToggle(itemIndex: Int) {}
    func modalPickerDidSelectModelAtIndex(_ index: Int, context: AnyObject?) {}
}

enum ModalPickerViewAction {
    case none
    case add
}

class ModalPickerViewController<C: UITableViewCell & ModalPickerCellProtocol, T>: UIViewController, UISearchResultsUpdating,
    ModalViewProtocol, UITableViewDelegate, UITableViewDataSource where T == C.Model {

    @IBOutlet private var headerView: ImageWithTitleView!
    @IBOutlet private var headerBackgroundView: BorderedContainerView!
    @IBOutlet private var headerHeightConstraint: NSLayoutConstraint!
    @IBOutlet private var tableView: UITableView!

    var localizedTitle: LocalizableResource<String>?
    var icon: UIImage?
    var actionType: ModalPickerViewAction = .none

    var cellNib: UINib?
    var cellHeight: CGFloat = 55.0
    var footerHeight: CGFloat = 24.0
    var headerHeight: CGFloat = 0.0
    var cellIdentifier: String = "modalPickerCellId"
    var selectedIndex: Int = 0

    var searchController: UISearchController = UISearchController()

    var hasCloseItem: Bool = false
    var hasDoneItem: Bool = false
    var allowsSelection: Bool = true

    var viewModels: [LocalizableResource<T>] = []
    private var filteredViewModels: [LocalizableResource<T>] = []
    private var models: [LocalizableResource<T>] {
        searchController.isActive ? filteredViewModels : viewModels
    }

    weak var delegate: ModalPickerViewControllerDelegate?
    weak var presenter: ModalPresenterProtocol?

    var context: AnyObject?

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()
        setupLocalization()
    }

    private func configure() {
        if let cellNib = cellNib {
            tableView.register(cellNib, forCellReuseIdentifier: cellIdentifier)
        } else {
            tableView.register(C.self, forCellReuseIdentifier: cellIdentifier)
        }
        tableView.isScrollEnabled = true
        tableView.allowsSelection = allowsSelection
        tableView.isEditing = self.isEditing
        headerHeightConstraint.constant = headerHeight

        searchController.searchResultsUpdater = self
        searchController.hidesNavigationBarDuringPresentation = false
        self.extendedLayoutIncludesOpaqueBars = true
        self.navigationItem.searchController = searchController

        if let icon = icon {
            headerView.iconImage = icon
        } else {
            headerView.spacingBetweenLabelAndIcon = 0
            headerView.isHidden = true
        }

        switch actionType {
        case .add:
            configureAddAction()
        default:
            break
        }

        configureSearch()

        if hasCloseItem {
            centerHeader()
            configureCloseItem()
        }
        if self.isEditing {
            configureDoneItem()
        }
    }

    private func setupLocalization() {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        headerView.title = localizedTitle?.value(for: locale)
        headerView.titleFont = UIFont.styled(for: .title1)
        searchController.searchBar.placeholder = R.string.localizable.search(preferredLanguages: locale.rLanguages)
    }

    private func configureAddAction() {
        let addButton = RoundedButton()
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.roundedBackgroundView?.shadowOpacity = 0.0
        addButton.roundedBackgroundView?.fillColor = .clear
        addButton.roundedBackgroundView?.highlightedFillColor = .clear
        addButton.changesContentOpacityWhenHighlighted = true
        addButton.imageWithTitleView?.spacingBetweenLabelAndIcon = 0.0
        addButton.contentInsets = UIEdgeInsets(top: 20.0, left: 20.0, bottom: 20.0, right: 20.0)
        addButton.imageWithTitleView?.iconImage = R.image.iconCopy()

        headerBackgroundView.addSubview(addButton)

        addButton.trailingAnchor.constraint(equalTo: headerBackgroundView.trailingAnchor).isActive = true
        addButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor).isActive = true

        addButton.addTarget(self, action: #selector(handleAction), for: .touchUpInside)
    }

    private func centerHeader() {
        headerView.trailingAnchor.constraint(equalTo: headerBackgroundView.trailingAnchor,
                                             constant: -20.0).isActive = true
    }

    private func configureSearch() {
        let bar = searchController.searchBar
        bar.backgroundColor = .clear
        bar.clearBackgroundColor()
        bar.changePlaceholderColor(R.color.neumorphism.textDark()!)
        bar.textField?.textColor = R.color.neumorphism.textDark()!
        bar.textField?.font = UIFont.styled(for: .paragraph2)
        bar.setLeftImage(R.image.iconSearch()!, tintColor: R.color.neumorphism.navBarIcon()!)
        bar.showsCancelButton = false
    }

    private func configureCloseItem() {
        let closeButton = RoundedButton()
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.roundedBackgroundView?.shadowOpacity = 0.0
        closeButton.roundedBackgroundView?.fillColor = .clear
        closeButton.roundedBackgroundView?.highlightedFillColor = .clear
        closeButton.changesContentOpacityWhenHighlighted = true
        closeButton.imageWithTitleView?.spacingBetweenLabelAndIcon = 0.0
        closeButton.contentInsets = UIEdgeInsets(top: 20.0, left: 20.0, bottom: 20.0, right: 20.0)
        closeButton.imageWithTitleView?.iconImage = R.image.close()

        headerBackgroundView.addSubview(closeButton)

        closeButton.leadingAnchor.constraint(equalTo: headerBackgroundView.leadingAnchor).isActive = true
        closeButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor).isActive = true

        closeButton.addTarget(self, action: #selector(handleClose), for: .touchUpInside)
    }

    private func configureDoneItem() {
        let closeButtonItem = UIBarButtonItem(title: R.string.localizable.commonDone(preferredLanguages: localizationManager?.selectedLocale.rLanguages),
                                              style: .plain,
                                              target: self,
                                              action: #selector(handleDone))

        self.navigationItem.rightBarButtonItem = closeButtonItem

    }
    // MARK: Table View Delegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        if var oldCell = tableView.cellForRow(at: IndexPath(row: selectedIndex, section: 0)) as? C {
            oldCell.checkmarked = false
        }

        if var newCell = tableView.cellForRow(at: indexPath) as? C {
            newCell.checkmarked = true
        }

        selectedIndex = realIndex(for: indexPath.row)

        self.dismiss(animated: true) { [weak self, selectedIndex] in
            self?.delegate?.modalPickerDidSelectModelAtIndex(selectedIndex, context: self?.context)
        }
    }

    func realIndex(for selectedIndex: Int) -> Int {
        let locale = localizationManager?.selectedLocale ?? Locale.current
        // swiftlint:disable force_cast
        let selected = models[selectedIndex].value(for: locale) as! LoadingIconWithTitleViewModel
        let realIndex = viewModels.firstIndex(where: {
            $0.value(for: locale) as! LoadingIconWithTitleViewModel == selected
        })
        // swiftlint:enable force_cast
        return realIndex ?? 0
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return cellHeight
    }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .none
    }

    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        if searchController.isActive { return false }
        return indexPath.row != 0
    }

    func tableView(_ tableView: UITableView,
                   targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath,
                   toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
        if proposedDestinationIndexPath.row == 0 {
            return IndexPath(row: 1, section: proposedDestinationIndexPath.section)
        }
        return proposedDestinationIndexPath
    }

    // MARK: Table View Data Source

    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let item = viewModels.remove(at: sourceIndexPath.row)
        viewModels.insert(item, at: destinationIndexPath.row)
        delegate?.modalPickerDidMoveItem(from: sourceIndexPath.row, to: destinationIndexPath.row)
        self.tableView.reloadData()
    }

    func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        false
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return models.count
    }

    // swiftlint:disable force_cast
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as! C

        let locale = localizationManager?.selectedLocale ?? Locale.current
        let model = models[indexPath.row].value(for: locale)
        cell.bind(model: model)
        cell.checkmarked = (selectedIndex == indexPath.row)
        cell.showsReorderControl = true
        cell.shouldIndentWhileEditing = false
        if let toggle = cell.toggle {
            toggle.tag = realIndex(for: indexPath.row)
            toggle.addTarget(self, action: #selector(handleToggle), for: .valueChanged)
        }
        return cell
    }
    // swiftlint:enable force_cast

    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        if let presenter = presenter {
            presenter.hide(view: self, animated: flag)
            completion?()
        } else {
            self.presentingViewController?.dismiss(animated: true, completion: completion)
        }
    }

    @objc private func handleToggle(sender: UISwitch) {
        delegate?.modalPickerDidToggle(itemIndex: sender.tag)
    }

    @objc private func handleAction() {
        delegate?.modalPickerDidSelectAction(context: context)
        presenter?.hide(view: self, animated: true)
    }

    @objc private func handleClose() {
        presenter?.hide(view: self, animated: true)
    }

    @objc private func handleDone() {
        self.dismiss(animated: true, completion: {[weak self] in
            self?.delegate?.modalPickerDone(context: nil)
        })
    }

    func updateSearchResults(for searchController: UISearchController) {
        if let text = searchController.searchBar.text {
            let locale = localizationManager?.selectedLocale ?? Locale.current
            let result = text.isEmpty ? viewModels : viewModels.filter {

                // swiftlint:disable force_cast
                let model = $0.value(for: locale) as! LoadingIconWithTitleViewModel
                // swiftlint:enable force_cast

                return model.title.localizedCaseInsensitiveContains(text) || (model.subtitle ?? "").localizedCaseInsensitiveContains(text)
            }
            print(result.map {$0.value(for: locale)})
            filteredViewModels = result
            tableView.reloadData()
            reloadEmptyState(animated: false)
        }

    }
}

extension ModalPickerViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            headerView.setNeedsLayout()
            tableView.reloadData()
        }
    }
}

extension ModalPickerViewController: ModalPresenterDelegate {
    func presenterDidHide(_ presenter: ModalPresenterProtocol) {
        delegate?.modalPickerDidCancel(context: context)
    }
}

extension ModalPickerViewController: EmptyStateDelegate {
    var configurationDataSource: EmptyStateDataSource { WalletEmptyStateDataSource.searchAssets
    }

    var shouldDisplayEmptyState: Bool {
        guard filteredViewModels.isEmpty  else {
            return false
        }

        return true
    }
}

extension ModalPickerViewController: EmptyStateDataSource {
    
    var viewForEmptyState: UIView? {
        return nil
    }

    var contentViewForEmptyState: UIView {
        return view
    }

    var imageForEmptyState: UIImage? {
        return configurationDataSource.imageForEmptyState
    }

    var titleForEmptyState: String? {
        return configurationDataSource.titleForEmptyState
    }

    var titleColorForEmptyState: UIColor? {
        return configurationDataSource.titleColorForEmptyState
    }

    var titleFontForEmptyState: UIFont? {
        return configurationDataSource.titleFontForEmptyState
    }

    var verticalSpacingForEmptyState: CGFloat? {
        return configurationDataSource.verticalSpacingForEmptyState
    }

    var trimStrategyForEmptyState: EmptyStateView.TrimStrategy {
        return configurationDataSource.trimStrategyForEmptyState ?? .none
    }
}

extension ModalPickerViewController: EmptyStateViewOwnerProtocol {
    var emptyStateDelegate: EmptyStateDelegate {
        return self
    }

    var emptyStateDataSource: EmptyStateDataSource {
        return self
    }

    var displayInsetsForEmptyState: UIEdgeInsets {
        return .zero
    }
}
