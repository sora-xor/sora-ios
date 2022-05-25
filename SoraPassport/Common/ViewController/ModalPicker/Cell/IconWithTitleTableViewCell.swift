import UIKit

class IconWithTitleTableViewCell: UITableViewCell, ModalPickerCellProtocol {
    typealias Model = IconWithTitleViewModel

    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var iconImageView: UIImageView!
    @IBOutlet private var checkmarkImageView: UIImageView!

    var checkmarked: Bool {
        get {
            !checkmarkImageView.isHidden
        }

        set {
            checkmarkImageView.isHidden = !newValue
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()

        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = R.color.themeAccent()!.withAlphaComponent(0.3)
        self.selectedBackgroundView = selectedBackgroundView
    }

    func bind(model: Model) {
        titleLabel.text = model.title
        iconImageView.image = model.icon
    }
}

class LoadingIconWithTitleTableViewCell: UITableViewCell, ModalPickerCellProtocol {
    typealias Model = LoadingIconWithTitleViewModel

    @IBOutlet private var titleLabel: UILabel!
    @IBOutlet private var subtitleLabel: UILabel!
    @IBOutlet private var iconImageView: UIImageView!
    @IBOutlet private var checkmarkImageView: UIImageView!

    var checkmarked: Bool {
        get {
            !checkmarkImageView.isHidden
        }

        set {
            checkmarkImageView.isHidden = !newValue
        }
    }

    var toggle: UISwitch? = UISwitch()

    override func awakeFromNib() {
        super.awakeFromNib()

        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = R.color.themeAccent()!.withAlphaComponent(0.3)
        self.selectedBackgroundView = selectedBackgroundView
        self.editingAccessoryView = toggle
        toggle?.onTintColor = R.color.neumorphism.tint()!
        self.iconImageView.image = nil

        titleLabel.font = UIFont.styled(for: .display2, isBold: true).withSize(15)
        subtitleLabel.font = UIFont.styled(for: .paragraph2, isBold: false).withSize(11)
    }

    func bind(model: Model) {
        titleLabel.text = model.title
        subtitleLabel.text = model.subtitle ?? ""
        model.iconViewModel?.loadImage { [weak self] (icon, _) in
            self?.iconImageView.image = icon
        }
        toggle?.isOn = model.toggle
    }
}
