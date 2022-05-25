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
    @IBOutlet private var mnemonicContainer: BorderedContainerView!

    @IBOutlet var shareButton: NeumorphismButton!
    @IBOutlet var nextButton: NeumorphismButton!

    @IBOutlet weak var topToRedSignConstraint: NSLayoutConstraint!
    @IBOutlet weak var stackHeightConstraint: NSLayoutConstraint!

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
        adjustLayout()
        setupLocalization()
        configure()

        presenter.setup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if keyboardHandler == nil {
            setupKeyboardHandler()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        clearKeyboardHandler()
    }

    private func adjustLayout() {
        if UIScreen.main.bounds.size.height <= 568 {
            stackHeightConstraint.constant = 390
        } else if UIScreen.main.bounds.size.height > 667 {
            topToRedSignConstraint.constant = (UIScreen.main.bounds.size.height - 667) / 2.0
        }
    }

    private func configure() {
        view.backgroundColor = R.color.neumorphism.base()

        detailsLabel.font = UIFont.styled(for: .paragraph1)

        shareButton.tintColor = R.color.neumorphism.buttonTextDark()
        shareButton.setImage(R.image.shareArrow(), for: .normal)
        shareButton.color = R.color.neumorphism.buttonLightGrey()!
        nextButton.color = R.color.neumorphism.tint()!
        nextButton.font = UIFont.styled(for: .button)

        if mode == .view {
            let view = nextButton.superview!
            view.addSubview(shareButton)
            shareButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16).isActive = true
            shareButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16).isActive = true
            shareButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
            shareButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24).isActive = true
            shareButton.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 24).isActive = true

            nextButton.removeFromSuperview()
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
        mnemonicView.indexTitleColorInColumn = R.color.neumorphism.textDark()!
        mnemonicView.wordTitleColorInColumn = R.color.neumorphism.textDark()!
        mnemonicView.indexFontInColumn = UIFont.styled(for: .paragraph1)
        mnemonicView.wordFontInColumn =  UIFont.styled(for: .paragraph1, isBold: true)
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

        title = R.string.localizable.mnemonicTitle(preferredLanguages: locale.rLanguages).capitalized
        detailsLabel.text = R.string.localizable.mnemonicText(preferredLanguages: locale.rLanguages)
        nextButton.setTitle(R.string.localizable
                                .transactionContinue(preferredLanguages: locale.rLanguages), for: .normal)
    }

    @IBAction private func actionNext() {
        presenter.proceed()
    }

    @IBAction private func actionShare() {
        presenter.share()
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
