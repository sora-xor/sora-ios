import Foundation
import CommonWallet

struct WalletConfirmationViewBinder {
    var separatorStyle: WalletStrokeStyleProtocol {
        WalletStrokeStyle(color: R.color.neumorphism.separator()!, lineWidth: 1.0)
    }

    var formDetailsViewStyle: WalletFormDetailsViewStyle {
        let title = WalletTextStyle(font: UIFont.styled(for: .paragraph1),
                                    color: UIColor(red: 0.176, green: 0.161, blue: 0.149, alpha: 1))

        let details = WalletTextStyle(font: UIFont.styled(for: .paragraph1, isBold: true),
                                      color: UIColor(red: 0.176, green: 0.161, blue: 0.149, alpha: 1))

        let contentInsets = UIEdgeInsets(top: 11, left: 0, bottom: 11, right: 0)

        return WalletFormDetailsViewStyle(title: title,
                                          separatorStyle: separatorStyle,
                                          contentInsets: contentInsets,
                                          titleHorizontalSpacing: 0,
                                          detailsHorizontalSpacing: 0,
                                          titleDetailsHorizontalSpacing: 0,
                                          details: details,
                                          detailsAlignment: .detailsIcon)
    }

    var noteStyle: WalletFormTitleIconViewStyle {
        let title = WalletTextStyle(font: UIFont.styled(for: .paragraph1),
                                    color: UIColor(red: 0.176, green: 0.161, blue: 0.149, alpha: 1))

        let contentInsets = UIEdgeInsets(top: 18, left: 0, bottom: 18, right: 0)

        return WalletFormTitleIconViewStyle(title: title,
                                            separatorStyle: separatorStyle,
                                            contentInsets: contentInsets,
                                            horizontalSpacing: 0)
    }

    var receiverStyle: WalletFormTitleIconViewStyle {
        let title = WalletTextStyle(font: UIFont.styled(for: .paragraph1, isBold: true),
                                    color: UIColor(red: 0.176, green: 0.161, blue: 0.149, alpha: 1))

        let contentInsets = UIEdgeInsets(top: 16, left: 0, bottom: 16, right: 0)

        return WalletFormTitleIconViewStyle(title: title,
                                            separatorStyle: separatorStyle,
                                            contentInsets: contentInsets,
                                            horizontalSpacing: 10)
    }

    var detailsHeaderStyle: WalletFormTitleIconViewStyle {
        let title = WalletTextStyle(font: UIFont.styled(for: .paragraph1, isBold: true),
                                    color: UIColor(red: 0.176, green: 0.161, blue: 0.149, alpha: 1))

        let contentInsets = UIEdgeInsets(top: 16, left: 0, bottom: 0, right: 0)

        return WalletFormTitleIconViewStyle(title: title,
                                            separatorStyle: separatorStyle,
                                            contentInsets: contentInsets,
                                            horizontalSpacing: 10)
    }

    var totalAmountStyle: WalletFormDetailsViewStyle {
        let title = WalletTextStyle(font: UIFont.styled(for: .paragraph1, isBold: true),
                                    color: UIColor(red: 0.176, green: 0.161, blue: 0.149, alpha: 1))

        let details = WalletTextStyle(font: UIFont.styled(for: .paragraph1, isBold: true).withSize(20),
                                      color: UIColor(red: 0.176, green: 0.161, blue: 0.149, alpha: 1))

        let contentInsets = UIEdgeInsets(top: 11, left: 0, bottom: 13, right: 0)

        return WalletFormDetailsViewStyle(title: title,
                                          separatorStyle: separatorStyle,
                                          contentInsets: contentInsets,
                                          titleHorizontalSpacing: 0,
                                          detailsHorizontalSpacing: 0,
                                          titleDetailsHorizontalSpacing: 0,
                                          details: details,
                                          detailsAlignment: .detailsIcon)
    }

    var tokenStyle: WalletFormTokenViewStyle {
        let title = WalletTextStyle(font: UIFont.styled(for: .paragraph1, isBold: true),
                                    color: UIColor(red: 0.176, green: 0.161, blue: 0.149, alpha: 1))

        let subtitle = WalletTextStyle(font: UIFont.styled(for: .paragraph1, isBold: true),
                                       color: UIColor(red: 0.459, green: 0.471, blue: 0.482, alpha: 1))

        let contentInsets = UIEdgeInsets(top: 17, left: 0.0, bottom: 16, right: 0.0)

        return WalletFormTokenViewStyle(title: title,
                                        subtitle: subtitle,
                                        contentInset: contentInsets,
                                        iconTitleSpacing: 11,
                                        separatorStyle: separatorStyle,
                                        displayStyle: .separatedDetails)
    }
}

extension WalletConfirmationViewBinder: WalletFormViewModelBinderProtocol, WalletFormViewModelBinderOverriding {
    func bind(viewModel: WalletNewFormDetailsViewModel, to view: WalletFormDetailsViewProtocol) {
        view.style = formDetailsViewStyle
        view.bind(viewModel: viewModel)
    }

    func bind(viewModel: MultilineTitleIconViewModel, to view: WalletFormTitleIconViewProtocol) {
        view.style = noteStyle
        view.bind(viewModel: viewModel)
    }

    func bind(viewModel: WalletFormSingleHeaderModel, to view: WalletFormTitleIconViewProtocol) {
        view.style = receiverStyle

        let targetViewModel = MultilineTitleIconViewModel(text: viewModel.title, icon: viewModel.icon)
        view.bind(viewModel: targetViewModel)
    }

    func bind(viewModel: WalletFormDetailsHeaderModel, to view: WalletFormTitleIconViewProtocol) {
        view.style = detailsHeaderStyle

        let targetViewModel = MultilineTitleIconViewModel(text: viewModel.title, icon: viewModel.icon)
        view.bind(viewModel: targetViewModel)
    }

    func bind(viewModel: WalletFormSpentAmountModel, to view: WalletFormDetailsViewProtocol) {
        view.style = totalAmountStyle

        let targetViewModel = WalletNewFormDetailsViewModel(title: viewModel.title,
                                                            titleIcon: nil,
                                                            details: viewModel.amount,
                                                            detailsIcon: nil)

        view.bind(viewModel: targetViewModel)
    }

    func bind(viewModel: WalletFormTokenViewModel, to view: WalletFormTokenViewProtocol) {
        view.style = tokenStyle
        view.bind(viewModel: viewModel)
    }
}
