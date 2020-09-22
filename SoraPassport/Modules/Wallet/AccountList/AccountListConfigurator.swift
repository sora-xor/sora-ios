import Foundation
import CommonWallet
import RobinHood
import SoraFoundation
import CoreData

final class AccountListConfigurator {
    let dataProvider: StreamableProvider<EthereumInit>
    let commandDecorator: WalletCommandDecoratorFactoryProtocol
    let amountFormatterFactory: NumberFormatterFactoryProtocol
    let xorAsset: WalletAsset
    let ethAsset: WalletAsset
    let headerViewModel: WalletHeaderViewModel
    let logger: LoggerProtocol

    let assetStyleFactory: AssetCellStyleFactoryProtocol
    let viewModelFactory: AccountListViewModelFactory

    var commandFactory: WalletCommandFactoryProtocol? {
        get {
            viewModelFactory.commandFactory
        }

        set {
            viewModelFactory.commandFactory = newValue
        }
    }

    init(dataProvider: StreamableProvider<EthereumInit>,
         commandDecorator: WalletCommandDecoratorFactoryProtocol,
         amountFormatterFactory: NumberFormatterFactoryProtocol,
         xorAsset: WalletAsset,
         ethAsset: WalletAsset,
         headerViewModel: WalletHeaderViewModel,
         logger: LoggerProtocol) {
        self.dataProvider = dataProvider
        self.commandDecorator = commandDecorator
        self.amountFormatterFactory = amountFormatterFactory
        self.xorAsset = xorAsset
        self.ethAsset = ethAsset
        self.headerViewModel = headerViewModel
        self.logger = logger

        assetStyleFactory = AssetStyleFactory(xorAssetId: xorAsset.identifier,
                                              ethAssetId: ethAsset.identifier)

        viewModelFactory = AccountListViewModelFactory(dataProvider: dataProvider,
                                                       commandDecorator: commandDecorator,
                                                       assetCellStyleFactory: assetStyleFactory,
                                                       amountFormatterFactory: amountFormatterFactory,
                                                       ethAssetId: ethAsset.identifier)
    }

    func configure(using builder: AccountListModuleBuilderProtocol) {
        do {
            let localHeaderViewModel = headerViewModel

            try builder
            .with(minimumContentHeight: localHeaderViewModel.itemHeight)
            .inserting(viewModelFactory: { localHeaderViewModel }, at: 0)
            .with(cellNib: UINib(resource: R.nib.walletAccountHeaderView),
                  for: localHeaderViewModel.cellReuseIdentifier)
            .with(cellNib: UINib(resource: R.nib.assetCollectionViewCell),
                  for: ConfigurableAssetConstants.cellReuseIdentifier)
            .with(assetCellStyleFactory: assetStyleFactory)
            .with(listViewModelFactory: viewModelFactory)
        } catch {
            logger.error("Can't customize account list: \(error)")
        }
    }
}
