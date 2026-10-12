import UIKit

/// Effect tiers (spec §4.0). Decided once, read everywhere.
public enum FxTier {
    /// Default: glass, glow, finite pulses, aurora with grid.
    case full
    /// Low Power Mode or a hot device: static glows only, no pulses.
    case reduced
    /// Reduce Transparency or the in-app "Reduce effects": opaque surfaces,
    /// ring instead of glow, no live blur.
    case minimal
}

public struct FxPolicy {
    /// In-app "Reduce effects" switch. A new key: the theme keys are never touched.
    public static let reduceEffectsKey = "neon.reduceEffects"

    public static var reduceEffects: Bool {
        get { UserDefaults.standard.bool(forKey: reduceEffectsKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: reduceEffectsKey)
            NeonFxCenter.shared.post()
        }
    }

    public static var current: FxPolicy { FxPolicy() }

    public var tier: FxTier {
        if FxPolicy.reduceEffects || UIAccessibility.isReduceTransparencyEnabled { return .minimal }
        let info = ProcessInfo.processInfo
        if info.isLowPowerModeEnabled || info.thermalState == .serious || info.thermalState == .critical {
            return .reduced
        }
        return .full
    }

    public var reduceMotion: Bool { UIAccessibility.isReduceMotionEnabled }
    public var highContrast: Bool { UIAccessibility.isDarkerSystemColorsEnabled }
    /// Translucent glass becomes `glassSolid`, no sheen, no live blur.
    public var opaqueGlass: Bool { tier == .minimal || highContrast }
    public var glows: Bool { !highContrast }
    public var pulses: Bool { tier == .full && !reduceMotion }
    /// Grid texture (aurora is always drawn).
    public var ambientDetail: Bool { tier != .minimal }
}

public extension Notification.Name {
    /// Posted on the main queue when any input of `FxPolicy` changes.
    static let neonFxChanged = Notification.Name("neon.fx.changed")
}

/// Turns the system accessibility and power notifications into one
/// `.neonFxChanged` notification on the main queue.
public final class NeonFxCenter {
    public static let shared = NeonFxCenter()

    private var observers: [NSObjectProtocol] = []

    private init() {
        let names: [Notification.Name] = [
            UIAccessibility.reduceMotionStatusDidChangeNotification,
            UIAccessibility.reduceTransparencyStatusDidChangeNotification,
            UIAccessibility.darkerSystemColorsStatusDidChangeNotification,
            UIAccessibility.boldTextStatusDidChangeNotification,
            .NSProcessInfoPowerStateDidChange,
            ProcessInfo.thermalStateDidChangeNotification
        ]
        observers = names.map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) { [weak self] _ in
                self?.post()
            }
        }
    }

    /// Starts listening. Safe to call more than once.
    public func start() {}

    func post() {
        let send = { NotificationCenter.default.post(name: .neonFxChanged, object: nil) }
        Thread.isMainThread ? send() : DispatchQueue.main.async(execute: send)
    }
}
