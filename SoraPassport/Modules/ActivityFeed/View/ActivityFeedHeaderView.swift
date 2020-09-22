import UIKit
import SoraUI
import SoraFoundation

final class ActivityFeedHeaderView: UICollectionReusableView, Localizable {
    @IBOutlet private(set) var titleLabel: UILabel!
    @IBOutlet private(set) var helpButton: RoundedButton!

    override func awakeFromNib() {
        super.awakeFromNib()

        setupLocalization()
    }

    private func setupLocalization() {
        let languages = localizationManager?.preferredLocalizations
        titleLabel.text = R.string.localizable.activity(preferredLanguages: languages)
    }

    func applyLocalization() {
        setupLocalization()

        if superview != nil {
            setNeedsLayout()
        }
    }
}
