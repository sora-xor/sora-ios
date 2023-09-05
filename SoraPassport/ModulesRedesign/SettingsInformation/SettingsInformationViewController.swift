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
import Anchorage

protocol SettingsInformationViewProtocol: ControllerBackedProtocol {
    var presenter: SettingsInformationPresenterProtocol? { get set }
    
    func set(title: String)
    func update(snapshot: SettingsInformationSnapshot)
}

final class SettingsInformationViewController: SoramitsuViewController & SettingsInformationViewProtocol {
    var presenter: SettingsInformationPresenterProtocol?
    
    private lazy var dataSource: SettingsInformationDataSource = {
        SettingsInformationDataSource(tableView: tableView) { tableView, indexPath, item in
            let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsInformationCell", for: indexPath) as? SettingsInformationCell
            cell?.set(item: item, context: nil)
            return cell
        }
    }()

    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.delegate = self
        tableView.backgroundColor = .clear
        tableView.rowHeight = 64
        tableView.separatorStyle = .none
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 30, right: 0)
        return tableView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        addCloseButton()
        setupView()
        setupConstraints()
        presenter?.reload()
    }

    private func setupView() {
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        view.addSubview(tableView)
        
        tableView.register(SettingsInformationCell.self, forCellReuseIdentifier: "SettingsInformationCell")
    }

    private func setupConstraints() {
        tableView.edgeAnchors == view.safeAreaLayoutGuide.edgeAnchors
    }
    
    func set(title: String) {
        navigationItem.title = title
        setNeedsStatusBarAppearanceUpdate()
    }

    func update(snapshot: SettingsInformationSnapshot) {
        dataSource.apply(snapshot, animatingDifferences: true)
    }
}

extension SettingsInformationViewController: UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else {
            return
        }
        
        item.onTap?()
    }
    
    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }
    
}

extension SettingsInformationViewController: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView.isTracking, scrollView.contentOffset.y < -200 {
            close()
        }
    }
}
