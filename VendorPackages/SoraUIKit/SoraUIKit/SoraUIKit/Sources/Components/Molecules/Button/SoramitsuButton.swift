//
//  SoramitsuButton.swift
//  SoraUIKit
//
//  Created by Ivan Shlyapkin on 14.09.2022.
//

import Foundation
import UIKit

public final class SoramitsuButton: UIControl, Molecule {

    public let sora: SoramitsuButtonConfiguration<SoramitsuButton>

    // MARK: - UI

    var type: SoramitsuButtonType = .filled(.primary)

    /// How firmly a button with a side inset keeps to the width of its title and glyphs, and to the
    /// height of its size: the way a view keeps to its own size. It holds wherever nothing else sets the
    /// button's width or height, and gives way to the screen that does, so a button pinned to both sides
    /// of its column fills it. These were required once: the button then insisted on being exactly as wide
    /// as its title, and a column that ran from one side of that button to the other came out as wide as
    /// the word on it (the swap and send screens' Review), or Auto Layout had to break a constraint on
    /// every layout to get out of it.
    public static let fittedSizePriority = UILayoutPriority(990)
    /// Below the fitted width: with too little room the title gets smaller before it leaves its button.
    static let titleCompressionPriority = UILayoutPriority(980)

    var horizontalConstaint: NSLayoutConstraint?
    var leftImageSizeConstaint: NSLayoutConstraint?
    var rightImageSizeConstaint: NSLayoutConstraint?

    let leftImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.isHidden = true
        label.sora.alignment = .center
        label.sora.backgroundColor = .custom(uiColor: .clear)
        label.setContentCompressionResistancePriority(SoramitsuButton.titleCompressionPriority, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .horizontal)
        // A long title in a narrow button (Japanese on a small phone) gets smaller, down to seven tenths,
        // before it is cut.
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        return label
    }()

    public let rightImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 4
        stackView.isUserInteractionEnabled = false
        stackView.alignment = .center
        stackView.distribution = .fill
        return stackView
    }()

    let pressingView: SoramitsuView = {
        let view = SoramitsuView()
        view.alpha = 0
        return view
    }()

    private var shapePath: UIBezierPath {
        return UIBezierPath(rect: self.bounds)
    }

    private var size: SoramitsuButtonSize = .large

    init(style: SoramitsuStyle, size: SoramitsuButtonSize, type: SoramitsuButtonType = .filled(.primary)) {
        sora = SoramitsuButtonConfiguration(style: style)
        self.size = size
        self.type = type
        super.init(frame: .zero)
        sora.owner = self
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// The cut glass of a filled button, made when the button is one: pads, links and disabled buttons
    /// carry no glass and nothing of theirs follows the light.
    private var glass: LitCutGlass?
    private var plate: LitPlateLayer?

    override public func layoutSubviews() {
        super.layoutSubviews()
        applyMaterial()
    }

    public override var isHighlighted: Bool {
        didSet {
            guard isHighlighted != oldValue else { return }
            switch type {
            case .text: break
            case .filled:
                // Cut glass is set down on the surface: it moves a point and its light tightens under it.
                LitMotion.press(self, pressed: isHighlighted, scale: 1)
                setNeedsLayout()
            default: LitMotion.press(self, pressed: isHighlighted)
            }
        }
    }

    /// Filled buttons are cut glass of their own colour; surface-coloured ones are soft raised pads.
    private func applyMaterial() {
        let palette = sora.supportsPaletteMode ? sora.style.palette : LightPalette()
        var isFilled = false
        if case .filled = type { isFilled = true }
        var isPlate = false
        if case .bleached = type { isPlate = true }
        if case .bgSurface? = sora.explicitBackgroundColor { isPlate = true }
        var glassColor = palette.color(sora.explicitBackgroundColor ?? type.enabledBackgroundColor)
        if isFilled, !isPlate {
            let onLightPage = Self.luminance(of: palette.color(.bgPage)) > 0.5
            switch Self.material(of: glassColor) {
            // A clear filled button is a bare label with a glyph (a token chooser, a link): glass over
            // nothing renders as smoked glass, so it gets no material at all.
            case .bare: isFilled = false
            // A white or page-coloured one is a pad, not white glass.
            case .pad where onLightPage: isFilled = false; isPlate = true
            // Ink-dark glass on a white page is a black control; the screen's action is red glass.
            case .ink where onLightPage: glassColor = palette.color(.accentPrimary)
            default: break
            }
        }
        let requested = sora.style.radii.radius(sora.cornerRadius, size: bounds.size)
        // Cut glass is a slab with small corners, whatever was asked for; a pad keeps the shape it was given
        // (a PIN key is round).
        let radius = isFilled && !isPlate ? Lit.controlRadius : requested
        if isFilled, !isPlate {
            layer.cornerRadius = min(radius, bounds.height / 2)
            pressingView.layer.cornerRadius = layer.cornerRadius
        }
        if isFilled, !isPlate, isEnabled {
            let face = glass ?? LitCutGlass()
            glass = face
            if face.layer.superlayer == nil { layer.insertSublayer(face.layer, at: 0) }
            face.layout(in: self, radius: radius, color: glassColor, pressed: isHighlighted)
            // The glass is the face; the flat fill under it would show round its cut edge.
            backgroundColor = .clear
            layer.masksToBounds = false
        } else {
            glass?.layer.removeFromSuperlayer()
            glass = nil
            if !isPlate { layer.shadowOpacity = 0 }
        }
        if isPlate, isEnabled, bounds.height > 0 {
            let target = plate ?? LitPlateLayer()
            if plate == nil {
                plate = target
                layer.insertSublayer(target, at: 0)
            }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            target.cornerRadiusValue = min(radius, bounds.height / 2)
            target.elevation = 8
            target.frame = bounds
            CATransaction.commit()
            layer.masksToBounds = false
            layer.shadowOpacity = 0
        } else {
            plate?.removeFromSuperlayer()
            plate = nil
        }
    }

    enum Material: Equatable { case bare, pad, ink, glass }

    /// What a filled button of this colour is made of.
    static func material(of color: UIColor) -> Material {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard color.getRed(&r, green: &g, blue: &b, alpha: &a) else { return .glass }
        if a < 0.2 { return .bare }
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        let chroma = max(r, g, b) - min(r, g, b)
        if chroma < 0.12, luminance > 0.82 { return .pad }
        if chroma < 0.12, luminance < 0.3 { return .ink }
        return .glass
    }

    static func luminance(of color: UIColor) -> CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard color.getRed(&r, green: &g, blue: &b, alpha: &a) else { return 1 }
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    public override var isEnabled: Bool {
        didSet {
            updateView()
        }
    }

    func pressedAnimation() {
        UIView.animate(withDuration: 0.3,
                      delay: .zero,
                      options: [.allowUserInteraction, .curveEaseInOut],
                      animations: {
            self.pressingView.sora.alpha = 1
        }) { completed in
            UIView.animate(withDuration: 0.3,
                          delay: .zero,
                          options: [.allowUserInteraction, .curveEaseInOut],
                          animations: {
                self.pressingView.sora.alpha = 0
            })
        }
    }

    func updateView() {
        if case .outlined = type {
            layer.borderWidth = 1
        }

        let palette = sora.supportsPaletteMode ? sora.style.palette : LightPalette()

        let borderColor = palette.color((isEnabled ? type.tintColor : type.disabledBorderColor) ?? .fgPrimary).cgColor
        layer.borderColor = borderColor

        let soraBackgroundColor = isEnabled ? (sora.explicitBackgroundColor ?? type.enabledBackgroundColor)
            : type.disabledBackgroundColor
        let backgroundColor = isEnabled ? palette.color(soraBackgroundColor) : palette.color(soraBackgroundColor).withAlphaComponent(0.04)
        sora.applyTypeBackground(.custom(uiColor: backgroundColor))

        let soraColor = isEnabled ? type.tintColor : type.disabledTintColor
        let textColor = isEnabled ? palette.color(soraColor) : palette.color(soraColor).withAlphaComponent(0.12)
        let mainColor = isEnabled ? palette.color(soraColor) : palette.color(soraColor).withAlphaComponent(0.12)

        leftImageView.tintColor = mainColor
        titleLabel.sora.textColor = .custom(uiColor: textColor)
        rightImageView.tintColor = mainColor

        titleLabel.sora.font = size.font

        pressingView.sora.backgroundColor = .custom(uiColor: palette.color(type.pressedSublayerColor).withAlphaComponent(0.12))
        setNeedsLayout()
    }
}

private extension SoramitsuButton {
    func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = min(Lit.controlRadius, size.height / 2)
        pressingView.layer.cornerRadius = layer.cornerRadius
        
        addSubview(pressingView)
        addSubview(stackView)

        stackView.addArrangedSubview(leftImageView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(rightImageView)
        
        let side = stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16)
        side.priority = Self.fittedSizePriority
        horizontalConstaint = side

        leftImageSizeConstaint = leftImageView.heightAnchor.constraint(equalToConstant: 24)
        leftImageSizeConstaint?.isActive = true
        
        rightImageSizeConstaint = rightImageView.heightAnchor.constraint(equalToConstant: 24)
        rightImageSizeConstaint?.isActive = true

        NSLayoutConstraint.activate([
            pressingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            pressingView.topAnchor.constraint(equalTo: topAnchor),
            pressingView.centerXAnchor.constraint(equalTo: centerXAnchor),
            pressingView.centerYAnchor.constraint(equalTo: centerYAnchor),

            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            rightImageView.widthAnchor.constraint(equalTo: rightImageView.heightAnchor),
            leftImageView.widthAnchor.constraint(equalTo: leftImageView.heightAnchor)
        ])
        // The size's own height, unless the screen gives the button another one (a PIN key, a token chooser).
        let height = heightAnchor.constraint(equalToConstant: size.height)
        height.priority = Self.fittedSizePriority
        height.isActive = true
    }
}

public extension SoramitsuButton {
    convenience init(size: SoramitsuButtonSize = .large, type: SoramitsuButtonType = .filled(.primary)) {
        let sora = SoramitsuUI.shared
        self.init(style: sora.style, size: size, type: type)
    }
}
