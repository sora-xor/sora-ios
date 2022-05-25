import Foundation
import CommonWallet

struct WalletCommonStyleConfigurator {
    let navigationBarStyle: WalletNavigationBarStyleProtocol = {
        var navigationBarStyle = WalletNavigationBarStyle(barColor: R.color.baseBackground()!,
                                                          shadowColor: .clear,
                                                          itemTintColor: R.color.neumorphism.navBarIcon()!,
                                                          titleColor: R.color.neumorphism.text()!,
                                                          titleFont: UIFont.styled(for: .title1))
        return navigationBarStyle
    }()

    let accessoryStyle: WalletAccessoryStyleProtocol = {
        let title = WalletTextStyle(font: UIFont.styled(for: .display2),
                                    color: R.color.baseContentPrimary()!)

        let buttonTitle = WalletTextStyle(font: UIFont.styled(for: .button),
                                          color: R.color.baseContentPrimary()!)

        let buttonStyle = WalletRoundedButtonStyle(background: R.color.brandSoramitsuRed()!,
                                                   title: buttonTitle)

        let separator = WalletStrokeStyle(color: .clear, lineWidth: 0.0)

        return WalletAccessoryStyle(title: title,
                                    action: buttonStyle,
                                    separator: separator,
                                    background: R.color.baseBackground()!)
    }()
}

extension WalletCommonStyleConfigurator {
    func configure(builder: WalletStyleBuilderProtocol) {
        let errorStyle = WalletInlineErrorStyle(titleColor: UIColor(red: 0.942, green: 0, blue: 0.044, alpha: 1),
                                                titleFont: UIFont.styled(for: .paragraph3)!,
                                                icon: R.image.iconWarning()!)
        builder
            .with(background: R.color.neumorphism.base()!)
            .with(navigationBarStyle: navigationBarStyle)
            .with(header1: UIFont.styled(for: .title1))
            .with(header2: UIFont.styled(for: .title2))
            .with(header3: UIFont.styled(for: .title3))
            .with(header4: UIFont.styled(for: .title4))
            .with(bodyBold: UIFont.styled(for: .paragraph1, isBold: true))
            .with(bodyRegular: UIFont.styled(for: .paragraph1))
            .with(small: UIFont.styled(for: .paragraph3))
            .with(keyboardIcon: R.image.iconKeyboardOff()!)
            .with(caretColor: R.color.brandSoramitsuRed()!)
            .with(closeIcon: R.image.close())
            .with(inlineErrorStyle: errorStyle)
    }
}
