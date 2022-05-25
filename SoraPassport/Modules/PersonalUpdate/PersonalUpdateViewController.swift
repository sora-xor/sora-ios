import UIKit
import Then
import Anchorage
import SoraFoundation

final class PersonalUpdateViewController: UIViewController, AdaptiveDesignable {
	var presenter: PersonalUpdatePresenterProtocol!

    @IBOutlet private var tableView: UITableView!

    private(set) var models: [InputViewModelProtocol] = []

    private var keyboardHandler: KeyboardHandler?

    private var hasChanges: Bool = false

    private lazy var contentWidth: CGFloat = baseDesignSize.width

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = R.color.baseBackground()
        adjustLayout()
        configureTableView()
        configureSaveButton()
        applyLocalization()

        updateActionState()

        presenter.setup()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        setupKeyboardHandler()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        clearKeyboardHandler()
    }

    private func adjustLayout() {
        contentWidth *= designScaleRatio.width
    }

    private func configureTableView() {
        tableView.register(R.nib.personalInfoCell)
        tableView.backgroundColor = .clear
        let footerText = R.string.localizable.personalDetailsInfo(preferredLanguages: languages)
        let footerViewModel = PersonalInfoFooterViewModel(text: footerText)
        setupTableFooter(for: footerViewModel)
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

        footerView?.titleLabel.font = UIFont.styled(for: .paragraph3)
        footerView?.titleLabel.textColor = R.color.baseContentQuaternary()

        footerView?.bind(viewModel: viewModel)

        if let footerView = footerView {
            let size = footerView.sizeThatFits(CGSize(width: contentWidth,
                                                      height: CGFloat.greatestFiniteMagnitude))
            footerView.frame = CGRect(origin: .zero, size: size)
        }

        tableView.tableFooterView = footerView
    }

    private func configureSaveButton() {
        let saveButton = UIBarButtonItem(
            title: R.string.localizable.commonDone(preferredLanguages: languages),
            style: .plain,
            target: self,
            action: #selector(actionSave(sender:))
        )

        var normalTextAttributes = [NSAttributedString.Key: Any]()
        normalTextAttributes[.foregroundColor] = R.color.baseContentPrimary()
        normalTextAttributes[.font] = UIFont.styled(for: .paragraph1)

        saveButton.setTitleTextAttributes(normalTextAttributes, for: .normal)

        var disabledTextAttributes = [NSAttributedString.Key: Any]()
        disabledTextAttributes[.foregroundColor] = R.color.baseOnDisabled()
        disabledTextAttributes[.font] = UIFont.styled(for: .paragraph1)

        saveButton.setTitleTextAttributes(disabledTextAttributes, for: .disabled)

        navigationItem.rightBarButtonItem = saveButton
    }

    // MARK: Keyboard

    private func setupKeyboardHandler() {
        keyboardHandler = KeyboardHandler()
        keyboardHandler?.animateOnFrameChange = animateKeyboardChange
    }

    private func animateKeyboardChange(keyboardFrame: CGRect) {
        let localKeyboardFrame = view.convert(keyboardFrame, from: nil)

        let margin = tableView.frame.maxY - localKeyboardFrame.minY

        var contentInset = tableView.contentInset

        if margin > 0.0 {
            tableView.isScrollEnabled = true
            contentInset.bottom = margin
        } else {
            tableView.isScrollEnabled = false
            contentInset.bottom = 0.0
        }

        tableView.contentInset = contentInset
    }

    private func clearKeyboardHandler() {
        keyboardHandler = nil
    }

    // MARK: Actions

    @objc private func actionSave(sender: AnyObject) {
        tableView.visibleCells.forEach { ($0 as? PersonalInfoCell)?.textField.resignFirstResponder() }

        presenter.save()
    }

    private func updateActionState() {
        guard let rightBarButtonItem = navigationItem.rightBarButtonItem else {
            return
        }

        rightBarButtonItem.isEnabled = hasChanges &&
            (models.first { $0.inputHandler.required && !$0.inputHandler.completed } == nil)
    }
}

extension PersonalUpdateViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return models.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: R.reuseIdentifier.personalInfoCellId, for: indexPath)!

        cell.titleLabel.font = UIFont.styled(for: .paragraph2)
        cell.textField.font = UIFont.styled(for: .paragraph2)
        cell.normalColor = R.color.baseContentTertiary()!
        cell.bind(model: models[indexPath.row])
        cell.delegate = self

        return cell
    }
}

extension PersonalUpdateViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)

        if let cell = tableView.cellForRow(at: indexPath) as? PersonalInfoCell {
            cell.textField.becomeFirstResponder()
        }
    }
}

extension PersonalUpdateViewController: PersonalInfoCellDelegate {
    func didSelectNext(on cell: PersonalInfoCell) {
        guard let indexPath = tableView.indexPath(for: cell) else {
            return
        }

        cell.isError = !models[indexPath.row].inputHandler.completed

        let optionalNextIndex = ((indexPath.row + 1)..<models.count).first { models[$0].inputHandler.enabled }

        if let nextIndex = optionalNextIndex {
            let nextIndexPath = IndexPath(row: nextIndex, section: indexPath.section)
            guard let nextCell = tableView.cellForRow(at: nextIndexPath) as? PersonalInfoCell else {
                return
            }

            nextCell.textField.becomeFirstResponder()

            tableView.scrollToRow(at: nextIndexPath, at: .bottom, animated: true)
        } else {
            cell.textField.resignFirstResponder()
        }
    }

    func didChangeValue(in cell: PersonalInfoCell) {
        hasChanges = true

        updateActionState()
    }
}

extension PersonalUpdateViewController: PersonalUpdateViewProtocol {
    func didReceive(viewModels: [InputViewModelProtocol]) {
        models = viewModels
        tableView.reloadData()
    }

    func didStartSaving() {
        hasChanges = false

        updateActionState()
    }

    func didCompleteSaving(success: Bool) {
        hasChanges = !success

        updateActionState()
    }
}

// MARK: - Localizable

extension PersonalUpdateViewController: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    func applyLocalization() {
        navigationItem.title = R.string.localizable
            .personalInfoUsernameV1(preferredLanguages: languages)
    }
}
