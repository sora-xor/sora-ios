import UIKit
import SoraUI
import SoraFoundation

final class OnboardingMainViewController: UIViewController, OnboardingMainViewProtocol, HiddableBarWhenPushed {
    var presenter: OnboardingMainPresenterProtocol!

    @IBOutlet weak var logo: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var createAccountButton: NeumorphismButton!
    @IBOutlet weak var importAccountButton: NeumorphismButton!

    @IBOutlet weak var logoTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var logoToTitleConstraint: NSLayoutConstraint!
    @IBOutlet weak var titleToSubtitleConstraint: NSLayoutConstraint!
    @IBOutlet weak var subtitleToDescriptionConstraint: NSLayoutConstraint!

    let soraLabelText = "SORA"

    var locale: Locale?

    override func viewDidLoad() {
        super.viewDidLoad()

        configure()
        adjustLayout()
        presenter.setup()
    }

    func configure() {
        view.backgroundColor = R.color.neumorphism.base()
        logo.image = R.image.soraLogoBig()
        configureLabels()
        configureButtons()
    }

    func configureLabels() {
        let locale = locale ?? Locale.current

        titleLabel.text =  R.string.localizable.tutorialManyWorld(preferredLanguages: locale.rLanguages)
        subtitleLabel.text = soraLabelText
        descriptionLabel.text = R.string.localizable.tutorialManyWorldDesc(preferredLanguages: locale.rLanguages)

        titleLabel.textColor = R.color.neumorphism.textDark()
        subtitleLabel.textColor = R.color.neumorphism.tint()
        descriptionLabel.textColor = R.color.neumorphism.textDark()

        titleLabel.font = UIFont.styled(for: .display1)
        subtitleLabel.font = UIFont.styled(for: .display1)
        descriptionLabel.font = UIFont.styled(for: .paragraph2)
    }

    fileprivate func configureButtons() {
        let locale = locale ?? Locale.current

        createAccountButton.setTitle(R.string.localizable.create_account_title(preferredLanguages: locale.rLanguages), for: .normal)
        createAccountButton.font = UIFont.styled(for: .button)
        createAccountButton.color = R.color.neumorphism.tint()!
        importAccountButton.setTitle(R.string.localizable.recoveryTitleV2(preferredLanguages: locale.rLanguages), for: .normal)
        importAccountButton.font = UIFont.styled(for: .button)
        importAccountButton.setTitleColor(R.color.neumorphism.buttonTextDark(), for: .normal)
    }

    func adjustLayout() {
        if UIScreen.main.bounds.height <= 568 {
            logoTopConstraint.constant = 8
            logoToTitleConstraint.constant = 8
            titleToSubtitleConstraint.constant = 0

            descriptionLabel.font = UIFont.styled(for: .paragraph3)
        }
    }

    @IBAction func createAccountPressed(_ sender: Any) {
        presenter.activateSignup()
    }

    @IBAction func importAccountPressed(_ sender: Any) {
        presenter.activateAccountRestore()
    }
}
