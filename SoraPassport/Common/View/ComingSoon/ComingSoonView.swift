import UIKit

class ComingSoonView: UIView {

    @IBOutlet private var label: UILabel!
    @IBOutlet private var imageView: UIImageView!
    @IBOutlet private var link: UIButton!
    @IBOutlet private var title: UILabel!

    var text: String? {
        didSet {
            label.text = text
        }
    }

    var titleText: String? {
        didSet {
            title.text = titleText
        }
    }

    var image: UIImage? {
        didSet {
            imageView.image = image
        }
    }

    var linkTitle: String? {
        didSet {
            link.setAttributedTitle(linkTitle?.decoratedWith(
                [.font: UIFont.styled(for: .paragraph1),
                 .foregroundColor: R.color.brandSoramitsuRed()!,
                 .underlineStyle: NSUnderlineStyle.single.rawValue],
                adding: [:], to: []), for: .normal)
        }
    }
    var tapClosure: (() -> Void)?

    override func awakeFromNib() {
        super.awakeFromNib()
        link.addTarget(self, action: #selector(onTap), for: .touchUpInside)
        label.font = UIFont.styled(for: .paragraph1)
        title.font = UIFont.styled(for: .button, isBold: true).withSize(13)
    }

    @objc func onTap(sender: Any) {
        tapClosure?()
    }
}
