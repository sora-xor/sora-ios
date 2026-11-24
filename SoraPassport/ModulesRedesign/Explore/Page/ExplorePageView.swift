// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

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
            
            let needsHeaders = viewModel?.isNeedHeaders == true
            tableView.sectionHeaderHeight = needsHeaders ? UITableView.automaticDimension : 0
            tableView.contentInset = UIEdgeInsets(top: needsHeaders ? 0 : 16, left: 0, bottom: 16, right: 0)
        }
    }
    
    private var loadingDeadline: DispatchWorkItem?
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
    
    private let emptyIcon: UIImageView = {
        let icon = UIImageView(image: UIImage(systemName: "magnifyingglass", withConfiguration: UIImage.SymbolConfiguration(pointSize: 30, weight: .light)))
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.tintColor = Lit.lacquerText
        icon.isHidden = true
        icon.isAccessibilityElement = false
        return icon
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
        addSubview(emptyIcon)
        addSubview(emptyListLabel)
        
        NSLayoutConstraint.activate([
            // The list is a card in the content column: 16 points from the sides on a phone, the readable
            // width in a wider window (on an iPad it ran from edge to edge, its rows in the middle of it).
            // A page is as wide as its screen, so its own column guide is the screen's.
            tableView.leadingAnchor.constraint(equalTo: litColumnGuide.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: litColumnGuide.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: topAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            emptyIcon.centerXAnchor.constraint(equalTo: emptyListLabel.centerXAnchor),
            emptyIcon.bottomAnchor.constraint(equalTo: emptyListLabel.topAnchor, constant: -12),
            emptyListLabel.leadingAnchor.constraint(equalTo: litColumnGuide.leadingAnchor),
            emptyListLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            emptyListLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
    
    private func setupSubscriptions() {
        cancellables.removeAll()
        viewModel?.snapshotPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                guard let self else { return }
                self.loadingDeadline?.cancel()
                self.emptyListLabel.sora.text = R.string.localizable.commonNothingFound(preferredLanguages: .currentLocale)
                self.emptyListLabel.isHidden = snapshot.numberOfItems != 0
                self.emptyIcon.isHidden = self.emptyListLabel.isHidden
                let pending = snapshot.numberOfItems > 0 && snapshot.itemIdentifiers.allSatisfy { item in
                    switch item {
                    case .asset(let row): return row.assetViewModel.assetId == nil
                    case .pool(let row): return row.poolViewModel.poolId == nil
                    case .farm(let row): return row.farmViewModel.farmId == nil
                    case .header: return false
                    }
                }
                var visible = snapshot
                if pending {
                    visible.deleteItems(Array(snapshot.itemIdentifiers.dropFirst(3)))
                    if !LitMotion.allowed {
                        visible = ExplorePageSnapshot()
                        self.emptyListLabel.sora.text = R.string.localizable.loading(preferredLanguages: .currentLocale)
                        self.emptyListLabel.isHidden = false
                    }
                }
                self.dataSource.apply(visible, animatingDifferences: false)
                guard pending else { return }
                let deadline = DispatchWorkItem { [weak self] in
                    self?.dataSource.apply(ExplorePageSnapshot(), animatingDifferences: false)
                    self?.emptyListLabel.sora.text = R.string.localizable.commonErrorNotFoundTitle(preferredLanguages: .currentLocale)
                    self?.emptyListLabel.isHidden = false
                }
                self.loadingDeadline = deadline
                DispatchQueue.main.asyncAfter(deadline: .now() + 12, execute: deadline)
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
        let snapshot = dataSource.snapshot()
        guard viewModel?.isNeedHeaders == true,
              snapshot.sectionIdentifiers.indices.contains(section),
              let first = snapshot.itemIdentifiers(inSection: snapshot.sectionIdentifiers[section]).first else { return nil }
        let type: ExploreItemType
        switch first {
        case .asset: type = .assets
        case .pool: type = .pools
        case .farm: type = .farms
        case .header: return nil
        }
        let title = type.title
        let cell = tableView.dequeueReusableHeaderFooterView(withIdentifier: ExploreSectionHeader.reuseIdentifier) as? ExploreSectionHeader
        cell?.configure(with: title)
        return cell
    }
}
