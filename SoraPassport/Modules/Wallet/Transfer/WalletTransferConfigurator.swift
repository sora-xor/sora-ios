import Foundation
import CommonWallet
import SoraFoundation

final class  WalletTransferConfigurator {
    let localizationManager: LocalizationManagerProtocol
    var errorHandler: WalletTransferErrorHandler?

    var commandFactory: WalletCommandFactoryProtocol? {
        get {
            viewModelFactory.commandFactory
        }
        set {
            errorHandler?.commandFactory = newValue
            viewModelFactory.commandFactory = newValue
        }
    }

    lazy private var headerStyle: WalletContainingHeaderStyle = {
        let text = WalletTextStyle(font: UIFont.styled(for: .paragraph1, isBold: true),
                                   color: UIColor(red: 0.125, green: 0.125, blue: 0.125, alpha: 1))
        let contentInsets = UIEdgeInsets(top: 15.0, left: 0.0, bottom: 0.0, right: 0.0)

        return WalletContainingHeaderStyle(titleStyle: text,
                                           horizontalSpacing: 6.0,
                                           contentInsets: contentInsets)
    }()

    static var errorStyle: WalletContainingErrorStyle = {
        let error = WalletInlineErrorStyle(titleColor: UIColor(red: 0.942, green: 0, blue: 0.044, alpha: 1),
                                           titleFont: UIFont.styled(for: .paragraph3),
                                           icon: R.image.iconWarning()!)
        let contentInsets = UIEdgeInsets(top: 16.0, left: 0.0, bottom: 16.0, right: 0.0)
        return WalletContainingErrorStyle(inlineErrorStyle: error,
                                          horizontalSpacing: 6.0,
                                          contentInsets: contentInsets)
    }()

    lazy private var separatorStyle: WalletStrokeStyle = {
        WalletStrokeStyle(color: UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 0.35), lineWidth: 1.0)
    }()

    lazy private var assetStyle: WalletContainingAssetStyle = {
        let title = WalletTextStyle(font: UIFont.styled(for: .paragraph1, isBold: true),
                                    color: UIColor(red: 0.125, green: 0.125, blue: 0.125, alpha: 1))
        let subtitle = WalletTextStyle(font: UIFont.styled(for: .paragraph1, isBold: true),
                                       color: UIColor(red: 0.459, green: 0.471, blue: 0.482, alpha: 1))
        let details = WalletTextStyle(font: UIFont.styled(for: .paragraph3),
                                      color: UIColor(red: 0.539, green: 0.539, blue: 0.539, alpha: 1))
        let contentInsets = UIEdgeInsets(top: 16.0, left: 0.0, bottom: 16, right: 0.0)

        return WalletContainingAssetStyle(containingHeaderStyle: headerStyle,
                                          titleStyle: title,
                                          subtitleStyle: subtitle,
                                          detailsStyle: details,
                                          switchIcon: nil,
                                          contentInsets: contentInsets,
                                          titleHorizontalSpacing: 10.0,
                                          detailsHorizontalSpacing: 8.0,
                                          displayStyle: .separatedDetails,
                                          separatorStyle: separatorStyle,
                                          containingErrorStyle: WalletTransferConfigurator.errorStyle)
    }()

    lazy private var receiverStyle: WalletContainingReceiverStyle = {
        let textStyle = WalletTextStyle(font: UIFont.styled(for: .paragraph1),
                                        color: UIColor(red: 0.125, green: 0.125, blue: 0.125, alpha: 1))
        let contentInsets = UIEdgeInsets(top: 15.0, left: 0.0, bottom: 15.0, right: 0.0)

        return WalletContainingReceiverStyle(containingHeaderStyle: headerStyle,
                                             textStyle: textStyle,
                                             horizontalSpacing: 8.0,
                                             contentInsets: contentInsets,
                                             separatorStyle: separatorStyle,
                                             containingErrorStyle: WalletTransferConfigurator.errorStyle)
    }()

    lazy private var amountStyle: WalletContainingAmountStyle = {
        let textStyle = WalletTextStyle(font: UIFont.styled(for: .paragraph1, isBold: true).withSize(18),
                                        color: UIColor(red: 0.125, green: 0.125, blue: 0.125, alpha: 1))
        let contentInsets = UIEdgeInsets(top: 8.0, left: 0.0, bottom: 15, right: 0.0)

        return WalletContainingAmountStyle(containingHeaderStyle: headerStyle,
                                           assetStyle: textStyle,
                                           inputStyle: textStyle,
                                           keyboardIndicatorMode: .always,
                                           keyboardIcon: nil,
                                           caretColor: nil,
                                           horizontalSpacing: 16.0,
                                           contentInsets: contentInsets,
                                           separatorStyle: separatorStyle,
                                           containingErrorStyle: WalletTransferConfigurator.errorStyle)
    }()

    lazy private var feeHeaderStyle: WalletContainingHeaderStyle = {
        let text = WalletTextStyle(font: UIFont.styled(for: .paragraph3),
                                   color: UIColor(red: 0.459, green: 0.471, blue: 0.482, alpha: 1))
        let contentInsets = UIEdgeInsets(top: 15.0, left: 0.0, bottom: 0.0, right: 0.0)

        return WalletContainingHeaderStyle(titleStyle: text,
                                           horizontalSpacing: 10.0,
                                           contentInsets: contentInsets)
    }()

    lazy private var feeStyle: WalletContainingFeeStyle = {
        let title = WalletTextStyle(font: UIFont.styled(for: .paragraph1),
                                    color: UIColor(red: 0.125, green: 0.125, blue: 0.125, alpha: 1))
        let amount = WalletTextStyle(font: UIFont.styled(for: .paragraph1, isBold: true),
                                     color: UIColor(red: 0.125, green: 0.125, blue: 0.125, alpha: 1))
        let contentInsets = UIEdgeInsets(top: 18.0, left: 0.0, bottom: 18.0, right: 0.0)

        return WalletContainingFeeStyle(containingHeaderStyle: feeHeaderStyle,
                                        titleStyle: title,
                                        amountStyle: amount,
                                        activityTintColor: nil,
                                        displayStyle: .separatedDetails,
                                        horizontalSpacing: 10.0,
                                        contentInsets: contentInsets,
                                        separatorStyle: separatorStyle,
                                        containingErrorStyle: WalletTransferConfigurator.errorStyle)
    }()

    lazy private var descriptionStyle: WalletContainingDescriptionStyle = {
        let text = WalletTextStyle(font: UIFont.styled(for: .paragraph1),
                                    color: UIColor(red: 0.125, green: 0.125, blue: 0.125, alpha: 1))
        let placeholder = WalletTextStyle(font: UIFont.styled(for: .paragraph1),
                                          color: UIColor(red: 0.631, green: 0.631, blue: 0.627, alpha: 1))
        let contentInsets = UIEdgeInsets(top: 19.0, left: 0.0, bottom: 0.0, right: 0.0)

        return WalletContainingDescriptionStyle(containingHeaderStyle: headerStyle,
                                                inputStyle: text,
                                                placeholderStyle: placeholder,
                                                keyboardIndicatorMode: .never,
                                                keyboardIcon: nil,
                                                caretColor: nil,
                                                contentInsets: contentInsets,
                                                separatorStyle: separatorStyle,
                                                containingErrorStyle: WalletTransferConfigurator.errorStyle)
    }()

    lazy private var generatingIconStyle: WalletNameIconStyleProtocol = {
        let textStyle = WalletTextStyle(font: UIFont.styled(for: .paragraph3),
                                        color: UIColor(red: 0.379, green: 0.379, blue: 0.379, alpha: 1))
        return WalletNameIconStyle(background: .white,
                                   title: textStyle,
                                   radius: 12.0)
    }()

    var viewModelFactory: WalletTransferViewModelFactory

    init(assets: [WalletAsset],
         assetManager: AssetManagerProtocol,
         amountFormatterFactory: AmountFormatterFactoryProtocol,
         localizationManager: LocalizationManagerProtocol) {
        viewModelFactory = WalletTransferViewModelFactory(assets: assets,
                                                          assetManager: assetManager,
                                                          amountFormatterFactory: amountFormatterFactory)
        self.localizationManager = localizationManager
    }

    func configure(builder: TransferModuleBuilderProtocol) {
        let title: LocalizableResource<String> = LocalizableResource { (locale: Locale) in
            let locale = LocalizationManager.shared.selectedLocale
            return R.string.localizable.transferAmountTitle(preferredLanguages: locale.rLanguages)
        }

        let definitionFactory = TransferDefinitionFactory()

        builder
            .with(localizableTitle: title)
            .with(containingHeaderStyle: headerStyle)
            .with(receiverStyle: receiverStyle)
            .with(feeStyle: feeStyle)
            .with(feeDisplayStyle: .separatedDetails)
            .with(receiverPosition: .form)
            .with(accessoryViewType: .onlyActionBar)
            .with(separatorsDistribution: WalletTransferSeparatorsDistribution())
            .with(changeHandler: WalletTransferChangeHandler())
            .with(headerFactory: WalletTransferHeaderModelFactory())
            .with(transferViewModelFactory: viewModelFactory)
            .with(amountStyle: amountStyle)
            .with(accessoryViewFactory: WalletSingleActionAccessoryFactory.self)
            .with(operationDefinitionFactory: definitionFactory)
            .with(resultValidator: WalletTransferValidator())
    }
}
