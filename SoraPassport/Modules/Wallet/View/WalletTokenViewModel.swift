import Foundation
import CommonWallet

struct WalletTokenViewModel: AssetSelectionViewModelProtocol {
    var state: SelectedAssetState
    
    let header: String
    
    let title: String
    
    let subtitle: String
    
    let details: String
    
    let icon: UIImage?
    
    let iconViewModel: WalletImageViewModelProtocol?
}

extension WalletTokenViewModel: WalletFormViewBindingProtocol {
    func accept(definition: WalletFormDefining) -> WalletFormItemView? {
        if let definition = definition as? WalletSoraFormDefining {
            return definition.defineViewForSoraTokenViewModel(self)
        } else {
            return nil
        }
    }
}

struct WalletSoraReceiverViewModel: MultilineTitleIconViewModelProtocol {
    var text: String
    
    var icon: UIImage?
    
    var title: String
    
    var command: WalletCommandProtocol?
    
}

extension WalletSoraReceiverViewModel: WalletFormViewBindingProtocol {
    func accept(definition: WalletFormDefining) -> WalletFormItemView? {
        if let definition = definition as? WalletSoraFormDefining {
            return definition.defineViewForSoraReceiverViewModel(self)
        } else if let definition = definition as? WalletTransactionDetailsDefining {
            return definition.defineViewForSoraReceiverViewModel(self)
        } else {
            return nil
        }
    }
}

extension FeeViewModel: WalletFormViewBindingProtocol {
    public func accept(definition: WalletFormDefining) -> WalletFormItemView? {
        if let definition = definition as? WalletSoraFormDefining {
            return definition.defineViewForFeeViewModel(self)
        } else if let definition = definition as? WalletTransactionDetailsDefining {
            return definition.defineViewForFeeViewModel(self)
        } else {
            return nil
        }
    }
}

struct SoraTransactionHeaderViewModel: WalletFormViewBindingProtocol {
    let title: String
    let details: String
    let direction: TransactionType?
    
    public func accept(definition: WalletFormDefining) -> WalletFormItemView? {
        if let definition = definition as? WalletTransactionDetailsDefining {
            return definition.defineViewForHeader(self)
        } else {
            return nil
        }
    }
}

struct SoraSwapHeaderViewModel: WalletFormViewBindingProtocol {
    let sourceAsset: WalletTokenViewModel
    let targetAsset: WalletTokenViewModel
    let estimate: String
    
    
    public func accept(definition: WalletFormDefining) -> WalletFormItemView? {
        if let definition = definition as? WalletSoraFormDefining {
            return definition.defineViewForSwapConfirmationHeaderViewModel(self)
        } else {
            return nil
        }
    }
}

struct SoraTransactionStatusViewModel: WalletFormViewBindingProtocol {
    public let title: String
    public let titleIcon: UIImage?
    public let details: String?
    public let detailsIcon: UIImage?
    
    public init(title: String,
                titleIcon: UIImage? = nil,
                details: String? = nil,
                detailsIcon: UIImage? = nil) {
        self.title = title
        self.titleIcon = titleIcon
        self.details = details
        self.detailsIcon = detailsIcon
    }
    
    public func accept(definition: WalletFormDefining) -> WalletFormItemView? {
        if let definition = definition as? WalletTransactionDetailsDefining {
            return definition.defineViewForStatus(self)
        } else {
            return nil
        }
    }
    
}

struct SoraTransactionAmountViewModel: WalletFormViewBindingProtocol {
    func accept(definition: WalletFormDefining) -> WalletFormItemView? {
        if let definition = definition as? WalletTransactionDetailsDefining {
            return definition.defineViewForAmountModel(self)
        } else {
            return nil
        }
    }
    
    let title: String
    let details: String
}

struct AddLiquidityViewModel: WalletFormViewBindingProtocol {
    let firstAsset: AssetInfo
    let firstAssetValue: String
    let secondAsset: AssetInfo
    let secondAssetValue: String
    let shareOfPoolValue: Decimal
    let directExchangeRateTitle: String
    let directExchangeRateValue: String
    let inversedExchangeRateTitle: String
    let inversedExchangeRateValue: String
    let sbApyValue: Decimal
    let networkFeeValue: Decimal
    let slippage: String
    
    init(
        firstAsset: AssetInfo,
        firstAssetValue: String,
        secondAsset: AssetInfo,
        secondAssetValue: String,
        shareOfPoolValue: Decimal,
        directExchangeRateTitle: String,
        directExchangeRateValue: String,
        inversedExchangeRateTitle: String,
        inversedExchangeRateValue: String,
        sbApyValue: Decimal,
        networkFeeValue: Decimal,
        slippage: String
    ) {
        self.firstAsset = firstAsset
        self.firstAssetValue = firstAssetValue
        self.secondAsset = secondAsset
        self.secondAssetValue = secondAssetValue
        self.shareOfPoolValue = shareOfPoolValue
        self.directExchangeRateTitle = directExchangeRateTitle
        self.directExchangeRateValue = directExchangeRateValue
        self.inversedExchangeRateTitle = inversedExchangeRateTitle
        self.inversedExchangeRateValue = inversedExchangeRateValue
        self.sbApyValue = sbApyValue
        self.networkFeeValue = networkFeeValue
        self.slippage = slippage
    }
    
    func accept(definition: WalletFormDefining) -> WalletFormItemView? {
        if let definition = definition as? WalletSoraFormDefining {
            return definition.defineViewForAddLiquidityViewModel(self)
        } else {
            return nil
        }
    }
    
    
}
