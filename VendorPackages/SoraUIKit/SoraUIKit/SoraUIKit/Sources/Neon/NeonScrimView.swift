import UIKit

/// Modal backdrop: the screen below, blurred and tinted with the page
/// colour of the app theme. Dark mode gets a dark backdrop (it used to be a
/// light blur in both themes). With reduced transparency it is a nearly
/// opaque page-coloured layer without blur.
public final class NeonScrimView: UIView {
    private var effectView: UIVisualEffectView?
    private let dim = UIView()
    private var observer: NSObjectProtocol?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        backgroundColor = .clear
        dim.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(dim)
        apply()
        SoramitsuUI.updates.addObserver(self)
        observer = NotificationCenter.default.addObserver(forName: .neonFxChanged, object: nil, queue: .main) {
            [weak self] _ in self?.apply()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        observer.map(NotificationCenter.default.removeObserver)
    }

    public func apply() {
        let tokens = NeonTokens.current
        let fx = FxPolicy.current
        effectView?.removeFromSuperview()
        effectView = nil
        if !fx.opaqueGlass {
            let effect = UIVisualEffectView(effect: UIBlurEffect(style: tokens.isDark ? .systemThinMaterialDark
                                                                                   : .systemThinMaterialLight))
            effect.frame = bounds
            effect.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            effect.isUserInteractionEnabled = false
            insertSubview(effect, at: 0)
            effectView = effect
        }
        dim.frame = bounds
        // Full-screen flows sit directly on this backdrop, so it is tinted
        // with the page colour (dark stays dark, light stays light) rather
        // than greyed with a black scrim.
        if fx.opaqueGlass {
            dim.backgroundColor = tokens.canvas.withAlphaComponent(0.94)
        } else {
            dim.backgroundColor = tokens.canvas.withAlphaComponent(tokens.isDark ? 0.55 : 0.45)
        }
    }
}

extension NeonScrimView: SoramitsuObserver {
    public func styleDidChange(options: UpdateOptions) {
        if options.contains(.palette) { apply() }
    }
}
