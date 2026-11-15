import UIKit

public class SoramitsuViewConfiguration<Type: Element & UIView>: SoramitsuConfiguration<Type> {

    public var material: SoramitsuSurfaceMaterial = .automatic {
        didSet { updatePlate() }
    }
    
    public var backgroundColor: SoramitsuColor = .custom(uiColor: .clear) {
        didSet {
            let supportedPalette = supportsPaletteMode ? style.palette : LightPalette()
            let color = supportedPalette.color(backgroundColor)
            owner?.backgroundColor = color
            updatePlate()
        }
    }

    /// A rounded, unclipped surface-coloured view is a card: it stands on a porcelain plate.
    private var plate: LitPlateLayer?

    func updatePlate() {
        guard let owner else { return }
        var isSurface = false
        if case .bgSurface = backgroundColor { isSurface = true }
        let radius = owner.layer.cornerRadius
        guard isSurface, material != .solid, !clipsToBounds, radius >= 12, !(owner is UIControl) else {
            plate?.removeFromSuperlayer()
            plate = nil
            return
        }
        let target = plate ?? LitPlateLayer()
        if plate == nil {
            plate = target
            owner.layer.insertSublayer(target, at: 0)
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        target.cornerRadiusValue = min(radius, min(owner.bounds.width, owner.bounds.height) / 2)
        target.elevation = owner.bounds.height < 80 ? 9 : 16
        target.frame = owner.bounds
        CATransaction.commit()
        owner.layer.shadowOpacity = 0
    }

    /// True while the stored background is re-applied (theme change, owner
    /// set), as opposed to a caller assigning a new one.
    private(set) var isReapplyingBackground = false

    func reapplyBackground() {
        isReapplyingBackground = true
        retrigger(self, \.backgroundColor)
        isReapplyingBackground = false
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
            updatePlate()
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
            updatePlate()
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
            reapplyBackground()
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
        
        reapplyBackground()
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
        updatePlate()
    }
    
    public override func styleDidChange(options: UpdateOptions) {
        super.styleDidChange(options: options)
        
        if options.contains(.palette) {
            reapplyBackground()
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

/// `.solid` keeps a surface-coloured view flat; otherwise a rounded, unclipped one stands on a plate.
public enum SoramitsuSurfaceMaterial {
    case automatic
    case solid
    case glass
}
