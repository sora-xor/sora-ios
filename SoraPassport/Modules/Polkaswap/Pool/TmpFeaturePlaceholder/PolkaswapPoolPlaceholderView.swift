import Foundation
import SoraFoundation
import UIKit

class PolkaswapPoolPlaceholderView: UIViewController, PolkaswapPoolViewProtocol {
    
    var delegate: PolkaswapPoolViewDelegate?
    
    @IBOutlet var comingSoonLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        view.translatesAutoresizingMaskIntoConstraints = false

        view.backgroundColor = R.color.neumorphism.base()
        comingSoonLabel.font = UIFont.styled(for: .title1, isBold: true)
        applyLocalization()
    }
    
    func setPoolList(_ pools: [PoolDetails]) {
    }
}

extension PolkaswapPoolPlaceholderView: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    func applyLocalization() {
        comingSoonLabel?.text = R.string.localizable.comingSoon(preferredLanguages: languages)
    }
}
