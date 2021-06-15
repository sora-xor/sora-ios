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
        self.ethIcon.image = R.image.assetValErc()
        self.soraIcon.image = R.image.assetVal()
        self.ethTitleLabel.text = "Ethereum"
        self.soraTitleLabel.text = "SORA NET"
    }
}
