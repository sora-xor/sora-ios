/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet
import SoraFoundation

struct WalletConfirmationConfigurator {
    let amountFormatterFactory: NumberFormatterFactoryProtocol
    let feeDisplayFactory: FeeDisplaySettingsFactoryProtocol
    let xorAsset: WalletAsset
    let valAsset: WalletAsset
    let ethAsset: WalletAsset

    init(amountFormatterFactory: NumberFormatterFactoryProtocol,
         feeDisplayFactory: FeeDisplaySettingsFactoryProtocol,
         xorAsset: WalletAsset,
         valAsset: WalletAsset,
         ethAsset: WalletAsset) {
        self.amountFormatterFactory = amountFormatterFactory
        self.feeDisplayFactory = feeDisplayFactory
        self.xorAsset = xorAsset
        self.valAsset = valAsset
        self.ethAsset = ethAsset
    }

    var generatingIconStyle: WalletNameIconStyleProtocol {
        let textStyle = WalletTextStyle(font: R.font.soraRc0040417Regular(size: 12)!,
                                        color: UIColor(red: 0.379, green: 0.379, blue: 0.379, alpha: 1))
        return WalletNameIconStyle(background: .white,
                                   title: textStyle,
                                   radius: 12.0)
    }

    func configure(using builder: TransferConfirmationModuleBuilderProtocol) {
        let viewModelFactory = WalletConfirmationViewModelFactory(amountFormatterFactory: amountFormatterFactory,
                                                                  feeDisplayFactory: feeDisplayFactory,
                                                                  generatingIconStyle: generatingIconStyle,
                                                                  xorAsset: xorAsset,
                                                                  valAsset: valAsset,
                                                                  ethAsset: ethAsset)

        let localizableTitle: LocalizableResource<String> = LocalizableResource { locale in
            R.string.localizable.transactionConfirm(preferredLanguages: locale.rLanguages)
        }

        builder
            .with(completion: .hide)
            .with(accessoryViewType: .onlyActionBar)
            .with(viewModelFactoryOverriding: viewModelFactory)
            .with(viewBinder: WalletConfirmationViewBinder())
            .with(localizableTitle: localizableTitle)
    }
}
