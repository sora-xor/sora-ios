import UIKit
import SoraUIKit

final class ActivityIndicatorViewController: SoramitsuViewController {
    lazy var blurredView: UIView = {
        let containerView = UIView()
        let blurEffect = UIBlurEffect(style: .light)
        let customBlurEffectView = CustomVisualEffectView(effect: blurEffect, intensity: 0.5)
        customBlurEffectView.frame = self.view.bounds

        containerView.addSubview(customBlurEffectView)
        return containerView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        view.addSubview(blurredView)
        view.sendSubviewToBack(blurredView)
        
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor.systemGray5
        backgroundView.layer.cornerRadius = 10
        backgroundView.layer.masksToBounds = true
        view.addSubview(backgroundView)
        backgroundView.snp.makeConstraints {
            $0.center.equalToSuperview()
            $0.size.equalTo(CGSize(width: 64, height: 64))
        }
        
        let activityIndicatorView = UIActivityIndicatorView()
        activityIndicatorView.style = .large
        backgroundView.addSubview(activityIndicatorView)
        activityIndicatorView.snp.makeConstraints {
            $0.center.equalToSuperview()
        }
        
        activityIndicatorView.startAnimating()
    }
}
