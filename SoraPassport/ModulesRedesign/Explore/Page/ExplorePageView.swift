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
        cancellables.removeAll()
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
