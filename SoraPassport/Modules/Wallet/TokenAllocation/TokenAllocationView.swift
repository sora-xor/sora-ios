import UIKit

class TokenAllocationView: UIView {

    @IBOutlet var headerIcon: UIImageView!
    @IBOutlet var ethIcon: UIImageView!
    @IBOutlet var soraIcon: UIImageView!
    @IBOutlet var ethTitleLabel: UILabel!
    @IBOutlet var ethValueLabel: UILabel!
    @IBOutlet var soraTitleLabel: UILabel!
    @IBOutlet var soraValueLabel: UILabel!
    @IBOutlet var headerLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()

        self.headerIcon.image = R.image.iconWalletInfo()
        self.ethIcon.image = R.image.iconXorErc()
        self.soraIcon.image = R.image.iconSoraXor()
        self.ethTitleLabel.text = "Erc20"
        self.soraTitleLabel.text = "SoraNet"
    }
}
