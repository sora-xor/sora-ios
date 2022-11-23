import UIKit

class PswapButton: NeumorphismButton {
    @IBOutlet weak var leftImageView: UIImageView!
    @IBOutlet weak var rightImageView: UIImageView!
    @IBOutlet weak var customLabel: UILabel!
    @IBOutlet weak var shortCustomLabel: UILabel!

    override func initNib() {
        let bundle = Bundle(for: PswapButton.self)
        bundle.loadNibNamed("PswapButton", owner: self, options: nil)
        addSubview(containerView)
        containerView.frame = bounds
        containerView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        layoutNeumorphismShadows()
        setupButton()
    }
}
