import UIKit
import SoraFoundation

final class AnnouncementCollectionViewCell: UICollectionViewCell, Localizable {
    @IBOutlet private(set) var titleLabel: UILabel!
    @IBOutlet private(set) var detailsLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()

        setupLocalization()
    }

    func bind(viewModel: AnnouncementItemViewModelProtocol) {
        detailsLabel.text = viewModel.content.message
    }

    private func setupLocalization() {
        let languages = localizationManager?.preferredLocalizations
        titleLabel.text = R.string.localizable.activitySoraAnnouncement(preferredLanguages: languages)
    }

    func didChangeLocalizationManager(from oldManager: LocalizationManagerProtocol?,
                                      to newManager: LocalizationManagerProtocol?) {
        setupLocalization()
    }

    func applyLocalization() {
        setupLocalization()

        if superview != nil {
            setNeedsLayout()
        }
    }
}
