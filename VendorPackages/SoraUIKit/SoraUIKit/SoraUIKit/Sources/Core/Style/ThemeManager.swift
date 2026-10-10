import UIKit

final class ThemeManager {

	var theme: SoramitsuThemeType {
        switch mode {
        case .system:
            return systemTheme
        case let .manual(theme):
            return theme
        }
    }

	var themeMode: SoramitsuThemeMode {
		get {
			return mode
		}
		set {
			self.mode = newValue
			switch mode {
			case .system:
				storage.theme = nil
			case let .manual(theme):
				storage.theme = theme
			}
			systemTheme = currentSystemTheme
			updateTheme()
		}
	}

	private(set) lazy var style = SoramitsuStyle(palette: theme.palette,
                                         radii: DefaultRadii(),
                                         shady: DefaultShady(),
                                         layout: DefaultLayout(),
                                         statusBar: theme.statusBar)
	private let storage: ThemeStorage

	private lazy var systemTheme: SoramitsuThemeType = currentSystemTheme
	private var mode: SoramitsuThemeMode
	private var observers: [NSObjectProtocol] = []

	/// The device appearance. Read from the screen, which in-app window
	/// overrides do not affect. `UITraitCollection.current` can be
	/// unspecified at cold launch or reflect an override.
	private var currentSystemTheme: SoramitsuThemeType {
		// UIKit scene state is main-thread only; elsewhere use the current traits.
		let screenStyle = Thread.isMainThread
			? UIApplication.shared.connectedScenes
				.compactMap { $0 as? UIWindowScene }
				.first?.screen.traitCollection.userInterfaceStyle
			: nil
		switch screenStyle ?? UITraitCollection.current.userInterfaceStyle {
		case .dark:
			return .dark
		case .light, .unspecified:
			return .light
		@unknown default:
			return .light
		}
	}

	init(storage: ThemeStorage) {
        self.storage = storage
        if let theme = storage.theme {
            mode = .manual(theme)
        } else {
            mode = .system
        }

		let center = NotificationCenter.default
		observers.append(center.addObserver(forName: UIApplication.didBecomeActiveNotification,
											object: nil, queue: .main) { [weak self] _ in
			self?.refreshSystemTheme()
		})
		// Glass, glow and shadow choices depend on accessibility and power
		// settings: re-resolve every surface when they change.
		observers.append(center.addObserver(forName: .neonFxChanged, object: nil, queue: .main) { [weak self] _ in
			guard let self else { return }
			self.style.apply(self.theme.palette)
		})
		_ = NeonFxCenter.shared
	}

	/// Re-reads the device appearance; call when the system trait changes.
	func refreshSystemTheme() {
		guard case .system = mode else { return }
		let current = currentSystemTheme
		if systemTheme != current {
			systemTheme = current
			updateTheme()
		}
	}

	private func updateTheme() {
		style.apply(theme.palette)
		style.apply(theme.statusBar)
		syncWindows()
	}

	/// The `overrideUserInterfaceStyle` matching the in-app choice, so system
	/// UI (alerts, keyboards, sheets, Liquid Glass, system materials) follows
	/// the app theme rather than the device setting.
	var userInterfaceStyle: UIUserInterfaceStyle {
		switch mode {
		case .system:
			return .unspecified
		case let .manual(theme):
			return theme == .dark ? .dark : .light
		}
	}

	func applyInterfaceStyle(to window: UIWindow) {
		if window.overrideUserInterfaceStyle != userInterfaceStyle {
			window.overrideUserInterfaceStyle = userInterfaceStyle
		}
	}

	/// Applies the style to the app's own windows in every connected scene.
	/// UIKit's private windows (keyboard, text effects) are left alone.
	func syncWindows() {
		let uiKit = Bundle(for: UIWindow.self)
		for scene in UIApplication.shared.connectedScenes {
			guard let windowScene = scene as? UIWindowScene else { continue }
			for window in windowScene.windows
			where type(of: window) == UIWindow.self || Bundle(for: type(of: window)) != uiKit {
				applyInterfaceStyle(to: window)
			}
		}
	}
}
