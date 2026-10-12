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
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .horizontal)
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

    /// Neon CTA fill (spec §8.4): only for primary and swap CTAs.
    private var gradientLayer: CAGradientLayer?
    /// Neon glow: a sublayer, so resetting the button's own shadow never removes it.
    private var glowLayer: CALayer?
    private(set) var neonVariant: NeonVariant?

    enum NeonVariant {
        case primary
        case swap
    }

    override public func layoutSubviews() {
        super.layoutSubviews()
        layoutNeonLayers()
    }

    public override var isEnabled: Bool {
        didSet {
            updateView()
        }
    }

    public override var isHighlighted: Bool {
        didSet {
            guard isHighlighted != oldValue else { return }
            let pressed = isHighlighted && isEnabled && neonVariant != nil
            if let variant = neonVariant {
                let tokens: NeonTokens = sora.supportsPaletteMode ? .current : .light
                let spec = variant == .swap ? tokens.glowSwap : tokens.glowPrimary
                glowLayer?.shadowOpacity = pressed ? spec.pressed : spec.rest
            }
            // Only the press scale this button applied itself is animated and
            // always released, even if the tap disabled the button. A
            // transform set by the caller is left alone.
            if pressed, !UIAccessibility.isReduceMotionEnabled {
                appliesPressScale = true
                UIView.animate(withDuration: NeonMotion.press, delay: 0,
                               options: [.allowUserInteraction, .beginFromCurrentState]) {
                    self.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
                }
            } else if appliesPressScale {
                appliesPressScale = false
                UIView.animate(withDuration: NeonMotion.fast, delay: 0,
                               options: [.allowUserInteraction, .beginFromCurrentState]) {
                    self.transform = .identity
                }
            }
        }
    }

    private var appliesPressScale = false

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
        let palette = sora.supportsPaletteMode ? sora.style.palette : LightPalette()
        let tokens: NeonTokens = sora.supportsPaletteMode ? .current : .light

        if case .outlined = type {
            layer.borderWidth = 1
        }

        if case .bleached = type {
            sora.shadow = .default
        }

        // A border the caller set wins over the type's border.
        if let custom = sora.borderColor {
            layer.borderColor = palette.color(custom).cgColor
        } else {
            let borderColor = isEnabled ? palette.color(type.tintColor)
                : (type.disabledBorderColor.map { _ in tokens.hairline } ?? palette.color(type.tintColor))
            layer.borderColor = borderColor.cgColor
        }

        let explicit = sora.explicitBackgroundColor
        neonVariant = isEnabled ? Self.neonVariant(for: type, explicitBackground: explicit) : nil

        let backgroundColor: UIColor
        let textColor: UIColor
        if !isEnabled {
            switch type {
            case .filled, .bleached, .tonal: backgroundColor = tokens.ctaDisabled
            case .outlined, .text: backgroundColor = .clear
            }
            textColor = tokens.textDisabled
        } else if neonVariant != nil {
            backgroundColor = .clear
            textColor = tokens.onAccent
        } else {
            // Keep a background the caller chose (it used to be reset to
            // the type's colour on every theme change or enable toggle).
            let fill = explicit ?? type.enabledBackgroundColor
            backgroundColor = palette.color(fill)
            if case .filled = type, Self.isSurface(fill, palette: palette) {
                // A filled button drawn on a surface or container colour:
                // the ink/white "on accent" label would vanish there.
                textColor = palette.color(sora.explicitTintColor ?? .fgPrimary)
            } else {
                textColor = palette.color(type.tintColor)
            }
        }
        self.backgroundColor = backgroundColor

        // Images keep a tint the caller chose (they used to take the label
        // colour after every theme change).
        let imageTint: UIColor
        if isEnabled, neonVariant == nil, let explicitTint = sora.explicitTintColor {
            imageTint = palette.color(explicitTint)
        } else {
            imageTint = textColor
        }
        leftImageView.tintColor = imageTint
        titleLabel.sora.textColor = .custom(uiColor: textColor)
        rightImageView.tintColor = imageTint

        titleLabel.sora.font = size.font

        let pressedColor: UIColor = neonVariant != nil
            ? UIColor.black.withAlphaComponent(tokens.isDark ? 0.08 : 0.10)
            : palette.color(type.pressedSublayerColor).withAlphaComponent(0.12)
        pressingView.sora.backgroundColor = .custom(uiColor: pressedColor)

        applyNeonLayers(tokens: tokens)
    }

    /// Page, surface, container or transparent fills (not an accent fill).
    static func isSurface(_ color: SoramitsuColor, palette: Palette) -> Bool {
        switch color {
        case .bgPage, .bgSurface, .bgSurfaceVariant,
             .accentPrimaryContainer, .accentSecondaryContainer, .accentTertiaryContainer,
             .statusSuccessContainer, .statusWarningContainer, .statusErrorContainer, .statusInfoContainer,
             .additionalPolkaswapContainer:
            return true
        case let .custom(uiColor):
            return uiColor.cgColor.alpha < 0.5
        default:
            return false
        }
    }

    static func neonVariant(for type: SoramitsuButtonType, explicitBackground: SoramitsuColor?) -> NeonVariant? {
        guard case let .filled(style) = type else { return nil }
        switch explicitBackground {
        case nil:
            return style == .primary ? .primary : nil
        case .accentPrimary?:
            return .primary
        case .additionalPolkaswap?:
            return .swap
        default:
            return nil
        }
    }

    private func applyNeonLayers(tokens: NeonTokens) {
        guard let variant = neonVariant else {
            gradientLayer?.removeFromSuperlayer()
            gradientLayer = nil
            glowLayer?.removeFromSuperlayer()
            glowLayer = nil
            return
        }
        let gradient = variant == .swap ? tokens.ctaSwap : tokens.ctaPrimary
        let glow = variant == .swap ? tokens.glowSwap : tokens.glowPrimary
        let fx = FxPolicy.current

        let fill = gradientLayer ?? CAGradientLayer()
        if gradientLayer == nil {
            layer.insertSublayer(fill, at: 0)
            gradientLayer = fill
        }
        fill.colors = gradient.cgColors
        fill.locations = gradient.nsLocations
        fill.startPoint = CGPoint(x: 0, y: 0.5)
        fill.endPoint = CGPoint(x: 1, y: 0.5)

        if fx.glows, fx.tier != .minimal {
            let halo = glowLayer ?? CALayer()
            if glowLayer == nil {
                layer.insertSublayer(halo, at: 0)
                glowLayer = halo
            }
            halo.shadowColor = glow.color.cgColor
            halo.shadowOpacity = isHighlighted ? glow.pressed : glow.rest
            halo.shadowRadius = glow.blur / 2
            halo.shadowOffset = CGSize(width: 0, height: glow.offsetY)
            applyClipping()
        } else {
            glowLayer?.removeFromSuperlayer()
            glowLayer = nil
        }
        layoutNeonLayers()
    }

    /// The glow is drawn outside the button, so it must not clip.
    func applyClipping() {
        if glowLayer != nil {
            clipsToBounds = false
        }
    }

    private func layoutNeonLayers() {
        guard gradientLayer != nil || glowLayer != nil else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let radius = layer.cornerRadius
        if let fill = gradientLayer {
            fill.frame = bounds
            fill.cornerRadius = radius
            fill.cornerCurve = .continuous
            fill.masksToBounds = true
        }
        if let halo = glowLayer {
            halo.frame = bounds
            halo.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: radius).cgPath
        }
        CATransaction.commit()
    }
}

private extension SoramitsuButton {
    func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = size.height / 2
        layer.cornerCurve = .continuous
        pressingView.layer.cornerRadius = size.height / 2
        
        addSubview(pressingView)
        addSubview(stackView)

        stackView.addArrangedSubview(leftImageView)
        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(rightImageView)
        
        horizontalConstaint = stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16)
        
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
            leftImageView.widthAnchor.constraint(equalTo: leftImageView.heightAnchor),

            heightAnchor.constraint(equalToConstant: size.height)
        ])
    }
}

public extension SoramitsuButton {
    convenience init(size: SoramitsuButtonSize = .large, type: SoramitsuButtonType = .filled(.primary)) {
        let sora = SoramitsuUI.shared
        self.init(style: sora.style, size: size, type: type)
    }
}
