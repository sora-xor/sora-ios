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
    
    private var messageLabel: SoramitsuLabel = {
        let title = SoramitsuTextItem(text: R.string.localizable.launchScreenLoadingTitle(preferredLanguages: .currentLocale),
                                      fontData: FontType.headline3,
                                      textColor: .fgPrimary,
                                      alignment: .center)
        
        let label = SoramitsuLabel()
        label.sora.attributedText = title
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private var loaderView: UIActivityIndicatorView = {
        let loaderView = UIActivityIndicatorView(style: .large)
        loaderView.translatesAutoresizingMaskIntoConstraints = false
        return loaderView
    }()
    
    private var containerView: SoramitsuView = {
        let containerView = SoramitsuView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.sora.isHidden = true
        return containerView
    }()
    
    override func viewDidLoad() {
        view.backgroundColor = R.color.baseBackground()
        setupHierarchy()
        setupLayout()
        animationView.play(fromProgress: 0, toProgress: 0.8, loopMode: .playOnce) { [weak self] _ in }
    }
    
    private func setupHierarchy() {
        view.addSubview(animationView)
        view.addSubview(containerView)
        
        containerView.addSubview(messageLabel)
        containerView.addSubview(loaderView)
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
        
        loaderView.snp.makeConstraints { make in
            make.top.equalTo(messageLabel.snp.bottom).offset(spinnerViewTopOffset)
            make.centerX.bottom.equalTo(containerView)
        }
    }
    
    private func showLoader() {
        containerView.sora.isHidden = false
        loaderView.startAnimating()
    }
    
    private func hideLoader() {
        containerView.sora.isHidden = true
        loaderView.stopAnimating()
    }
    
    func animate(duration animationDurationBase: Double, completion: @escaping () -> Void) {
        hideLoader()
        animationView.play(fromProgress: 0.8, toProgress: 1, loopMode: .playOnce) { (_) in
            completion()
        }
    }
}
