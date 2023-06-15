import Foundation
import UIKit
import Lottie
import SoraUIKit
import SnapKit

class SplashViewController: UIViewController, SplashViewProtocol {
    
    var presenter: SplashPresenter!
    
    private lazy var animationView: LottieAnimationView = {
        let animationView = LottieAnimationView(filePath: R.file.soraSplashJson.path()!)
        animationView.contentMode = .scaleAspectFit
        animationView.backgroundBehavior = .pauseAndRestore
        animationView.translatesAutoresizingMaskIntoConstraints = false
        return animationView
    }()
    
    private lazy var messageLabel: SoramitsuLabel = {
        let title = SoramitsuTextItem(text: R.string.localizable.launchScreenLoadingTitle(preferredLanguages: .currentLocale),
                                      fontData: FontType.headline3,
                                      textColor: .fgPrimary,
                                      alignment: .center)
        
        let label = SoramitsuLabel()
        label.sora.attributedText = title
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var spinnerView: UIActivityIndicatorView = {
        let spinnerView = UIActivityIndicatorView(style: .large)
        spinnerView.translatesAutoresizingMaskIntoConstraints = false
        return spinnerView
    }()
    
    private lazy var containerView: SoramitsuView = {
        let containerView = SoramitsuView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.sora.isHidden = true
        return containerView
    }()
    
    override func viewDidLoad() {
        view.backgroundColor = R.color.baseBackground()
        setupHierarchy()
        setupLayout()
        animationView.play(fromProgress: 0, toProgress: 0.8, loopMode: .playOnce) { [weak self] _ in
            self?.hideMessage()
        }
        presenter.showIsLoading(after: 0.5) { [weak self] in
            self?.showMessage()
        }
    }
    
    private func setupHierarchy() {
        view.addSubview(animationView)
        view.addSubview(containerView)
        
        containerView.addSubview(messageLabel)
        containerView.addSubview(spinnerView)
    }
    
    private func setupLayout() {
        let containerViewBottomOffset: CGFloat = 76
        let spinnerViewTopOffset: CGFloat = 24
        
        animationView.snp.makeConstraints { make in
            make.center.width.height.equalTo(view)
        }
        
        containerView.snp.makeConstraints { make in
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-containerViewBottomOffset)
            make.leading.equalTo(messageLabel)
            make.centerX.equalTo(view)
        }
        
        messageLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalTo(containerView)
        }
        
        spinnerView.snp.makeConstraints { make in
            make.top.equalTo(messageLabel.snp.bottom).offset(spinnerViewTopOffset)
            make.centerX.bottom.equalTo(containerView)
        }
    }
    
    private func showMessage() {
        containerView.sora.isHidden = false
        spinnerView.startAnimating()
    }
    
    private func hideMessage() {
        containerView.sora.isHidden = true
        spinnerView.stopAnimating()
    }
    
    func animate(duration animationDurationBase: Double, completion: @escaping () -> Void) {
        animationView.play(fromProgress: 0.8, toProgress: 1, loopMode: .playOnce) { (_) in
            completion()
        }
    }
}
