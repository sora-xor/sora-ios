import UIKit

final class TitleTableViewCell: UITableViewCell {
    @IBOutlet private var titleLabel: UILabel!

    func bind(title: String) {
        titleLabel.text = title
    }
}
