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

import UIKit
import SoraUIKit
import CommonWallet
import BigInt
import Combine

final class ViewAssetListViewModel {

    var setupNavigationBar: ((UIBarButtonItem?) -> Void)?
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?

    var assetItems: [ExploreAssetListItem] = [] {
        didSet {
            setupItems?(assetItems)
        }
    }

    var filteredAssetItems: [ExploreAssetListItem] = [] {
        didSet {
            setupItems?(filteredAssetItems)
        }
    }

    var isActiveSearch: Bool = false {
        didSet {
            setupItems?(isActiveSearch ? filteredAssetItems : assetItems)
        }
    }

    var searchText: String = "" {
        didSet {
            guard !searchText.isEmpty else {
                setupItems?(assetItems)
                return
            }
            filterAssetList(with: searchText.lowercased())
        }
    }

    weak var view: UIViewController?
    weak var viewModelService: ExploreAssetViewModelService?
    private var wireframe: ExploreWireframeProtocol?
    private var cancellables: Set<AnyCancellable> = []

    init(viewModelService: ExploreAssetViewModelService,
         wireframe: ExploreWireframeProtocol?) {
        self.viewModelService = viewModelService
        self.wireframe = wireframe
    }
}

extension ViewAssetListViewModel: Explorable {
    var navigationTitle: String {
        R.string.localizable.commonCurrencies(preferredLanguages: .currentLocale)
    }
    
    var searchBarPlaceholder: String {
        R.string.localizable.assetListSearchPlaceholder(preferredLanguages: .currentLocale)
    }
    
    func viewDidLoad() {
        setupNavigationBar?(nil)
        setupSubscription()
    }
}

private extension ViewAssetListViewModel {
    
    func setupSubscription() {
        viewModelService?.$viewModels
            .receive(on: DispatchQueue.main)
            .sink { [weak self] value in
                let items = value.map { viewModel in
                    let item = ExploreAssetListItem(viewModel: viewModel)
                    item.assetHandler = { [weak self] assetId in
                        self?.wireframe?.showAssetDetails(on: self?.view, assetId: assetId ?? "")
                    }
                    return item
                }
                self?.assetItems = items
            }
            .store(in: &cancellables)
    }

    func filterAssetList(with query: String) {
        filteredAssetItems = assetItems.filter { item in
            return (item.viewModel.assetId?.lowercased().contains(query) ?? false) ||
            (item.viewModel.symbol?.lowercased().contains(query) ?? false) ||
            (item.viewModel.title?.lowercased().contains(query) ?? false)
        }
    }
}
