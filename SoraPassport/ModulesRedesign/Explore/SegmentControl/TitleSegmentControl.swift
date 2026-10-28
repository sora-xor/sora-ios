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

import Foundation
import SoraUIKit
import Combine

class TitleSegmentControl: SoramitsuView {
    
    var viewModel: TitleSegmentControlViewModel? {
        didSet {
            setupSubscriptions()
            viewModel?.setup()
        }
    }
    
    private var cancellables: Set<AnyCancellable> = []
    
    private lazy var dataSource: TitleSegmentControlDataSource = {
        TitleSegmentControlDataSource(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .segment(let item):
                let cell: SegmentCell? = collectionView.dequeueReusableCell(withReuseIdentifier: "SegmentCell",
                                                                            for: indexPath) as? SegmentCell
                cell?.set(item: item)
                return cell ?? UICollectionViewCell()
            }
        }
    }()
    
    lazy var collectionView: UICollectionView = {
        var collectionViewFlowControl = UICollectionViewFlowLayout()
        collectionViewFlowControl.scrollDirection = .horizontal
        collectionViewFlowControl.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        
        let view = UICollectionView(frame: .zero, collectionViewLayout: collectionViewFlowControl)
        view.showsVerticalScrollIndicator = false
        view.showsHorizontalScrollIndicator = false
        view.backgroundColor = .clear
        view.decelerationRate = .fast
        view.translatesAutoresizingMaskIntoConstraints = false
        view.delegate = self
        view.register(SegmentCell.self, forCellWithReuseIdentifier: "SegmentCell")
        return view
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()
    }
    
    // MARK: - Private methods

    private func setupLayout() {
        translatesAutoresizingMaskIntoConstraints = false
        addSubview(collectionView)
        
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor),
            collectionView.centerXAnchor.constraint(equalTo: centerXAnchor),
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

extension TitleSegmentControl: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else {
            return
        }
        
        switch item {
        case .segment(let item):
            viewModel?.didSelect(number: item.tab.rawValue)
        default: break
        }
    }
}
