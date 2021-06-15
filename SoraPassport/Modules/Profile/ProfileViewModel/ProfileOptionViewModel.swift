import UIKit

// MARK: - Base

protocol ProfileOptionViewModelProtocol {
    static var locale: Locale { get set }

    var option: ProfileOption { get }

    var iconImage: UIImage? { get }
    var title: String { get }

    var accessoryContent: ProfileOptionAccessoriableProtocol? { get }
    var switchContent: ProfileOptionSwitchableProtocol? { get }
}

struct ProfileOptionViewModel: ProfileOptionViewModelProtocol {
    static var locale: Locale = Locale.current

    var option: ProfileOption

    var iconImage: UIImage?
    var title: String

    var accessoryContent: ProfileOptionAccessoriableProtocol?
    var switchContent: ProfileOptionSwitchableProtocol?

    init(by option: ProfileOption) {
        self.option = option

        self.iconImage = option.iconImage()
        self.title = option.title(for: Self.locale)
    }

    init(by option: ProfileOption, accessoryTitle: String) {
        self.option = option

        self.iconImage = option.iconImage()
        self.title = option.title(for: Self.locale)

        self.accessoryContent = ProfileOptionAccessory(title: accessoryTitle)
    }

    init(by option: ProfileOption, switchIsOn: Bool, switchAction: ((Bool) -> Void)?) {
        self.option = option

        self.iconImage = option.iconImage()
        self.title = option.title(for: Self.locale)

        self.switchContent = ProfileOptionSwitch(isOn: switchIsOn, action: switchAction)
    }
}

extension ProfileOptionViewModel: Comparable {
    static func < (lhs: ProfileOptionViewModel, rhs: ProfileOptionViewModel) -> Bool {
        lhs.option.rawValue < rhs.option.rawValue
    }

    static func == (lhs: ProfileOptionViewModel, rhs: ProfileOptionViewModel) -> Bool {
        lhs.option.rawValue == rhs.option.rawValue
    }
}

// MARK: - Accessoriable

protocol ProfileOptionAccessoriableProtocol {
    var iconImage: UIImage? { get }
    var title: String { get }
}

struct ProfileOptionAccessory: ProfileOptionAccessoriableProtocol {
    var iconImage: UIImage?
    var title: String

    init(title: String, iconImage: UIImage? = nil) {
        self.iconImage = iconImage
        self.title = title
    }
}

// MARK: - Switchable

protocol ProfileOptionSwitchableProtocol {
    var isOn: Bool { get }
    var action: ((Bool) -> Void)? { get }
}

struct ProfileOptionSwitch: ProfileOptionSwitchableProtocol {
    var isOn: Bool
    var action: ((Bool) -> Void)?
}
