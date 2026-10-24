import UIKit

public final class SoramitsuUI {

    public static let shared: SoramitsuUI = {
        let storage = ThemeStorage()
        let manager = ThemeManager(storage: storage)
        let soraUI = SoramitsuUI(themeManager: manager)
        return soraUI
    }()

    public var theme: SoramitsuThemeType {
        return themeManager.theme
    }

    /// The stored choice (system, dark or light). Upgrades never rewrite it.
    public var themeMode: SoramitsuThemeMode {
        get { themeManager.themeMode }
        set { themeManager.themeMode = newValue }
    }

    public static var updates: SoramitsuObservable {
        return shared.style
    }

    /// `overrideUserInterfaceStyle` for the app's windows: unspecified when
    /// following the system, otherwise the in-app choice.
    public var userInterfaceStyle: UIUserInterfaceStyle {
        themeManager.userInterfaceStyle
    }

    /// Applies the in-app theme to a window. Call for every new window.
    public func applyInterfaceStyle(to window: UIWindow) {
        themeManager.applyInterfaceStyle(to: window)
    }

    /// Applies the in-app theme to all of the app's windows.
    public func syncWindowsInterfaceStyle() {
        themeManager.syncWindows()
    }

    /// Re-reads the device appearance (for "System" mode). Call when the
    /// trait collection of a root view changes.
    public func refreshSystemTheme() {
        themeManager.refreshSystemTheme()
    }

    var style: SoramitsuStyle {
        return themeManager.style
    }

    private let themeManager: ThemeManager

    private init(themeManager: ThemeManager) {
        self.themeManager = themeManager
    }
}
