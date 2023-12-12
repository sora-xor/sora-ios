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
import UIKit
import SoraUIKit
import Combine

protocol LiquidityViewProtocol: ControllerBackedProtocol {}

final class PolkaswapViewController: SoramitsuViewController, LiquidityViewProtocol {
    private lazy var accessoryView: InputAccessoryView = {
//        let rect = CGRect(origin: .zero, size: CGSize(width: UIScreen.main.bounds.width, height: 48))
        let view = InputAccessoryView(frame: .zero)
        view.delegate = viewModel
        view.variants = [ InputAccessoryVariant(displayValue: "25%", value: 0.25),
                          InputAccessoryVariant(displayValue: "50%", value: 0.5),
                          InputAccessoryVariant(displayValue: "75%", value: 0.75),
                          InputAccessoryVariant(displayValue: "100%", value: 1) ]
        return view
    }()
    
    private lazy var tableView: SoramitsuTableView = {
        let tableView = SoramitsuTableView()
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = SoramitsuUI.shared.theme.palette.color(.custom(uiColor: .clear))
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.sectionHeaderHeight = .zero
        tableView.estimatedRowHeight = UITableView.automaticDimension
        tableView.register(PolkaswapCell.self, forCellReuseIdentifier: "PolkaswapCell")
        tableView.register(SoramitsuCell<SoramitsuTableViewSpaceView>.self, forCellReuseIdentifier: "SpaceCell")
        tableView.register(SwapDetailsCell.self, forCellReuseIdentifier: "SwapDetailsCell")
        tableView.sora.cancelsTouchesOnDragging = true
        return tableView
    }()

    private var cancellables: Set<AnyCancellable> = []
    var viewModel: LiquidityViewModelProtocol {
        didSet {
            setupSubscription()
        }
    }
    
    private lazy var dataSource: PolkaswapDataSource = {
        PolkaswapDataSource(tableView: tableView) { tableView, indexPath, item in
            switch item {
            case .polkaswap(let item):
                let cell: PolkaswapCell? = tableView.dequeueReusableCell(withIdentifier: "PolkaswapCell", for: indexPath) as? PolkaswapCell
                cell?.set(item: item, context: nil)
                return cell ?? UITableViewCell()
            case .space(let item):
                let cell: SoramitsuCell<SoramitsuTableViewSpaceView>? = tableView.dequeueReusableCell(withIdentifier: "SpaceCell",
                                                                                                      for: indexPath) as? SoramitsuCell<SoramitsuTableViewSpaceView>
                cell?.set(item: item, context: nil)
                return cell ?? UITableViewCell()
            case .details(let item):
                let cell: SwapDetailsCell? = tableView.dequeueReusableCell(withIdentifier: "SwapDetailsCell", for: indexPath) as? SwapDetailsCell
                cell?.set(item: item, context: nil)
                return cell ?? UITableViewCell()
            }
        }
    }()

    init(viewModel: LiquidityViewModelProtocol) {
        self.viewModel = viewModel
        super.init()
        setupSubscription()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        setupConstraints()
        
        if let imageName = viewModel.imageName {
            let logo = UIImage(named: imageName)
            let imageView = UIImageView(image: logo)
            navigationItem.titleView = imageView
        }
        
        if let title = viewModel.title {
            navigationItem.title = title
        }

        addCloseButton()
        
        if !viewModel.isSwap {
            navigationItem.leftBarButtonItem = UIBarButtonItem(image: R.image.wallet.info24(),
                                                               style: .plain,
                                                               target: self,
                                                               action: #selector(infoTapped))
            navigationItem.leftBarButtonItem?.tintColor = SoramitsuUI.shared.theme.palette.color(.fgSecondary)
        }

        viewModel.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.viewWillAppear()
    }
    
    private func setupSubscription() {
        viewModel.snapshotPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.dataSource.apply(snapshot, animatingDifferences: false)
            }
            .store(in: &cancellables)
        
        
        viewModel.isAccessoryViewHiddenPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isHidden in
                self?.accessoryView.sora.isHidden = isHidden
            }
            .store(in: &cancellables)
    }
    
    @objc
    func infoTapped() {
        viewModel.infoButtonTapped()
    }

    private func setupView() {
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        view.addSubview(tableView)
        view.addSubview(accessoryView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            accessoryView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            accessoryView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            accessoryView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            accessoryView.heightAnchor.constraint(equalToConstant: 48),
        ])
    }
}

extension PolkaswapViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let item = dataSource.itemIdentifier(for: indexPath) else {
            return UITableView.automaticDimension
        }
        
        switch item {
        case .space: return 16
        default: return UITableView.automaticDimension
        }
    }
}
