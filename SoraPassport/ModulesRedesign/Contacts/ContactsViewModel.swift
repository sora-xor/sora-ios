// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation
import IrohaCrypto
import RobinHood
import SoraFoundation
import CommonWallet
import SoraUIKit

public struct ContactModuleParameters {
    public let accountId: String
    public let assetId: String
}

protocol ContactsViewModelProtocol {
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)? { get set }
    func viewDidLoad()
    func search(_ pattern: String)
    func openQR()
}

final class ContactsViewModel: NSObject {
    
    private struct Constants {
        static let inputSearchDelay: Double = 0.5
    }
    
    weak var view: ContactsViewProtocol?
    
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)?

    private let wireframe: ContactsWireframeProtocol
    private let networkFacade: WalletNetworkOperationFactoryProtocol
    private let assetManager: AssetManagerProtocol
    private let dataProvider: SingleValueProvider<[SearchData]>
    private let walletService: WalletServiceProtocol
    private let localSearchEngine: ContactsLocalSearchEngineProtocol?
    private let settingsManager: SelectedWalletSettingsProtocol
    private let qrEncoder: WalletQREncoderProtocol
    private let sharingFactory: AccountShareFactoryProtocol
    private let assetsProvider: AssetProviderProtocol?
    private let providerFactory: BalanceProviderFactory
    private let feeProvider: FeeProviderProtocol

    private let assetId: String

    private var searchPattern = ""

    private var searchOperation: CancellableCall?
    private var isWaitingSearch: Bool = false
    var completion: ((ScanQRResult) -> Void)?
    
    var recentContantsItems: [SoramitsuTableViewItemProtocol] = []
    
    deinit {
        cancelSearch()
    }

    init(dataProvider: SingleValueProvider<[SearchData]>,
         walletService: WalletServiceProtocol,
         assetId: String,
         localSearchEngine: ContactsLocalSearchEngineProtocol?,
         wireframe: ContactsWireframeProtocol,
         networkFacade: WalletNetworkOperationFactoryProtocol,
         assetManager: AssetManagerProtocol,
         settingsManager: SelectedWalletSettingsProtocol,
         qrEncoder: WalletQREncoderProtocol,
         sharingFactory: AccountShareFactoryProtocol,
         assetsProvider: AssetProviderProtocol?,
         providerFactory: BalanceProviderFactory,
         feeProvider: FeeProviderProtocol
    ) {
        self.dataProvider = dataProvider
        self.walletService = walletService
        self.assetId = assetId
        self.localSearchEngine = localSearchEngine
        self.wireframe = wireframe
        self.networkFacade = networkFacade
        self.assetManager = assetManager
        self.settingsManager = settingsManager
        self.qrEncoder = qrEncoder
        self.sharingFactory = sharingFactory
        self.assetsProvider = assetsProvider
        self.providerFactory = providerFactory
        self.feeProvider = feeProvider
    }
    

    private func setupDataProvider() {
        let changesBlock = { [weak self] (changes: [DataProviderChange<[SearchData]>]) -> Void in
            if let change = changes.first {
                switch change {
                case .insert(let items), .update(let items):
                    self?.handleContacts(with: items)
                default:
                    break
                }
            } else {
                self?.handleContacts(with: nil)
            }
        }
        
        dataProvider.addObserver(self,
                                 deliverOn: .main,
                                 executing: changesBlock,
                                 failing: { _ in },
                                 options: DataProviderObserverOptions(alwaysNotifyOnRefresh: true))
    }
    
    private func handleContacts(with updatedContacts: [SearchData]?) {
        guard let contacts = updatedContacts else {
            return
        }
        
        recentContantsItems = [ ContactHeaderCellItem(title: R.string.localizable.recentRecipients(preferredLanguages: .currentLocale).uppercased()) ]
        recentContantsItems.append(contentsOf:
                                    contacts.map { contact in
            ContactCellItem(title: contact.firstName, onTap: { [weak self] in
                guard contact.firstName != self?.settingsManager.currentAccount?.address else {
                    self?.view?.show(error: R.string.localizable.invoiceScanErrorMatch(preferredLanguages: .currentLocale))
                    return
                }
                self?.view?.controller.dismiss(animated: true, completion: { [weak self] in
                    self?.completion?(ScanQRResult(firstName: contact.firstName))
                })
            })
        })
        recentContantsItems.append(ContactFooterItem())
        
        setupItems?(recentContantsItems)
    }

    private func handleSearch(with foundData: [SearchData]) {
        let filtered: [SearchData]

        filtered = foundData.filter { $0.accountId != settingsManager.currentAccount?.address }

        if filtered.isEmpty {
            setupItems?(recentContantsItems)
            return
        }
        
        let headerTitle = R.string.localizable.contactsSearchResults(preferredLanguages: .currentLocale).uppercased()
        var cellItems: [SoramitsuTableViewItemProtocol] = [ ContactHeaderCellItem(title: headerTitle) ]
        cellItems.append(contentsOf:
                            filtered.map { contact in
            ContactCellItem(title: contact.firstName, onTap: { [weak self] in
                guard contact.firstName != self?.settingsManager.currentAccount?.address else {
                    self?.view?.show(error: R.string.localizable.invoiceScanErrorMatch(preferredLanguages: .currentLocale))
                    return
                }
                self?.view?.controller.dismiss(animated: true, completion: { [weak self] in
                    self?.completion?(ScanQRResult(firstName: contact.firstName))
                })
            })
        })
        cellItems.append(ContactFooterItem())
        setupItems?(cellItems)
    }
    
    private func cancelSearch() {
        if isWaitingSearch {

            NSObject.cancelPreviousPerformRequests(withTarget: self,
                                                   selector: #selector(performSearch),
                                                   object: nil)
            isWaitingSearch = false
        }

        searchOperation?.cancel()
        searchOperation = nil
    }
    
    private func scheduleSearch() {
        searchOperation?.cancel()
        searchOperation = nil

        let accountId = try? SS58AddressFactory().accountId(from: settingsManager.currentAccount?.identifier ?? "").toHex(includePrefix: true)
        let parameters = ContactModuleParameters(accountId: accountId ?? "",
                                                 assetId: assetId)

        if let localSearchResults = localSearchEngine?.search(query: searchPattern,
                                                              parameters: parameters,
                                                              locale: Locale.current,
                                                              delegate: self) {
            if isWaitingSearch {
                cancelSearch()
            }

            let headerTitle = R.string.localizable.contactsSearchResults(preferredLanguages: .currentLocale).uppercased()
            var cellItems: [SoramitsuTableViewItemProtocol] = [ ContactHeaderCellItem(title: headerTitle) ]
            cellItems.append(contentsOf:
                                localSearchResults.map { contact in
                ContactCellItem(title: contact.firstName, onTap: { [weak self] in
                    self?.view?.controller.dismiss(animated: true, completion: { [weak self] in
                        self?.completion?(ScanQRResult(firstName: contact.firstName))
                    })
                })
            })
            cellItems.append(ContactFooterItem())
            setupItems?(cellItems)

            return
        }

        if !isWaitingSearch {

            isWaitingSearch = true

            self.perform(#selector(performSearch), with: nil, afterDelay: Constants.inputSearchDelay)
        }
    }
    
    @objc private func performSearch() {
        isWaitingSearch = false

        searchOperation = walletService.search(for: searchPattern, runCompletionIn: .main) { [weak self] (result) in

            guard let strongSelf = self else {
                return
            }

            if !strongSelf.isWaitingSearch {}

            if let result = result {
                self?.searchOperation = nil

                switch result {
                case .success(let contacts):
                    let loadedContacts = contacts ?? []
                    strongSelf.handleSearch(with: loadedContacts)
                case .failure(let error):
                    strongSelf.handleSearchError(error)
                }
            }
        }
    }

    private func handleSearchError(_ error: Error) {
    }
}


extension ContactsViewModel: ContactsViewModelProtocol {
    
    func viewDidLoad() {
        setupDataProvider()
    }
    
    func search(_ pattern: String) {
        searchPattern = pattern
        
        guard !pattern.isEmpty else {
            cancelSearch()
            return
        }

        scheduleSearch()
    }
    
    func openQR() {
        wireframe.showScanQR(on: view?.controller,
                             networkFacade: networkFacade,
                             assetManager: assetManager,
                             qrEncoder: qrEncoder,
                             sharingFactory: sharingFactory,
                             assetsProvider: assetsProvider,
                             providerFactory: providerFactory,
                             feeProvider: feeProvider,
                             completion: { [weak self] result in
            guard result.firstName != self?.settingsManager.currentAccount?.address else {
                self?.view?.show(error: R.string.localizable.invoiceScanErrorMatch(preferredLanguages: .currentLocale))
                return
            }
            
            self?.view?.controller.dismiss(animated: true, completion: { [weak self] in
                self?.completion?(result)
            })
        })
    }
}

extension ContactsViewModel: ContactViewModelDelegate {
    
    func didSelect(contact: ContactViewModelProtocol) {
        let receiveInfo = ReceiveInfo(accountId: contact.accountId,
                                      assetId: assetId,
                                      amount: nil,
                                      details: nil)

        let payload = TransferPayload(receiveInfo: receiveInfo,
                                      receiverName: contact.name)

    }
    
}
