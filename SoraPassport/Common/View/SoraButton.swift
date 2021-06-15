import Foundation
import SoraUI

class SoraButton: RoundedButton {

    @objc dynamic public var titleFont: UIFont? {
        get { return imageWithTitleView?.titleFont }
        set(newValue) {
            imageWithTitleView?.titleFont = newValue
            invalidateLayout()
        }
    }

    @objc dynamic public var cornerRadius: NSNumber? {
        get { return (roundedBackgroundView?.cornerRadius ?? 0) as NSNumber }
        set(newValue) {
            roundedBackgroundView?.cornerRadius = CGFloat(truncating: newValue ?? 0)
            invalidateLayout()
        }
    }

    @objc dynamic public var shadowOpacity: NSNumber? {
        get { return (roundedBackgroundView?.shadowOpacity ?? 0) as NSNumber }
        set(newValue) {
            roundedBackgroundView?.shadowOpacity = Float(truncating: newValue ?? 0)
            invalidateLayout()
        }

    }

    public var fillColor: UIColor {
        get { return roundedBackgroundView!.fillColor }
        set(newValue) {
            roundedBackgroundView?.fillColor = newValue
            invalidateLayout()
        }
    }

    public var title: String? {
        get { return imageWithTitleView?.title }
        set(newValue) {
            imageWithTitleView?.title = newValue
            invalidateLayout()
        }
    }

    public func startProgress() {
        self.addSubview(progressCover)
        progressCover.widthAnchor.constraint(equalTo: self.widthAnchor).isActive = true
        progressCover.heightAnchor.constraint(equalTo: self.heightAnchor).isActive = true
        progressCover.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        progressCover.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        self.isUserInteractionEnabled = false
        startAnimating()
    }

    public func stopProgress() {
        stopAnimating()
        progressCover.removeFromSuperview()
        self.isUserInteractionEnabled = true
    }

    private lazy var progressCover: ButtonProgressCover = {
        let view = ButtonProgressCover()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.cornerRadius = self.roundedBackgroundView!.cornerRadius
        view.shadowOpacity = 0
        view.shadowColor = .clear
        view.fillColor = R.color.baseDisabled()!
        view.progressIcon.image = R.image.iconProgressLoading()!
        return view
    }()
}

extension SoraButton {
    private struct Constants {
        static let animationPath = "transform.rotation.z"
        static let animationKey = "loading.animation.key"
        static let animationDuration: TimeInterval = 1.0
    }

    public func startAnimating() {

        let animation = createAnimation()
        progressCover.progressIcon.layer.add(animation, forKey: Constants.animationKey)

    }

    public func stopAnimating() {
        progressCover.progressIcon.layer.removeAnimation(forKey: Constants.animationKey)
    }

    public func createAnimation() -> CAAnimation {
        let animation = CAKeyframeAnimation(keyPath: Constants.animationPath)
        animation.values = [0.0, CGFloat.pi, 2.0 * CGFloat.pi]
        animation.calculationMode = .linear
        animation.keyTimes = [0.0, 0.5, 1.0]
        animation.repeatDuration = TimeInterval.infinity
        animation.duration = Constants.animationDuration
        animation.isCumulative = false
        return animation
    }

}

class ButtonProgressCover: RoundedView {
    var progressIcon: UIImageView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configure()
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        configure()
    }

    internal override func configure() {
        super.configure()
        self.addSubview(progressIcon)
        progressIcon.translatesAutoresizingMaskIntoConstraints = false
        progressIcon.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
        progressIcon.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        progressIcon.heightAnchor.constraint(lessThanOrEqualTo: self.heightAnchor, constant: -16).isActive = true
        progressIcon.widthAnchor.constraint(equalTo: progressIcon.heightAnchor, multiplier: 1).isActive = true
    }
}

final class GrayCopyButton: SoraButton {
    override func configure() {
        super.configure()

        self.imageWithTitleView?.layoutType = .horizontalLabelFirst
        self.imageWithTitleView?.iconImage = R.image.copy()!
        self.imageWithTitleView?.titleColor = R.color.baseContentPrimary()
        self.imageWithTitleView?.spacingBetweenLabelAndIcon = 7
    }

    override public var title: String? {
        get { return self.imageWithTitleView?.title }
        set { self.imageWithTitleView?.title = (newValue ?? "" ).soraConcat
            invalidateLayout()
        }
    }
}
