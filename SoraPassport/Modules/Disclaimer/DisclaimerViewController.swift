import UIKit
import SoraFoundation
import Nantes
import SwiftUI
import SoraKeystore

class DisclaimerViewController: UIViewController & DisclaimerViewProtocol {
    
    enum HiddenState {
        case hidden
        case shown
    }

    var state: HiddenState = .shown {
        didSet {
            switch state {
            case .shown:
                label7.text = R.string.localizable.polkaswapInfoText7(preferredLanguages: locale.rLanguages)
                swiper.text = R.string.localizable.commonHide(preferredLanguages: locale.rLanguages)
            case .hidden:
                label7.text = R.string.localizable.polkaswapInfoText9(preferredLanguages: locale.rLanguages)
                swiper.text = R.string.localizable.commonShow(preferredLanguages: locale.rLanguages)
            }
            SettingsManager.shared.disclaimerHidden = ( state == .hidden )
        }
    }

    @IBOutlet weak var label1: NantesLabel!
    @IBOutlet weak var label2: UILabel!
    @IBOutlet weak var label3: UILabel!
    @IBOutlet weak var label4: UILabel!
    @IBOutlet weak var label5: UILabel!
    @IBOutlet weak var label6: NantesLabel!
    @IBOutlet weak var label7: UILabel!
    @IBOutlet weak var labelIndex1: UILabel!
    @IBOutlet weak var labelIndex2: UILabel!
    @IBOutlet weak var labelIndex3: UILabel!

    @IBOutlet weak var swiper: NeuSwiper!

    let locale = LocalizationManager.shared.selectedLocale
    let linkDecorator = LinkDecoratorFactory.disclaimerDecorator()

    override func viewDidLoad() {
        super.viewDidLoad()

        title = R.string.localizable.polkaswapInfoTitle(preferredLanguages: locale.rLanguages)
        setupLabels()
        setupSwiper()
        let disclaimerStateHidden = SettingsManager.shared.disclaimerHidden ?? false
        state = disclaimerStateHidden ? .hidden : .shown
    }

    func setupLabels() {
        label1.text = R.string.localizable.polkaswapInfoText1(preferredLanguages: locale.rLanguages)
        label2.text = R.string.localizable.polkaswapInfoText2(preferredLanguages: locale.rLanguages)
        label3.text = R.string.localizable.polkaswapInfoText3(preferredLanguages: locale.rLanguages)
        label4.text = R.string.localizable.polkaswapInfoText4(preferredLanguages: locale.rLanguages)
        label5.text = R.string.localizable.polkaswapInfoText5(preferredLanguages: locale.rLanguages)
        label6.text = R.string.localizable.polkaswapInfoText6(preferredLanguages: locale.rLanguages)
        label7.text = R.string.localizable.polkaswapInfoText7(preferredLanguages: locale.rLanguages)

        [label1, label3, label4, label5, label6, labelIndex1, labelIndex2, labelIndex3].forEach { label in
            label?.font = UIFont.styled(for: .paragraph1)
        }
        label2.font = UIFont.styled(for: .paragraph1, isBold: true)
        label7.font = UIFont.styled(for: .paragraph2)

        decorate(label: label1)
        decorate(label: label6)
    }

    func decorate(label: NantesLabel) {
        label.delegate = self
        label.linkAttributes = [
            NSAttributedString.Key.foregroundColor: R.color.brandPolkaswapPink()!
        ]
        var text = label.text ?? ""
        let links: [(URL, NSRange)] = linkDecorator.links(inText: &text)
        label.text = text
        for link in links {
            label.addLink(to: link.0, withRange: link.1)
        }
    }

    fileprivate func setupSwiper() {
        swiper.delegate = self
    }
}

extension DisclaimerViewController: NantesLabelDelegate {
    func attributedLabel(_ label: NantesLabel, didSelectLink link: URL) {
        UIApplication.shared.open(link, options: [:], completionHandler: nil)
    }
}

extension DisclaimerViewController: NeuSwiperDelegate {
    func didSwipe(swiper: NeuSwiper) {
        swiper.reset()
        switch state {
        case .hidden:
            state = .shown
        case .shown:
            state = .hidden
        }
    }
}
