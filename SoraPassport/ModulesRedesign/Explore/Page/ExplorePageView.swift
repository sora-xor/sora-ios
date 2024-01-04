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

import SoraUIKit
import SnapKit
import Combine

enum ExploreItemType: Int, CaseIterable {
    case assets = 0
    case pools
    case farms
    
    var title: String {
        switch self {
        case .assets:
            return R.string.localizable.commonAssets(preferredLanguages: .currentLocale)
        case .pools:
            return R.string.localizable.commonPools(preferredLanguages: .currentLocale)
        case .farms:
            return R.string.localizable.commonFarms(preferredLanguages: .currentLocale)
        }
    }
}

final class ExplorePageView: SoramitsuView {

    public var viewModel: ExplorePageViewModelProtocol? {
        didSet {
            setupSubscriptions()
            viewModel?.setup()
            
            var topInset: CGFloat = 16
            
            if let viewModel, viewModel.isNeedHeaders {
                topInset = !viewModel.isNeedHeaders ? 16 : 0
            } else {
                tableView.sectionHeaderHeight = 0
            }
            
            tableView.contentInset = UIEdgeInsets(top: topInset, left: 0, bottom: 16, right: 0)
        }
    }
    
    private var cancellables: Set<AnyCancellable> = []
    
    private lazy var dataSource: ExplorePageDataSource = {
        ExplorePageDataSource(tableView: tableView) { tableView, indexPath, item in
            switch item {
            case .header(let item):
                let cell: HeaderCell? = tableView.dequeueReusableCell(withIdentifier: "HeaderCell",
                                                                            for: indexPath) as? HeaderCell
                cell?.set(item: item)
                return cell ?? UITableViewCell()
            case .asset(let item):
                let cell: ExploreAssetCell? = tableView.dequeueReusableCell(withIdentifier: "ExploreAssetCell",
                                                                            for: indexPath) as? ExploreAssetCell
                cell?.set(item: item)
                return cell ?? UITableViewCell()
            case .pool(let item):
                let cell: ExplorePoolCell? = tableView.dequeueReusableCell(withIdentifier: "ExplorePoolCell",
                                                                            for: indexPath) as? ExplorePoolCell
                cell?.set(item: item)
                return cell ?? UITableViewCell()
            case .farm(let item):
                let cell: ExploreFarmCell? = tableView.dequeueReusableCell(withIdentifier: "ExploreFarmCell",
                                                                            for: indexPath) as? ExploreFarmCell
                cell?.set(item: item)
                return cell ?? UITableViewCell()
            }
        }
    }()
    
    public lazy var tableView: SoramitsuTableView = {
        let tableView = SoramitsuTableView()
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.keyboardDismissMode = .onDrag
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.sora.estimatedRowHeight = UITableView.automaticDimension
        tableView.register(HeaderCell.self, forCellReuseIdentifier: "HeaderCell")
        tableView.register(ExploreAssetCell.self, forCellReuseIdentifier: "ExploreAssetCell")
        tableView.register(ExplorePoolCell.self, forCellReuseIdentifier: "ExplorePoolCell")
        tableView.register(ExploreFarmCell.self, forCellReuseIdentifier: "ExploreFarmCell")
        tableView.register(ExploreSectionHeader.self, forHeaderFooterViewReuseIdentifier: "ExploreSectionHeader")
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.tableFooterView = nil
        tableView.sora.cornerMask = .top
        tableView.sora.cornerRadius = .extraLarge
        tableView.sora.backgroundColor = .bgSurface
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        return tableView
    }()
    
    let emptyListLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.numberOfLines = 0
        label.sora.alignment = .center
        label.sora.font = FontType.paragraphM
        label.sora.textColor = .fgSecondary
        label.sora.text = R.string.localizable.commonNothingFound(preferredLanguages: .currentLocale)
        return label
    }()

    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        setupSubviews()
    }

    private func setupSubviews() {
        addSubview(tableView)
        addSubview(emptyListLabel)
        
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            tableView.topAnchor.constraint(equalTo: topAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor),
            tableView.centerXAnchor.constraint(equalTo: centerXAnchor),
            tableView.heightAnchor.constraint(equalTo: heightAnchor),
            
            emptyListLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            emptyListLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            emptyListLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
    
    private func setupSubscriptions() {
        viewModel?.snapshotPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                UIView.performWithoutAnimation {
                    self?.emptyListLabel.isHidden = snapshot.numberOfSections != 0
                    self?.dataSource.apply(snapshot, animatingDifferences: false)
                }
            }
            .store(in: &cancellables)
    }
}

extension ExplorePageView: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        viewModel?.didSelect(with: item)
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let title = ExploreItemType.allCases[section].title
        let cell = tableView.dequeueReusableHeaderFooterView(withIdentifier: ExploreSectionHeader.reuseIdentifier) as? ExploreSectionHeader
        cell?.configure(with: title)
        return cell
    }
}
