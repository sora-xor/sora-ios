import UIKit
import SoraFoundation
import SoraUI

final class AccountCreateViewController: UIViewController {
    enum Mode {
        case registration
        case view
    }

    var presenter: AccountCreatePresenterProtocol!

    @IBOutlet private var scrollView: UIScrollView!
    @IBOutlet private var stackView: UIStackView!
    @IBOutlet private var detailsLabel: UILabel!
    @IBOutlet private var explainLabel: UILabel!
    @IBOutlet private var mnemonicContainer: BorderedContainerView!

    @IBOutlet var copyButton: SoraButton!
    @IBOutlet var nextButton: SoraButton!

    var mode: Mode = .registration

    private var derivationPathModel: InputViewModelProtocol?

    var keyboardHandler: KeyboardHandler?

    var advancedAppearanceAnimator = TransitionAnimator(type: .push,
                                                        duration: 0.35,
                                                        subtype: .fromBottom,
                                                        curve: .easeOut)

    var advancedDismissalAnimator = TransitionAnimator(type: .push,
                                                       duration: 0.35,
                                                       subtype: .fromTop,
                                                       curve: .easeIn)

    private var mnemonicView: MnemonicDisplayView?

    override func viewDidLoad() {
        super.viewDidLoad()

        setupNavigationItem()
        setupLocalization()
        configure()

        presenter.setup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if keyboardHandler == nil {
            setupKeyboardHandler()
        }
        if mode == .view {

        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        clearKeyboardHandler()
    }

    private func configure() {
        stackView.arrangedSubviews.forEach { $0.backgroundColor = R.color.brandWhite() }

        detailsLabel.font = UIFont.styled(for: .paragraph1)
        explainLabel.font = UIFont.styled(for: .paragraph3)
        if mode == .view {
            let view = nextButton.superview!
            view.addSubview(copyButton)
            copyButton.fillColor = R.color.themeAccent()!
            copyButton.roundedBackgroundView!.highlightedFillColor = R.color.themeAccentPressed()!
            copyButton.imageWithTitleView?.iconTintColor = .white
            copyButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16).isActive = true
            copyButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16).isActive = true
            copyButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
            copyButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24).isActive = true
            copyButton.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 24).isActive = true

            nextButton.removeFromSuperview()
        } else {
            copyButton.fillColor = R.color.baseBackground()!
            copyButton.roundedBackgroundView!.highlightedFillColor = R.color.baseBackgroundHover()!
            copyButton.imageWithTitleView?.iconTintColor = R.color.baseContentPrimary()
        }
    }

    private func setupNavigationItem() {
        let infoItem = UIBarButtonItem(image: R.image.linkInfo(),
                                       style: .plain,
                                       target: self,
                                       action: #selector(actionOpenInfo))
        navigationItem.rightBarButtonItem = infoItem
    }

    private func setupMnemonicViewIfNeeded() {
        guard mnemonicView == nil else {
            return
        }

        let mnemonicView = MnemonicDisplayView()

        if let indexColor = R.color.baseContentQuaternary() {
            mnemonicView.indexTitleColorInColumn = indexColor
        }

        if let titleColor = R.color.baseContentPrimary() {
            mnemonicView.wordTitleColorInColumn = titleColor
        }

        mnemonicView.indexFontInColumn = UIFont.styled(for: .paragraph1)
        mnemonicView.wordFontInColumn =  UIFont.styled(for: .paragraph1)
        mnemonicView.backgroundColor = R.color.brandWhite()
        mnemonicView.translatesAutoresizingMaskIntoConstraints = false
        mnemonicContainer.addSubview(mnemonicView)
        mnemonicView.leadingAnchor.constraint(equalTo: mnemonicContainer.leadingAnchor, constant: -16).isActive = true
        mnemonicView.trailingAnchor.constraint(equalTo: mnemonicContainer.trailingAnchor, constant: 0).isActive = true
        mnemonicView.topAnchor.constraint(equalTo: mnemonicContainer.topAnchor, constant: 8).isActive = true
        mnemonicView.bottomAnchor.constraint(equalTo: mnemonicContainer.bottomAnchor, constant: -8).isActive = true
        self.mnemonicView = mnemonicView
    }

    private func setupLocalization() {
        let locale = localizationManager?.selectedLocale ?? Locale.current

        title = R.string.localizable.mnemonicTitle(preferredLanguages: locale.rLanguages)
        detailsLabel.text = R.string.localizable.mnemonicText(preferredLanguages: locale.rLanguages)
        explainLabel.text = R.string.localizable
            .commonPassphraseBody(preferredLanguages: locale.rLanguages)
        nextButton.title = R.string.localizable
            .transactionContinue(preferredLanguages: locale.rLanguages)
    }

    @IBAction private func actionNext() {
        presenter.proceed()
    }

    @IBAction private func actionCopy() {
        presenter.copy()
    }

    @objc private func actionOpenInfo() {
        presenter.activateInfo()
    }
}

extension AccountCreateViewController: AccountCreateViewProtocol {
    func set(mnemonic: [String]) {
        setupMnemonicViewIfNeeded()
        var conditionedMnemonic = mnemonic
        if mnemonic.count % 2 == 1 {
            conditionedMnemonic.append("") //Quick fix for legacy 15-word mnemonics
        }
        mnemonicView?.bind(words: conditionedMnemonic, columnsCount: 2)
    }
}

extension AccountCreateViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()

        return false
    }

    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {

        guard let viewModel = derivationPathModel else {
            return true
        }

        let shouldApply = viewModel.inputHandler.didReceiveReplacement(string, for: range)

        if !shouldApply, textField.text != viewModel.inputHandler.value {
            textField.text = viewModel.inputHandler.value
        }

        return shouldApply
    }
}

extension AccountCreateViewController: KeyboardAdoptable {
    func updateWhileKeyboardFrameChanging(_ frame: CGRect) {
        let localKeyboardFrame = view.convert(frame, from: nil)
        let bottomInset = view.bounds.height - localKeyboardFrame.minY
        let scrollViewOffset = view.bounds.height - scrollView.frame.maxY

        var contentInsets = scrollView.contentInset
        contentInsets.bottom = max(0.0, bottomInset - scrollViewOffset)
        scrollView.contentInset = contentInsets
    }
}

extension AccountCreateViewController: Localizable {
    func applyLocalization() {
        if isViewLoaded {
            setupLocalization()
            view.setNeedsLayout()
        }
    }
}
