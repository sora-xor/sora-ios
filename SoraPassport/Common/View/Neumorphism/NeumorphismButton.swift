import UIKit

@IBDesignable class NeumorphismButton: UIControl {
    @IBOutlet var containerView: UIView!
    @IBOutlet var shadowView: UIView!
    @IBOutlet weak var button: UIButton!

    let shadowLayerName = "shadow"
    let shadowAnimationDuration = 0.2

    var shadowSublayers: [CALayer] {
        return shadowView.layer.sublayers?.filter({
            $0.name == shadowLayerName
        }) ?? []
    }

    @IBInspectable var forceUppercase: Bool = true {
        didSet {
            let newTitle = forceUppercase ? buttonTitle.uppercased() : buttonTitle
            button?.setTitle(newTitle, for: .normal)
        }
    }

    @IBInspectable var buttonTitle: String = "" {
        didSet {
            let newTitle = forceUppercase ? buttonTitle.uppercased() : buttonTitle
            button?.setTitle(newTitle, for: .normal)
        }
    }

    @IBInspectable var image: UIImage? {
        didSet {
            button?.setImage(image, for: .normal)
        }
    }

    var font: UIFont? {
        get { button.titleLabel?.font }
        set { button.titleLabel?.font = newValue }
    }

    @IBInspectable var color: UIColor = R.color.neumorphism.base()! {
        didSet {
            layoutNeumorphismShadows()
        }
    }

    @IBInspectable var colorDisabled: UIColor = R.color.neumorphism.buttonLightGrey()! {
        didSet {
            layoutNeumorphismShadows()
        }
    }

    @IBInspectable var isFlat: Bool = false {
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
        let bundle = Bundle(for: NeumorphismButton.self)
        bundle.loadNibNamed("NeomorphismButton", owner: self, options: nil)
        addSubview(containerView)
        containerView.frame = bounds
        containerView.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        layoutNeumorphismShadows()
        setupButton()
    }

    override var isEnabled: Bool {
        didSet {
            button.isEnabled = isEnabled
            layoutNeumorphismShadows()
        }
    }

    func setupButton() {
        button.titleLabel?.font = UIFont.styled(for: .button)
        button.setTitleColor(R.color.neumorphism.buttonTextDisabled()!, for: .disabled)
        button.adjustsImageWhenHighlighted = false
        button.addTarget(self, action: #selector(hideNeumorphismShadows), for: .touchDown)
        button.addTarget(self, action: #selector(showNeumorphismShadows), for: [.touchUpInside, .touchUpOutside])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutNeumorphismShadows()
    }

    func layoutNeumorphismShadows() {
        shadowView.layer.masksToBounds = false
        shadowView.backgroundColor = .clear

        removeNeumorphismShadows()

        let cornerRadius: CGFloat = bounds.size.height/2
        let shadowRadius: CGFloat = 4

        let mainColor = CALayer()
        mainColor.name = shadowLayerName
        mainColor.frame = bounds
        mainColor.backgroundColor = button.isEnabled ? color.cgColor : colorDisabled.cgColor
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

    func removeNeumorphismShadows() {
        shadowSublayers.forEach({
            $0.removeFromSuperlayer()
        })
    }

    @objc func showNeumorphismShadows() {
        changeNeumorphismShadowsOpacity(to: 1, animated: true)
    }

    @objc func hideNeumorphismShadows() {
        changeNeumorphismShadowsOpacity(to: 0, animated: true)

    }

    func changeNeumorphismShadowsOpacity(to newOpacity: Float, animated: Bool) {
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

    override func addTarget(_ target: Any?, action: Selector, for controlEvents: UIControl.Event) {
        button.addTarget(target, action: action, for: controlEvents)
    }

    override func removeTarget(_ target: Any?, action: Selector?, for controlEvents: UIControl.Event) {
        button.removeTarget(target, action: action, for: controlEvents)
    }

    @IBAction func buttonPressed(_ sender: Any) {
        sendActions(for: .touchUpInside)
    }

    func setImage(_ image: UIImage?, for state: UIControl.State) {
        button.setImage(image, for: state)
    }

    func setTitle(_ title: String?, for state: UIControl.State) {
        let newTitle = forceUppercase ? title?.uppercased() : title
        button?.setTitle(newTitle, for: .normal)
    }

    func setAttributedTitle(_ attributedTitle: NSAttributedString?, for state: UIControl.State) {
        button.setAttributedTitle(attributedTitle, for: state)
    }

    func setTitleColor(_ color: UIColor?, for state: UIControl.State) {
        button.setTitleColor(color, for: state)
    }

    func image(for state: UIControl.State) -> UIImage? {
        button.image(for: state)
    }

    private lazy var progressCover: ButtonProgressCover = {
        let view = ButtonProgressCover()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.cornerRadius = bounds.size.height/2
        view.shadowOpacity = 0
        view.shadowColor = .clear
        view.fillColor = R.color.baseDisabled()!
        view.progressIcon.loopMode = .loop
        return view
    }()
}


extension NeumorphismButton {
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

    private func startAnimating() {
        progressCover.progressIcon.play()
    }

    private func stopAnimating() {
        progressCover.progressIcon.stop()
    }
}
