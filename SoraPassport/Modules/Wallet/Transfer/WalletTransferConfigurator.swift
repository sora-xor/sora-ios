import Foundation
import CommonWallet
import SoraFoundation

struct WalletTransferConfigurator {
    let localizationManager: LocalizationManagerProtocol
    let amountFormatterFactory: NumberFormatterFactoryProtocol
    let xorAsset: WalletAsset
    let ethAsset: WalletAsset

    init(localizationManager: LocalizationManagerProtocol,
         amountFormatterFactory: NumberFormatterFactoryProtocol,
         xorAsset: WalletAsset,
         ethAsset: WalletAsset) {
        self.localizationManager = localizationManager
        self.amountFormatterFactory = amountFormatterFactory
        self.xorAsset = xorAsset
        self.ethAsset = ethAsset
    }

    static let headerStyle: WalletContainingHeaderStyle = {
        let text = WalletTextStyle(font: R.font.soraRc0040417Bold(size: 14)!,
                                   color: UIColor(red: 0.125, green: 0.125, blue: 0.125, alpha: 1))
        let contentInsets = UIEdgeInsets(top: 15.0, left: 0.0, bottom: 0.0, right: 0.0)

        return WalletContainingHeaderStyle(titleStyle: text,
                                           horizontalSpacing: 6.0,
                                           contentInsets: contentInsets)
    }()

    static let errorStyle: WalletContainingErrorStyle = {
        let error = WalletInlineErrorStyle(titleColor: UIColor(red: 0.942, green: 0, blue: 0.044, alpha: 1),
                                           titleFont: R.font.soraRc0040417Regular(size: 12)!,
                                           icon: R.image.iconWarning()!)
        let contentInsets = UIEdgeInsets(top: 16.0, left: 0.0, bottom: 16.0, right: 0.0)
        return WalletContainingErrorStyle(inlineErrorStyle: error,
                                          horizontalSpacing: 6.0,
                                          contentInsets: contentInsets)
    }()

    static let separatorStyle: WalletStrokeStyle = {
        WalletStrokeStyle(color: UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 0.35), lineWidth: 1.0)
    }()

    static let assetStyle: WalletContainingAssetStyle = {
        let title = WalletTextStyle(font: R.font.soraRc0040417SemiBold(size: 14)!,
                                    color: UIColor(red: 0.125, green: 0.125, blue: 0.125, alpha: 1))
        let subtitle = WalletTextStyle(font: R.font.soraRc0040417SemiBold(size: 14)!,
                                       color: UIColor(red: 0.459, green: 0.471, blue: 0.482, alpha: 1))
        let details = WalletTextStyle(font: R.font.soraRc0040417Regular(size: 12)!,
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
                                          containingErrorStyle: errorStyle)
    }()

    static let receiverStyle: WalletContainingReceiverStyle = {
        let textStyle = WalletTextStyle(font: R.font.soraRc0040417Regular(size: 14)!,
                                        color: UIColor(red: 0.125, green: 0.125, blue: 0.125, alpha: 1))
        let contentInsets = UIEdgeInsets(top: 15.0, left: 0.0, bottom: 15.0, right: 0.0)

        return WalletContainingReceiverStyle(containingHeaderStyle: headerStyle,
                                             textStyle: textStyle,
                                             horizontalSpacing: 8.0,
                                             contentInsets: contentInsets,
                                             separatorStyle: separatorStyle,
                                             containingErrorStyle: errorStyle)
    }()

    static let amountStyle: WalletContainingAmountStyle = {
        let textStyle = WalletTextStyle(font: R.font.soraRc0040417SemiBold(size: 18.0)!,
                                        color: UIColor(red: 0.125, green: 0.125, blue: 0.125, alpha: 1))
        let contentInsets = UIEdgeInsets(top: 8.0, left: 0.0, bottom: 15, right: 0.0)

        return WalletContainingAmountStyle(containingHeaderStyle: headerStyle,
                                           assetStyle: textStyle,
                                           inputStyle: textStyle,
                                           keyboardIndicatorMode: .always,
                                           keyboardIcon: nil,
                                           caretColor: nil,
                                           horizontalSpacing: 5.0,
                                           contentInsets: contentInsets,
                                           separatorStyle: separatorStyle,
                                           containingErrorStyle: errorStyle)
    }()

    static let feeHeaderStyle: WalletContainingHeaderStyle = {
        let text = WalletTextStyle(font: R.font.soraRc0040417Regular(size: 12)!,
                                   color: UIColor(red: 0.459, green: 0.471, blue: 0.482, alpha: 1))
        let contentInsets = UIEdgeInsets(top: 15.0, left: 0.0, bottom: 0.0, right: 0.0)

        return WalletContainingHeaderStyle(titleStyle: text,
                                           horizontalSpacing: 10.0,
                                           contentInsets: contentInsets)
    }()

    static let feeStyle: WalletContainingFeeStyle = {
        let title = WalletTextStyle(font: R.font.soraRc0040417Regular(size: 14)!,
                                    color: UIColor(red: 0.125, green: 0.125, blue: 0.125, alpha: 1))
        let amount = WalletTextStyle(font: R.font.soraRc0040417SemiBold(size: 14)!,
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
                                        containingErrorStyle: errorStyle)
    }()

    static let descriptionStyle: WalletContainingDescriptionStyle = {
        let text = WalletTextStyle(font: R.font.soraRc0040417Regular(size: 14)!,
                                    color: UIColor(red: 0.125, green: 0.125, blue: 0.125, alpha: 1))
        let placeholder = WalletTextStyle(font: R.font.soraRc0040417Regular(size: 14)!,
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
                                                containingErrorStyle: errorStyle)
    }()

    static let generatingIconStyle: WalletNameIconStyleProtocol = {
        let textStyle = WalletTextStyle(font: R.font.soraRc0040417Regular(size: 12)!,
                                        color: UIColor(red: 0.379, green: 0.379, blue: 0.379, alpha: 1))
        return WalletNameIconStyle(background: .white,
                                   title: textStyle,
                                   radius: 12.0)
    }()

    func configure(using builder: TransferModuleBuilderProtocol) {
        let feeCalculationFactory = WalletFeeCalculatorFactory(xorPrecision: xorAsset.precision,
                                                               ethPrecision: ethAsset.precision)
        let viewModelFactory = WalletTransferViewModelFactory(amountFormatterFactory: amountFormatterFactory,
                                                              feeCalculationFactory: feeCalculationFactory,
                                                              xorAsset: xorAsset)

        let title: LocalizableResource<String> = LocalizableResource { (locale: Locale) in
            let assetName = R.string.localizable.assetDetails(preferredLanguages: locale.rLanguages)
            return R.string.localizable
                .walletTransferTitleFormat(assetName,
                                           preferredLanguages: locale.rLanguages)
        }

        let transferValidator = WalletTransferValidator()

        let changeHandler = WalletTransferChangeHandler()

        let errorHandler = WalletTransferErrorHandler(xorAsset: xorAsset,
                                                      ethAsset: ethAsset,
                                                      formatterFactory: amountFormatterFactory)

        builder
            .with(resultValidator: transferValidator)
            .with(transferViewModelFactory: viewModelFactory)
            .with(changeHandler: changeHandler)
            .with(headerFactory: WalletTransferHeaderModelFactory())
            .with(separatorsDistribution: WalletTransferSeparatorsDistribution())
            .with(errorHandler: errorHandler)
            .with(selectedAssetStyle: Self.assetStyle)
            .with(receiverStyle: Self.receiverStyle)
            .with(receiverPosition: .form)
            .with(amountStyle: Self.amountStyle)
            .with(feeStyle: Self.feeStyle)
            .with(descriptionStyle: Self.descriptionStyle)
            .with(accessoryViewType: .onlyActionBar)
            .with(generatingIconStyle: Self.generatingIconStyle)
            .with(localizableTitle: title)
    }
}
