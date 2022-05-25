import Foundation
import CommonWallet

struct WalletTransactionDetailsViewBinder {
    var separatorStyle: WalletStrokeStyleProtocol {
        WalletStrokeStyle(color: R.color.neumorphism.tableSeparator()!, lineWidth: 1.0)
    }

    var formDetailsViewStyle: WalletFormDetailsViewStyle {
        let title = WalletTextStyle(font: UIFont.styled(for: .paragraph1),
                                    color: R.color.neumorphism.textDark()!)

        let details = WalletTextStyle(font: UIFont.styled(for: .paragraph1, isBold: true),
                                      color: R.color.neumorphism.textDark()!)

        let contentInsets = UIEdgeInsets(top: 11, left: 0, bottom: 11, right: 0)

        return WalletFormDetailsViewStyle(title: title,
                                          separatorStyle: separatorStyle,
                                          contentInsets: contentInsets,
                                          titleHorizontalSpacing: 0,
                                          detailsHorizontalSpacing: 6,
                                          titleDetailsHorizontalSpacing: 0,
                                          details: details,
                                          detailsAlignment: .detailsIcon)
    }

    var noteStyle: WalletFormTitleIconViewStyle {
        let title = WalletTextStyle(font: UIFont.styled(for: .paragraph1),
                                    color: R.color.neumorphism.textDark()!)

        let contentInsets = UIEdgeInsets(top: 18, left: 0, bottom: 18, right: 0)

        return WalletFormTitleIconViewStyle(title: title,
                                            separatorStyle: separatorStyle,
                                            contentInsets: contentInsets,
                                            horizontalSpacing: 0)
    }

    var singleHeaderStyle: WalletFormTitleIconViewStyle {
        let title = WalletTextStyle(font: UIFont.styled(for: .paragraph1, isBold: true),
                                    color: R.color.neumorphism.textDark()!)

        let contentInsets = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)

        return WalletFormTitleIconViewStyle(title: title,
                                            separatorStyle: separatorStyle,
                                            contentInsets: contentInsets,
                                            horizontalSpacing: 10)
    }

    var detailsHeaderStyle: WalletFormTitleIconViewStyle {
        let title = WalletTextStyle(font: UIFont.styled(for: .paragraph1, isBold: true),
                                    color: R.color.neumorphism.textDark()!)

        let contentInsets = UIEdgeInsets(top: 16, left: 0, bottom: 0, right: 0)

        return WalletFormTitleIconViewStyle(title: title,
                                            separatorStyle: separatorStyle,
                                            contentInsets: contentInsets,
                                            horizontalSpacing: 10)
    }

    var totalAmountStyle: WalletFormDetailsViewStyle {
        let title = WalletTextStyle(font: UIFont.styled(for: .paragraph1, isBold: true),
                                    color: R.color.neumorphism.textDark()!)

        let details = WalletTextStyle(font: UIFont.styled(for: .paragraph1, isBold: true).withSize(20),
                                      color: R.color.neumorphism.textDark()!)

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
}

extension WalletTransactionDetailsViewBinder: WalletFormViewModelBinderOverriding {
    func bind(viewModel: WalletNewFormDetailsViewModel, to view: WalletFormDetailsViewProtocol) -> Bool {
        view.style = formDetailsViewStyle
        view.bind(viewModel: viewModel)

        return true
    }

    func bind(viewModel: MultilineTitleIconViewModel, to view: WalletFormTitleIconViewProtocol) -> Bool {
        view.style = noteStyle
        view.bind(viewModel: viewModel)

        return true
    }

    func bind(viewModel: WalletFormSingleHeaderModel, to view: WalletFormTitleIconViewProtocol) -> Bool {
        view.style = singleHeaderStyle

        let targetViewModel = MultilineTitleIconViewModel(text: viewModel.title, icon: viewModel.icon)
        view.bind(viewModel: targetViewModel)

        return true
    }

    func bind(viewModel: WalletFormDetailsHeaderModel, to view: WalletFormTitleIconViewProtocol) -> Bool {
        view.style = detailsHeaderStyle

        let targetViewModel = MultilineTitleIconViewModel(text: viewModel.title, icon: viewModel.icon)
        view.bind(viewModel: targetViewModel)

        return true
    }

    func bind(viewModel: WalletFormSpentAmountModel, to view: WalletFormDetailsViewProtocol) -> Bool {
        view.style = totalAmountStyle

        let targetViewModel = WalletNewFormDetailsViewModel(title: viewModel.title,
                                                            titleIcon: nil,
                                                            details: viewModel.amount,
                                                            detailsIcon: nil)

        view.bind(viewModel: targetViewModel)

        return true
    }
}
