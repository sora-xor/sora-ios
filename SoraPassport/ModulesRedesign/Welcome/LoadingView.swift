import Foundation
import SoraUIKit

final class SoramitsuLoadingView: SoramitsuView {
    
    let blurredView: UIView = UIView()
    
    let customBlurEffectView: CustomVisualEffectView = {
        let blurEffect = UIBlurEffect(style: .light)
        return CustomVisualEffectView(effect: blurEffect, intensity: 0.5)
    }()
    
    let backgroundView: UIView = {
        let backgroundView = UIView()
        backgroundView.backgroundColor = UIColor.systemGray5
        backgroundView.layer.cornerRadius = 10
        backgroundView.layer.masksToBounds = true
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        return backgroundView
    }()
    
    let activityIndicatorView: UIActivityIndicatorView = {
        let activityIndicatorView = UIActivityIndicatorView()
        activityIndicatorView.style = .large
        activityIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        activityIndicatorView.startAnimating()
        return activityIndicatorView
    }()
    
    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        setupSubviews()
        setupConstrains()
    }

    private func setupSubviews() {
        sora.backgroundColor = .custom(uiColor: .clear)
        isUserInteractionEnabled = false
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(blurredView)
        blurredView.addSubview(customBlurEffectView)
        
        addSubview(backgroundView)
        backgroundView.addSubview(activityIndicatorView)
    }

    private func setupConstrains() {
        NSLayoutConstraint.activate([
            blurredView.widthAnchor.constraint(equalTo: widthAnchor),
            blurredView.heightAnchor.constraint(equalTo: heightAnchor),
            
            backgroundView.centerYAnchor.constraint(equalTo: centerYAnchor),
            backgroundView.centerXAnchor.constraint(equalTo: centerXAnchor),
            backgroundView.widthAnchor.constraint(equalToConstant: 64),
            backgroundView.heightAnchor.constraint(equalToConstant: 64),

            
            activityIndicatorView.centerYAnchor.constraint(equalTo: backgroundView.centerYAnchor),
            activityIndicatorView.centerXAnchor.constraint(equalTo: backgroundView.centerXAnchor),
        ])
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        customBlurEffectView.frame = bounds
    }
}
