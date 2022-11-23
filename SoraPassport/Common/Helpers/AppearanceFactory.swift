import Foundation
import UIKit
import SoraUI
import CommonWallet
import SoraSwiftUI

struct AppearanceFactory {
    static func applyGlobalAppearance() {
        configureGlobalNavigationBar()
        configureButtons()
//        configureSearchBar()
    }

    private static func configureButtons() {
        SoraButton.appearance().titleFont = .styled(for: .button)
        SoraButton.appearance().cornerRadius = 12.0
        SoraButton.appearance().shadowOpacity = 0

        GrayCopyButton.appearance().titleFont = .styled(for: .paragraph2)
        GrayCopyButton.appearance().cornerRadius = 24.0
        GrayCopyButton.appearance().shadowOpacity = 0
    }

    private static func configureSearchBar() {
        let searchTextStyle = WalletTextStyle(font: UIFont.styled(for: .paragraph3),
                                              color: R.color.neumorphism.textDark()!)
        let searchPlaceholderStyle = WalletTextStyle(font: UIFont.styled(for: .paragraph3),
                                                     color: R.color.neumorphism.textDark()!)

        let searchStroke = WalletStrokeStyle(color: R.color.neumorphism.backgroundLightGrey()!,
                                             lineWidth: 1.0)
        let searchFieldStyle = WalletRoundedViewStyle(fill: R.color.neumorphism.backgroundLightGrey()!,
                                                      cornerRadius: 24.0,
                                                      stroke: searchStroke)
//        UISearchBar.appearance().searchTextField.textColor = .red

    }

    // TODO: SN-264. UINavigationBar configuration to decorator ??
    private static func configureGlobalNavigationBar() {

        // title color
        UINavigationBar.appearance().titleTextAttributes = [.foregroundColor: R.color.neumorphism.textDark() as Any,
                                                            .font: UIFont.styled(for: .title1) as Any]

        //TODO: Add navigation bar to design system
        UINavigationBar.appearance().tintColor = UIColor(hex: "EE2233")
        UINavigationBar.appearance().backgroundColor = R.color.neumorphism.base()
    }
}
