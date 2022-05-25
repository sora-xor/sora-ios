import UIKit
import Rswift
import SoraFoundation

final class LanguageSelectionViewController: SelectionListViewController<SelectionSubtitleTableViewCell> {
    var presenter: LanguageSelectionPresenterProtocol!

    override var selectableCellIdentifier: ReuseIdentifier<SelectionSubtitleTableViewCell>! {
        return R.reuseIdentifier.selectionSubtitleCellId
    }

    override var selectableCellNib: UINib? {
        return UINib(resource: R.nib.selectionSubtitleTableViewCell)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = R.color.baseBackground()
        navigationItem.largeTitleDisplayMode = .never

        applyLocalization()

        presenter.setup()
    }
}

extension LanguageSelectionViewController: LanguageSelectionViewProtocol {}

extension LanguageSelectionViewController: Localizable {
    func applyLocalization() {
        let languages = localizationManager?.preferredLocalizations
        title = R.string.localizable.profileLanguageTitle(preferredLanguages: languages)
    }
}
