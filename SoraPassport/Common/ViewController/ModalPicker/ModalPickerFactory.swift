import Foundation
import SoraUI
import SoraFoundation
import IrohaCrypto
import FearlessUtils
import CommonWallet
import SoraKeystore

enum AccountHeaderType {
    case title(_ title: LocalizableResource<String>)
    case address(_ type: SNAddressType, title: LocalizableResource<String>)
}

struct ModalPickerFactory {

    static func createPickerForAssetList(_ types: [WalletAsset],
                                         selectedType: WalletAsset?,
                                         delegate: ModalPickerViewControllerDelegate?,
                                         context: AnyObject?) -> UIViewController? {
        guard types.count > 0 else {
            return nil
        }

        let viewController: ModalPickerViewController<LoadingIconWithTitleTableViewCell, LoadingIconWithTitleViewModel>
            = ModalPickerViewController(nib: R.nib.modalPickerViewController)
        viewController.navigationItem.largeTitleDisplayMode = .never
        viewController.localizedTitle = LocalizableResource { locale in
            R.string.localizable.commonChooseAsset(preferredLanguages: locale.rLanguages)
        }
        viewController.title =  R.string.localizable.commonChooseAsset(preferredLanguages: LocalizationManager.shared.selectedLocale.rLanguages)
        viewController.cellNib = UINib(resource: R.nib.loadingIconWithTitleTableViewCell)
        viewController.delegate = delegate
        viewController.modalPresentationStyle = .pageSheet
        viewController.context = context
        viewController.selectedIndex = -1

        viewController.viewModels = types.map { type in
            let symbolViewModel: WalletImageViewModelProtocol?
            var visible = false
            if  let assetManager = context as? AssetManagerProtocol,
                let assetInfo = assetManager.assetInfo(for: type.identifier),
                let iconString = assetInfo.icon {
                symbolViewModel = WalletSvgImageViewModel(svgString: iconString)
                visible = assetInfo.visible ?? false
            } else {
                symbolViewModel = nil
            }
            return LocalizableResource { locale in
                LoadingIconWithTitleViewModel(iconViewModel: symbolViewModel,
                                              title: type.name.value(for: locale), subtitle: type.platform?.value(for: locale),
                                              toggle: visible)
            }
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.sora)
        viewController.modalTransitioningFactory = factory

        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }

    static func createPickerList(_ accounts: [AccountItem],
                                 selectedAccount: AccountItem?,
                                 headerType: AccountHeaderType,
                                 delegate: ModalPickerViewControllerDelegate?,
                                 context: AnyObject?) -> UIViewController? {

        let viewController: ModalPickerViewController<AccountPickerTableViewCell, AccountPickerViewModel>
            = ModalPickerViewController(nib: R.nib.modalPickerViewController)

        switch headerType {
        case .title(let title):
            viewController.localizedTitle = title
        case .address(let type, let title):
            viewController.localizedTitle = title
            viewController.icon = type.icon
            viewController.actionType = .add
        }

        viewController.cellNib = UINib(resource: R.nib.accountPickerTableViewCell)
        viewController.delegate = delegate
        viewController.modalPresentationStyle = .custom
        viewController.context = context

        if let selectedAccount = selectedAccount {
            viewController.selectedIndex = accounts.firstIndex(of: selectedAccount) ?? NSNotFound
        } else {
            viewController.selectedIndex = NSNotFound
        }

        let iconGenerator = PolkadotIconGenerator()

        viewController.viewModels = accounts.compactMap { account in
            let viewModel: AccountPickerViewModel
            if let icon = try? iconGenerator.generateFromAddress(account.address) {
                viewModel = AccountPickerViewModel(title: account.username, icon: icon)
            } else {
                viewModel = AccountPickerViewModel(title: account.username, icon: EmptyAccountIcon())
            }

            return LocalizableResource { _ in viewModel }
        }

        let factory = ModalSheetPresentationFactory(configuration: ModalSheetPresentationConfiguration.sora)
        viewController.modalTransitioningFactory = factory

        let height = viewController.headerHeight + CGFloat(accounts.count) * viewController.cellHeight +
            viewController.footerHeight
        viewController.preferredContentSize = CGSize(width: 0.0, height: height)

        viewController.localizationManager = LocalizationManager.shared

        return viewController
    }

}
