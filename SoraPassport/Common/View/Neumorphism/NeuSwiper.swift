import UIKit

protocol NeuSwiperDelegate: AnyObject {
    func didSwipe(swiper: NeuSwiper)
}

@IBDesignable class NeuSwiper: UIControl {
    @IBOutlet var containerView: UIView!
    @IBOutlet var shadowView: UIView!
    @IBOutlet weak var slider: UISlider!
    @IBOutlet weak var label: UILabel!

    weak var delegate: NeuSwiperDelegate?

    let shadowLayerName = "shadow"
    let shadowAnimationDuration = 0.2

    var shadowSublayers: [CALayer] {
        return shadowView.layer.sublayers?.filter({
            $0.name == shadowLayerName
        }) ?? []
    }

    @IBInspectable var forceUppercase: Bool = true {
        didSet {
            label.text = forceUppercase ? text.uppercased() : text
        }
    }

    @IBInspectable var text: String = "" {
        didSet {
            label.text = forceUppercase ? text.uppercased() : text
        }
    }
    
    @IBInspectable var textColor: UIColor = R.color.neumorphism.swiperTextGrey()! {
        didSet {
            label.textColor = textColor
        }
    }

    @IBInspectable var font: UIFont = UIFont.styled(for: .button) {
        didSet {
            label.font = font
        }
    }

    @IBInspectable var color: UIColor = R.color.neumorphism.buttonLightGrey()! {
        didSet {
            layoutNeumorphismShadows()
        }
    }

    @IBInspectable var thumbOuterColor: UIColor = R.color.neumorphism.swiperThumbLightGrey()! {
        didSet {
            layoutSlider()
        }
    }

    @IBInspectable var thumbInnerColor: UIColor = R.color.neumorphism.buttonDarkGrey()! {
        didSet {
            layoutSlider()
        }
    }

    @IBInspectable var colorDisabled: UIColor = R.color.neumorphism.base()! {
        didSet {
            layoutNeumorphismShadows()
        }
    }

    @IBInspectable var isFlat: Bool = true {
        didSet {
            layoutNeumorphismShadows()
        }
    }

    @IBInspectable var bottomShadowColor: UIColor = R.color.neumorphism.darkShadow()! {
        didSet {
            layoutNeumorphismShadows()
        }
    }

    @IBInspectable var topShadowColor: UIColor = R.color.neumorphism.lightShadow()! {
        didSet {
            layoutNeumorphismShadows()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        initNib()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        initNib()
    }

    func initNib() {
        let bundle = Bundle(for: NeuSwiper.self)
        bundle.loadNibNamed("NeuSwiper", owner: self, options: nil)
        addSubview(containerView)
        containerView.frame = bounds
        containerView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        layoutNeumorphismShadows()
        setupLabel()
        setupSlider()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        //need to be called when bounds changes
        layoutNeumorphismShadows()
        setupSlider()
    }
    
    fileprivate func layoutNeumorphismShadows() {
        shadowView.layer.masksToBounds = false
        shadowView.backgroundColor = .clear

        removeNeumorphismShadows()

        let cornerRadius: CGFloat = bounds.size.height/2
        let shadowRadius: CGFloat = 4

        let mainColor = CALayer()
        mainColor.name = shadowLayerName
        mainColor.frame = bounds
        mainColor.backgroundColor = isEnabled ? color.cgColor : colorDisabled.cgColor
        mainColor.cornerRadius = cornerRadius
        shadowView.layer.insertSublayer(mainColor, at: 0)

        guard !isFlat else { return }

        let lightShadow = CALayer()
        lightShadow.name = shadowLayerName
        lightShadow.masksToBounds = false
        lightShadow.frame = bounds
        lightShadow.backgroundColor = topShadowColor.cgColor
        lightShadow.shadowColor = topShadowColor.cgColor
        lightShadow.cornerRadius = cornerRadius
        lightShadow.shadowOffset = CGSize(width: -shadowRadius, height: -shadowRadius)
        lightShadow.shadowOpacity = 1
        lightShadow.shadowRadius = shadowRadius
        shadowView.layer.insertSublayer(lightShadow, at: 0)

        let darkShadow = CALayer()
        darkShadow.name = shadowLayerName
        darkShadow.frame = bounds
        darkShadow.masksToBounds = false
        darkShadow.backgroundColor = bottomShadowColor.cgColor
        darkShadow.shadowColor = bottomShadowColor.cgColor
        darkShadow.cornerRadius = cornerRadius
        darkShadow.shadowOffset = CGSize(width: shadowRadius, height: shadowRadius)
        darkShadow.shadowOpacity = 1
        darkShadow.shadowRadius = shadowRadius
        shadowView.layer.insertSublayer(darkShadow, at: 0)
    }

    fileprivate func removeNeumorphismShadows() {
        shadowSublayers.forEach({
            $0.removeFromSuperlayer()
        })
    }

    @objc fileprivate func showNeumorphismShadows() {
        changeNeumorphismShadowsOpacity(to: 1, animated: true)
    }

    @objc fileprivate func hideNeumorphismShadows() {
        changeNeumorphismShadowsOpacity(to: 0, animated: true)

    }

    fileprivate func changeNeumorphismShadowsOpacity(to newOpacity: Float, animated: Bool) {
        let opacityAnimationKey = "opacity"
        layer.removeAnimation(forKey: opacityAnimationKey)
        shadowSublayers.forEach({ sublayer in
            let currentOpacity = sublayer.opacity
            sublayer.opacity = newOpacity
            if animated {
                let animation = CABasicAnimation(keyPath: opacityAnimationKey)
                animation.fromValue = currentOpacity
                animation.toValue = newOpacity
                animation.duration = shadowAnimationDuration
                sublayer.add(animation, forKey: opacityAnimationKey)
            }
        })
    }

    fileprivate func setupLabel() {
        label.textColor = textColor
        label.font = font
    }

    fileprivate func layoutSlider() {
        slider.setMinimumTrackImage(UIImage(), for: .normal)
        slider.setMaximumTrackImage(UIImage(), for: .normal)
        slider.setThumbImage(createSliderThumbImage(), for: .normal)
    }

    fileprivate func setupSlider() {
        layoutSlider()
        slider.isContinuous = false
        slider.addTarget(self, action: #selector(sliderValueChanged), for: .valueChanged)
    }

    func reset() {
        slider.setValue(slider.minimumValue, animated: false)
    }

    fileprivate func createSliderThumbImage() -> UIImage? {
        let size = CGSize(width: bounds.size.height, height: bounds.size.height)

        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }

        // draw outer circle
        let rect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        ctx.setFillColor(thumbOuterColor.cgColor)
        ctx.fillEllipse(in: rect)

        // draw inner circle
        let innerRect = CGRect(x: 6, y: 6, width: size.width - 12, height: size.height - 12)
        ctx.setFillColor(thumbInnerColor.cgColor)
        ctx.fillEllipse(in: innerRect)

        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img
    }

    @objc fileprivate func sliderValueChanged() {
        if slider.value >= (slider.maximumValue - slider.minimumValue) / 2 {
            slider.setValue(slider.maximumValue, animated: true)
            delegate?.didSwipe(swiper: self)
        } else {
            slider.setValue(slider.minimumValue, animated: true)
        }
    }
}
