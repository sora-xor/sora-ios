/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet
import RobinHood

enum ConfigurableAssetStatus {
    case initial
    case inProgress
    case completed
    case failed

    init(sidechainState: SidechainInitState) {
        switch sidechainState {
        case .needsRegister, .inProgress, .needsUpdatePending:
            self = .inProgress
        case .completed:
            self = .completed
        case .failed:
            self = .failed
        }
    }
}

protocol AssetDetailsFactoryProtocol {
    func createDetailsForStatus(_ status: ConfigurableAssetStatus) -> String
}

struct AssetDetailsStatusFactory: AssetDetailsFactoryProtocol {
    let completedDetails: String
    let locale: Locale

    func createDetailsForStatus(_ status: ConfigurableAssetStatus) -> String {
        switch status {
        case .completed, .initial:
            return completedDetails
        case .failed:
            return R.string.localizable.assetStateError(preferredLanguages: locale.rLanguages)
        case .inProgress:
            return R.string.localizable.assetStateAssociating(preferredLanguages: locale.rLanguages)
        }
    }
}

protocol ConfigurableAssetViewModelDelegate: class {
    func viewModelDidChangeStatus(_ viewModel: ConfigurableAssetViewModelProtocol,
                                  oldStatus: ConfigurableAssetStatus)
}

protocol ConfigurableAssetViewModelProtocol: AssetViewModelProtocol {
    var status: ConfigurableAssetStatus { get }
    var delegate: ConfigurableAssetViewModelDelegate? { get set }
}

struct ConfigurableAssetConstants {
    static let cellReuseIdentifier = "co.jp.sora.asset.cell.identifier"
    static let cellHeight: CGFloat = 95.0
}

final class ConfigurableAssetViewModel<T: Codable>: ConfigurableAssetViewModelProtocol {
    var cellReuseIdentifier: String { ConfigurableAssetConstants.cellReuseIdentifier }
    var itemHeight: CGFloat { ConfigurableAssetConstants.cellHeight }
    let assetId: String
    let amount: String
    let symbol: String?

    var details: String { detailsFactory.createDetailsForStatus(status) }

    let accessoryDetails: String?
    let imageViewModel: WalletImageViewModelProtocol?
    let style: AssetCellStyle
    let command: WalletCommandProtocol?
    let dataProvider: StreamableProvider<SidechainInit<T>>
    let detailsFactory: AssetDetailsFactoryProtocol

    weak var delegate: ConfigurableAssetViewModelDelegate?

    private(set) var status: ConfigurableAssetStatus = .initial {
        didSet {
            delegate?.viewModelDidChangeStatus(self, oldStatus: oldValue)
        }
    }

    init(assetId: String,
         dataProvider: StreamableProvider<SidechainInit<T>>,
         amount: String,
         symbol: String?,
         detailsFactory: AssetDetailsFactoryProtocol,
         accessoryDetails: String?,
         imageViewModel: WalletImageViewModelProtocol?,
         style: AssetCellStyle,
         command: WalletCommandProtocol?) {
        self.assetId = assetId
        self.dataProvider = dataProvider
        self.amount = amount
        self.symbol = symbol
        self.detailsFactory = detailsFactory
        self.accessoryDetails = accessoryDetails
        self.imageViewModel = imageViewModel
        self.style = style
        self.command = command

        configureDataProvider()
    }

    // MARK: Private

    private func configureDataProvider() {
        let changes: ([DataProviderChange<SidechainInit<T>>]) -> Void = { [weak self] changes in
            for change in changes {
                switch change {
                case .insert(let newItem), .update(let newItem):
                    self?.status = ConfigurableAssetStatus(sidechainState: newItem.state)
                case .delete:
                    self?.status = .initial
                }
            }
        }

        let options = StreamableProviderObserverOptions(alwaysNotifyOnRefresh: false,
                                                        waitsInProgressSyncOnAdd: false,
                                                        refreshWhenEmpty: false)

        dataProvider.addObserver(self, deliverOn: .main,
                                 executing: changes,
                                 failing: { _ in },
                                 options: options)
    }
}
