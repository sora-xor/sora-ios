//
//  ExplorePageView.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 12/3/23.
//  Copyright © 2023 Soramitsu. All rights reserved.
//

import SoraUIKit
import SnapKit
import Combine

final class ExplorePageView: SoramitsuView {

    public var viewModel: ExplorePageViewModelProtocol? {
        didSet {
            setupSubscriptions()
            viewModel?.setup()
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
        tableView.sectionHeaderHeight = .zero
        tableView.contentInset = UIEdgeInsets(top: 16, left: 0, bottom: 16, right: 0)
        tableView.sora.cornerMask = .all
        tableView.sora.cornerRadius = .extraLarge
        tableView.sora.backgroundColor = .bgSurface
        return tableView
    }()

    override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        setupSubviews()
    }

    private func setupSubviews() {
        addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            tableView.topAnchor.constraint(equalTo: topAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor),
            tableView.centerXAnchor.constraint(equalTo: centerXAnchor),
            tableView.heightAnchor.constraint(equalTo: heightAnchor),
        ])
    }
    
    private func setupSubscriptions() {
        viewModel?.snapshotPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.dataSource.apply(snapshot, animatingDifferences: false)
            }
            .store(in: &cancellables)
    }
}

extension ExplorePageView: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else {
            return
        }
        
        switch item {
        case .asset(let item):
            viewModel?.didSelect(with: item.assetViewModel.assetId)
        case .pool(let item):
            viewModel?.didSelect(with: item.poolViewModel)
        case .farm(let item):
            viewModel?.didSelect(with: item.farmViewModel.farmId)
        default: break
        }
    }
}
