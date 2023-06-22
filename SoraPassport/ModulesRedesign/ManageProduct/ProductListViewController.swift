import Foundation
import UIKit
import SoraUIKit

final class ProductListViewController: SoramitsuViewController {

    private let searchController = UISearchController(searchResultsController: nil)

    private lazy var tableView: SoramitsuTableView = {
        let tableView = SoramitsuTableView(type: .plain)
        tableView.sora.backgroundColor = .bgSurface
        tableView.sectionHeaderHeight = 0
        tableView.sora.cornerMask = .all
        tableView.sora.cornerRadius = .extraLarge
        tableView.sora.shadow = .default
        tableView.sora.estimatedRowHeight = UITableView.automaticDimension
        tableView.sora.context = SoramitsuTableViewContext(scrollView: tableView, viewController: self)
        tableView.sectionHeaderHeight = .zero
        tableView.dragInteractionEnabled = true
        tableView.dragDelegate = self
        tableView.tableViewObserver = self
        tableView.scrollViewDelegate = self
        tableView.keyboardDismissMode = .onDrag
        tableView.contentInset = UIEdgeInsets(top: 16, left: 0, bottom: -16, right: 0)
        return tableView
    }()

    var viewModel: Produtable

    init(viewModel: Produtable) {
        self.viewModel = viewModel
        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        setupConstraints()

        searchController.searchBar.placeholder = viewModel.searchBarPlaceholder
        searchController.searchResultsUpdater = self
        searchController.delegate = self
        searchController.obscuresBackgroundDuringPresentation = false

        navigationItem.searchController = searchController

        navigationItem.title = viewModel.mode == .selection ? R.string.localizable.chooseToken(preferredLanguages: .currentLocale) : ""
        
        if viewModel.mode == .selection {
            addCloseButton(position: .left)
            
            let editButton = UIBarButtonItem(title: R.string.localizable.commonEdit(preferredLanguages: .currentLocale), style: .plain, target: self, action: #selector(editTapped))
            editButton.setTitleTextAttributes([
                .font: UIFont.systemFont(ofSize: 13, weight: .bold),
                .foregroundColor: SoramitsuUI.shared.theme.palette.color(.accentPrimary)],
                                              for: .normal)
            navigationItem.rightBarButtonItem = editButton
        }
        

        viewModel.reloadItems = { [weak self] item in
            UIView.performWithoutAnimation {
                self?.tableView.reloadItems(items: item)
            }
        }

        viewModel.setupItems = { [weak self] items in
            DispatchQueue.main.async {
                UIView.performWithoutAnimation {
                    self?.tableView.sora.sections = [ SoramitsuTableViewSection(rows: items) ]
                }
            }
        }

        viewModel.setupNavigationBar = { [weak self] mode in
            guard let self = self else {
                return
            }
                
            self.navigationItem.leftBarButtonItem = mode == .edit ? nil : UIBarButtonItem(image: R.image.wallet.cross(),
                                                                                           style: .plain,
                                                                                           target: self,
                                                                                          action: #selector(self.crossButtonTapped))

            if mode == .edit || mode == .view {
                let button = UIBarButtonItem(title: mode == .edit ? R.string.localizable.commonDone(preferredLanguages: .currentLocale) : R.string.localizable.commonEdit(preferredLanguages: .currentLocale),
                                             style: .plain,
                                             target: self,
                                             action: mode == .edit ? #selector(self.doneTapped) : #selector(self.editTapped) )
                button.setTitleTextAttributes([ .font: UIFont.systemFont(ofSize: 13, weight: .bold),
                                                .foregroundColor: UIColor(hex: "#EE2233")],
                                              for: .normal)
                self.navigationItem.rightBarButtonItem = button
            } else {
                self.navigationItem.rightBarButtonItem = nil
            }
        }
        
        viewModel.dissmiss = { [weak self] isNeedForce in
            DispatchQueue.main.async {
                if self?.presentedViewController == nil || isNeedForce {
                    self?.navigationItem.searchController?.isActive = false
                    self?.dismiss(animated: true)
                }
            }
        }
        
        viewModel.viewDidLoad()
    }

    @objc
    func editTapped() {
        viewModel.mode = .edit
        tableView.dragInteractionEnabled = true
    }

    @objc
    func doneTapped() {
        viewModel.mode = .view
        tableView.dragInteractionEnabled = false
    }
    
    @objc
    func crossButtonTapped() {
        viewModel.viewDissmissed()
        self.dismiss(animated: true)
    }

    private func setupView() {
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        view.addSubview(tableView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            tableView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }
}

extension ProductListViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        viewModel.searchText = searchController.searchBar.text ?? ""
    }
}

extension ProductListViewController: UITableViewDragDelegate {
    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        let dragItem = UIDragItem(itemProvider: NSItemProvider())
        dragItem.localObject = viewModel.items[indexPath.row].title
        return [ dragItem ]
    }
}

extension ProductListViewController: UISearchControllerDelegate {
    func willPresentSearchController(_ searchController: UISearchController) {
        viewModel.isActiveSearch = true
    }

    func willDismissSearchController(_ searchController: UISearchController) {
        viewModel.isActiveSearch = false
    }
}

extension ProductListViewController: SoramitsuTableViewObserver {
    func didSelectRow(at indexPath: IndexPath) {
        //TODO: Add transition to asset detail
    }

    func didMoveRow(at sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard viewModel.canMoveAsset(from: sourceIndexPath.row, to: destinationIndexPath.row) else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.tableView.beginUpdates()
                self.tableView.moveRow(at: destinationIndexPath, to: sourceIndexPath)
                self.tableView.endUpdates()
            }
            return
        }

        viewModel.didMoveAsset(from: sourceIndexPath.row, to: destinationIndexPath.row)
    }
}

extension ProductListViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.isTracking, scrollView.contentOffset.y < -236 {
            close()
        }
    }
}
