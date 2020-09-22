import UIKit
import SoraFoundation

final class PersonalInfoViewController: AccessoryViewController, AdaptiveDesignable {
    var presenter: PersonalInfoPresenterProtocol!

    private(set) var models: [InputViewModelProtocol] = []

    @IBOutlet private var tableView: UITableView!

    private var contentWidth: CGFloat = 375.0

    // MARK: Initialization

    override func viewDidLoad() {
        super.viewDidLoad()

        adjustLayout()

        configureTableView()

        presenter.load()
    }

    override func setupLocalization() {
        super.setupLocalization()

        title = R.string.localizable
            .personalInfoTitle(preferredLanguages: localizationManager?.selectedLocale.rLanguages)
    }

    private func adjustLayout() {
        contentWidth *= designScaleRatio.width
    }

    private func configureTableView() {
        tableView.register(UINib(resource: R.nib.personalInfoCell),
                           forCellReuseIdentifier: R.reuseIdentifier.personalInfoCellId.identifier)

        setupTableFooter(for: nil)
    }

    private func setupTableFooter(for viewModel: PersonalInfoFooterViewModel?) {
        guard let viewModel = viewModel else {
            tableView.tableFooterView = nil
            return
        }

        var footerView = tableView.tableFooterView as? PersonalInfoFooterView

        if footerView == nil {
            footerView = R.nib.personalInfoFooterView(owner: nil)
        }

        footerView?.bind(viewModel: viewModel)

        if let footerView = footerView {
            let size = footerView.sizeThatFits(CGSize(width: contentWidth,
                                                      height: CGFloat.greatestFiniteMagnitude))
            footerView.frame = CGRect(origin: .zero, size: size)
        }

        tableView.tableFooterView = footerView
    }

    override func updateBottom(inset: CGFloat) {
        var contentInset = tableView.contentInset
        contentInset.bottom = inset
        tableView.contentInset = contentInset
    }

    private func startEditing(at index: Int, section: Int) {
        let nextIndexPath = IndexPath(row: index, section: section)
        guard let nextCell = tableView.cellForRow(at: nextIndexPath) as? PersonalInfoCell else {
            return
        }

        nextCell.textField.becomeFirstResponder()

        tableView.scrollToRow(at: nextIndexPath,
                              at: .bottom,
                              animated: true)
    }

    // MARK: Actions

    override func actionAccessory() {
        tableView.visibleCells.forEach { ($0 as? PersonalInfoCell)?.textField.resignFirstResponder() }

        presenter.register()
    }

    private func updateAccessoryState() {
        accessoryView?.isActionEnabled = models
            .first(where: { $0.inputHandler.required && !$0.inputHandler.completed }) == nil
    }
}

extension PersonalInfoViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return models.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: R.reuseIdentifier.personalInfoCellId,
                                                 for: indexPath)!

        cell.bind(model: models[indexPath.row])
        cell.delegate = self

        return cell
    }
}

extension PersonalInfoViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)

        if let cell = tableView.cellForRow(at: indexPath) as? PersonalInfoCell {
            cell.textField.becomeFirstResponder()
        }
    }
}

extension PersonalInfoViewController: PersonalInfoCellDelegate {
    func didSelectNext(on cell: PersonalInfoCell) {
        guard let indexPath = tableView.indexPath(for: cell) else {
            return
        }

        cell.isError = !models[indexPath.row].inputHandler.completed

        let optionalNextIndex = ((indexPath.row + 1)..<models.count).first { models[$0].inputHandler.enabled }

        if let nextIndex = optionalNextIndex {
            startEditing(at: nextIndex, section: indexPath.section)
        } else {
            cell.textField.resignFirstResponder()
        }
    }

    func didChangeValue(in cell: PersonalInfoCell) {
        updateAccessoryState()
    }
}

extension PersonalInfoViewController: PersonalInfoViewProtocol {
    func didReceive(viewModels: [InputViewModelProtocol]) {
        models = viewModels
        tableView.reloadData()

        updateAccessoryState()
    }

    func didReceive(footerViewModel: PersonalInfoFooterViewModel?) {
        setupTableFooter(for: footerViewModel)
    }

    func didStartEditing(at index: Int) {
        startEditing(at: index, section: 0)
    }
}
