import UIKit

public class SoramitsuViewConfiguration<Type: Element & UIView>: SoramitsuConfiguration<Type> {
    
    public var backgroundColor: SoramitsuColor = .custom(uiColor: .clear) {
        didSet {
            let supportedPalette = supportsPaletteMode ? style.palette : LightPalette()
            let color = supportedPalette.color(backgroundColor)
            owner?.backgroundColor = color
        }
    }
    
    public var tintColor: SoramitsuColor = .accentPrimary {
        didSet {
            let supportedPalette = supportsPaletteMode ? style.palette : LightPalette()
            owner?.tintColor = supportedPalette.color(tintColor)
        }
    }
    
    public var cornerRadius: Radius = .zero {
        didSet {
            let radius = style.radii.radius(cornerRadius, size: owner?.frame.size ?? .zero)
            owner?.layer.cornerRadius = radius
            overlay.viewCornerRadiusDidChange()
        }
    }
    
    public var cornerMask: CornerMask = .all {
        didSet {
            owner?.layer.maskedCorners = cornerMask.maskValue
        }
    }
    
    public var borderWidth: CGFloat = 0 {
        didSet {
            owner?.layer.borderWidth = borderWidth
        }
    }
    
    public var borderColor: SoramitsuColor? {
        didSet {
            guard let color = borderColor else {
                owner?.layer.borderColor = nil
                return
            }
            let supportedPalette = supportsPaletteMode ? style.palette : LightPalette()
            owner?.layer.borderColor = supportedPalette.color(color).cgColor
        }
    }
    
    public var clipsToBounds: Bool = true {
        didSet {
            owner?.clipsToBounds = clipsToBounds
        }
    }
    
    public var useAutoresizingMask: Bool = false {
        didSet {
            owner?.translatesAutoresizingMaskIntoConstraints = useAutoresizingMask
        }
    }
    
    public private(set) lazy var loadingPlaceholder = SoramitsuLoadingPlaceholderDecorator(style: style)
    
    public var alpha: CGFloat = 1 {
        didSet {
            owner?.alpha = alpha
        }
    }
    
    public var isHidden: Bool = false {
        didSet {
            owner?.isHidden = isHidden
        }
    }
    
    public var shadow: Shadow = .none {
        didSet {
            guard let owner = owner else { return }
            let shadowData = style.shady.shadow(shadow)
            owner.layer.shadowColor = shadowData.color
            owner.layer.shadowOffset = shadowData.offset
            owner.layer.shadowRadius = shadowData.radius
            owner.layer.shadowOpacity = shadowData.opacity
            clipsToBounds = shadow == .none
        }
    }
    
    public var transform: CGAffineTransform = .identity {
        didSet {
            owner?.transform = transform
        }
    }
    
    public var isExclusiveTouch: Bool = false {
        didSet {
            owner?.isExclusiveTouch = isExclusiveTouch
        }
    }
    
    public var isUserInteractionEnabled: Bool = true {
        didSet {
            owner?.isUserInteractionEnabled = isUserInteractionEnabled
        }
    }
    
    public var supportsPaletteMode: Bool = true {
        didSet {
            retrigger(self, \.backgroundColor)
            retrigger(self, \.tintColor)
            retrigger(self, \.borderColor)
        }
    }
    
    private(set) lazy var overlay = SoramitsuOverlayDecorator(style: style)
    
    private lazy var blurDecorator = SoramitsuBlurDecorator()
    
    private lazy var observer: ViewObserver = {
        let observer = ViewObserver()
        observer.viewSizeDidChangeHandler = { [weak self] in
            self?.ownerSizeDidChange()
        }
        return observer
    }()
    
    override func configureOwner() {
        guard let owner = owner else { return }
        super.configureOwner()
        
        loadingPlaceholder.view = owner
        overlay.view = owner
        blurDecorator.view = owner
        
        retrigger(self, \.backgroundColor)
        retrigger(self, \.tintColor)
        retrigger(self, \.cornerRadius)
        retrigger(self, \.borderWidth)
        retrigger(self, \.borderColor)
        retrigger(self, \.clipsToBounds)
        retrigger(self, \.useAutoresizingMask)
        retrigger(self, \.isExclusiveTouch)
        
        observer.observe(owner)
    }
    
    private func ownerSizeDidChange() {
        retrigger(self, \.cornerRadius)
    }
    
    public override func styleDidChange(options: UpdateOptions) {
        super.styleDidChange(options: options)
        
        if options.contains(.palette) {
            retrigger(self, \.backgroundColor)
            retrigger(self, \.tintColor)
            retrigger(self, \.borderColor)
            retrigger(self, \.shadow)
        }
    }
    
    /// Анимированное изменений лэйаута
    func animateLayoutChanges() {
        UIView.animate(withDuration: CATransaction.animationDuration(),
                       delay: .zero,
                       options: [.allowUserInteraction],
                       animations: {
            self.owner?.layoutIfNeeded()
        })
    }
}
