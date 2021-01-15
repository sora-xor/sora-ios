/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet
import SoraFoundation

struct WalletTransferConfigurator {
    let localizationManager: LocalizationManagerProtocol
    let amountFormatterFactory: NumberFormatterFactoryProtocol
    let commandDecorator: WalletCommandDecoratorFactory
    let xorAsset: WalletAsset
    let valAsset: WalletAsset
    let ethAsset: WalletAsset
    var errorHandler: WalletTransferErrorHandler?

    var commandFactory: WalletCommandFactoryProtocol? {
        get {
            errorHandler?.commandFactory
        }
        set {
            errorHandler?.commandFactory = newValue
        }
    }

    init(localizationManager: LocalizationManagerProtocol,
         amountFormatterFactory: NumberFormatterFactoryProtocol,
         commandDecorator: WalletCommandDecoratorFactory,
         commandFactory: WalletCommandFactoryProtocol?,
         xorAsset: WalletAsset,
         valAsset: WalletAsset,
         ethAsset: WalletAsset) {
        self.localizationManager = localizationManager
        self.amountFormatterFactory = amountFormatterFactory
        self.commandDecorator = commandDecorator
//        self.commandFactory = commandFactory
        self.xorAsset = xorAsset
        self.valAsset = valAsset
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

    mutating func configure(using builder: TransferModuleBuilderProtocol) {
        let feeCalculationFactory = WalletFeeCalculatorFactory(xorPrecision: valAsset.precision,
                                                               ethPrecision: ethAsset.precision)
        let viewModelFactory = WalletTransferViewModelFactory(amountFormatterFactory: amountFormatterFactory,
                                                              feeCalculationFactory: feeCalculationFactory,
                                                              xorAsset: valAsset)

        let title: LocalizableResource<String> = LocalizableResource { (locale: Locale) in
            let assetName = R.string.localizable.assetDetailsVal(preferredLanguages: locale.rLanguages)
            return R.string.localizable
                .walletTransferTitleFormat(assetName,
                                           preferredLanguages: locale.rLanguages)
        }

        let transferValidator = WalletTransferValidator()

        let changeHandler = WalletTransferChangeHandler()

        self.errorHandler = WalletTransferErrorHandler(xorAsset: valAsset,
                                                      ethAsset: ethAsset,
                                                      formatterFactory: amountFormatterFactory,
                                                      commandDecorator: commandDecorator,
                                                      commandFactory: commandFactory)

        builder
            .with(resultValidator: transferValidator)
            .with(transferViewModelFactory: viewModelFactory)
            .with(changeHandler: changeHandler)
            .with(headerFactory: WalletTransferHeaderModelFactory())
            .with(operationDefinitionFactory: OperationDefinitionViewFactoryOverride())
            .with(separatorsDistribution: WalletTransferSeparatorsDistribution())
            .with(errorHandler: errorHandler! as OperationDefinitionErrorHandling)
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

struct OperationDefinitionViewFactoryOverride: OperationDefinitionViewFactoryOverriding {
    func createErrorViewForItem(type: OperationDefinitionType) -> BaseOperationDefinitionErrorView? {
        switch type {
        case .receiver :
            let style = WalletTransferConfigurator.errorStyle
            let view = ContainingErrorView()

            view.titleLabel.textColor = style.inlineErrorStyle.titleColor
            view.titleLabel.font = style.inlineErrorStyle.titleFont

            view.contentInsets = style.contentInsets
            view.horizontalSpacing = style.horizontalSpacing

            view.icon = style.inlineErrorStyle.icon

            return view
        default:
            return nil

        }
    }
}

final class ContainingErrorView: MultilineTitleIconView, OperationDefinitionErrorViewProtocol {
    func bind(errorMessage: String) {
        self.title = errorMessage
    }

    override public func bind(viewModel: MultilineTitleIconViewModelProtocol) {
        self.title = viewModel.text
        self.icon = viewModel.icon
        self.command = viewModel.command
    }

    var command: WalletCommandProtocol? {
        didSet {
            if command != nil {
                self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(runCommand)))
                addAccessoryIcon()
            }
        }
    }

    func addAccessoryIcon() {
        let icon = UIImageView(image: R.image.iconSmallArrow())
        icon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(icon)
        icon.widthAnchor.constraint(equalToConstant: 6).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 11).isActive = true
        icon.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -1).isActive = true
        icon.centerYAnchor.constraint(equalTo: self.centerYAnchor, constant: 0).isActive = true
    }

    @objc func runCommand() {
        try? command?.execute()
    }
}

class MultilineTitleIconView: UIView {
    private(set) var titleLabel: UILabel = UILabel()

    private var imageView: UIImageView?

    private var preferredWidth: CGFloat = 0.0

    var title: String? {
        get {
            titleLabel.text
        }

        set {
            titleLabel.text = newValue

            invalidateLayout()
        }
    }

    var icon: UIImage? {
        get {
            imageView?.image
        }

        set {
            if let newIcon = newValue {
                if imageView == nil {
                    let imageView = UIImageView()
                    addSubview(imageView)
                    self.imageView = imageView
                }

                imageView?.image = newIcon
            } else {
                if imageView != nil {
                    imageView?.removeFromSuperview()
                    imageView = nil
                }
            }

            invalidateLayout()
        }
    }

    var horizontalSpacing: CGFloat = 6.0 {
        didSet {
            invalidateLayout()
        }
    }

    var contentInsets: UIEdgeInsets = .zero {
        didSet {
            invalidateLayout()
        }
    }

    public func bind(viewModel: MultilineTitleIconViewModelProtocol) {
        self.title = viewModel.text
        self.icon = viewModel.icon
    }

    // MARK: Overridings

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        titleLabel.numberOfLines = 0
        addSubview(titleLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override var intrinsicContentSize: CGSize {
        guard preferredWidth > 0.0 else {
            return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
        }

        var resultSize = CGSize(width: UIView.noIntrinsicMetric, height: 0.0)

        var imageSize = CGSize.zero

        if let imageView = imageView {
            imageSize = imageView.intrinsicContentSize
            resultSize.height = imageSize.height
        }

        let offsetFromIcon = imageSize.width > 0.0 ? imageSize.width + horizontalSpacing : 0.0
        let boundingWidth = max(preferredWidth - offsetFromIcon - contentInsets.left
            - contentInsets.right, 0.0)
        let boundingSize = CGSize(width: boundingWidth, height: CGFloat.greatestFiniteMagnitude)
        let titleSize = titleLabel.sizeThatFits(boundingSize)

        resultSize.height = max(resultSize.height, titleSize.height)

        if resultSize.height > 0.0 {
            resultSize.height += contentInsets.top + contentInsets.bottom
        }

        return resultSize
    }

    public override func layoutSubviews() {
        super.layoutSubviews()

        var horizontalOffset = contentInsets.left

        let inset = (contentInsets.top - contentInsets.bottom) / 2.0

        if let imageView = imageView {
            let imageSize = imageView.image?.size ?? .zero
            imageView.frame = CGRect(x: horizontalOffset,
                                     y: bounds.height / 2.0 - imageSize.height / 2.0 + inset,
                                     width: imageSize.width,
                                     height: imageSize.height)
            horizontalOffset += imageSize.width + horizontalSpacing
        }

        let titleHeight = bounds.size.height - contentInsets.top - contentInsets.bottom

        titleLabel.frame = CGRect(x: horizontalOffset,
                                  y: bounds.height / 2.0 - titleHeight / 2.0 + inset,
                                  width: bounds.width - horizontalOffset - contentInsets.right,
                                  height: titleHeight)

        if abs(bounds.width - preferredWidth) > CGFloat.leastNormalMagnitude {
            preferredWidth = bounds.width
            invalidateIntrinsicContentSize()
        }
    }

    // MARK: Private

    private func invalidateLayout() {
        invalidateIntrinsicContentSize()

        if superview != nil {
            setNeedsLayout()
        }
    }
}
