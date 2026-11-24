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
import UIKit
import SoraUIKit
import SoraFoundation

protocol RedesignWalletViewProtocol: ControllerBackedProtocol {}

/// The Wallet home has no bar. Without this, the navigation controller shows the empty bar again after
/// `viewWillAppear` hid it, and it turns into a blank band across the top once the page scrolls.
final class RedesignWalletViewController: SoramitsuViewController, HiddableBarWhenPushed {

    private lazy var tableView: SoramitsuTableView = makeTableView()

    /// The right-hand page of a two-page home (an unfolded screen in landscape): the cards, scrolling
    /// beside the hero. Made the first time it is needed, so a phone never has it.
    private lazy var sideTableView: SoramitsuTableView = makeTableView()

    private func makeTableView() -> SoramitsuTableView {
        let tableView = SoramitsuTableView()
        // Clear: the tab bar controller draws the page colour behind every tab.
        tableView.sora.backgroundColor = .custom(uiColor: .clear)
        tableView.sora.estimatedRowHeight = UITableView.automaticDimension
        tableView.sora.tableViewHeader = nil
        tableView.delaysContentTouches = true
        tableView.canCancelContentTouches = true
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 65, right: 0)
        if #available(iOS 15.0, *) {
              tableView.sectionHeaderTopPadding = 0
         }
        return tableView
    }

    let viewModel: RedesignWalletViewModel
    /// The portfolio's table glue, when the home is the portfolio.
    private var portfolioBinding: PortfolioTableBinding?

    /// Everything the home shows, in order, however many pages it is on.
    private var items: [SoramitsuTableViewItemProtocol] = []
    private(set) var isTwoPage = false
    private var onePageConstraints: [NSLayoutConstraint] = []
    private var twoPageConstraints: [NSLayoutConstraint] = []
    private lazy var leftPageWidth = tableView.widthAnchor.constraint(equalToConstant: 0)
    private lazy var rightPageLeading = sideTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor)

    init(viewModel: RedesignWalletViewModel) {
        self.viewModel = viewModel
        super.init()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        setupConstraints()

        viewModel.reloadItem = { [weak self] items in
            DispatchQueue.main.async {
                guard let self = self else { return }
                Self.refresh(items: items, in: self.tableView)
                if self.isTwoPage { Self.refresh(items: items, in: self.sideTableView) }
            }
        }
        
        viewModel.setupItems = { [weak self] items in
            self?.show(items)
        }

        viewModel.fetchAssets { [weak self] items in
            self?.show(items)
        }

        portfolioBinding = PortfolioTableBinding(home: viewModel.portfolioHome, tableView: tableView, host: self)
    }

    /// Puts the home's rows on its page, or on its two pages.
    private func show(_ items: [SoramitsuTableViewItemProtocol]) {
        self.items = items
        let pages = WalletHomePages.split(items, twoPage: isTwoPage)
        UIView.performWithoutAnimation {
            tableView.sora.sections = [ SoramitsuTableViewSection(rows: pages.first) ]
            tableView.layoutIfNeeded()
            guard isTwoPage else { return }
            sideTableView.sora.sections = [ SoramitsuTableViewSection(rows: pages.second) ]
            sideTableView.layoutIfNeeded()
        }
        // Rows that arrive after the first layout may be the first to need a second page.
        if isViewLoaded, WalletDisplay.pages(in: view) != nil { view.setNeedsLayout() }
    }

    /// One page on every phone. Two on a window with room for them side by side: the hero stays on
    /// the left page while the cards scroll on the right one, either side of the fold. The rows are
    /// the same objects on either layout, so a balance being read, an open list or a scroll position
    /// in the cards is not started again when the window is resized.
    private func layoutPages() {
        let pages = WalletDisplay.pages(in: view)
        let wanted = pages != nil && !WalletHomePages.split(items, twoPage: true).second.isEmpty
        if wanted != isTwoPage {
            isTwoPage = wanted
            if wanted, sideTableView.superview == nil {
                sideTableView.translatesAutoresizingMaskIntoConstraints = false
                view.insertSubview(sideTableView, aboveSubview: tableView)
                twoPageConstraints = [
                    leftPageWidth,
                    rightPageLeading,
                    sideTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                    sideTableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                    sideTableView.bottomAnchor.constraint(equalTo: tableView.bottomAnchor)
                ]
            }
            NSLayoutConstraint.deactivate(wanted ? onePageConstraints : twoPageConstraints)
            NSLayoutConstraint.activate(wanted ? twoPageConstraints : onePageConstraints)
            if sideTableView.superview != nil {
                sideTableView.isHidden = !wanted
                if !wanted { sideTableView.sora.sections = [] }
            }
            portfolioBinding?.listTableView = wanted ? sideTableView : nil
            show(items)
        }
        if let pages, isTwoPage {
            leftPageWidth.constant = pages.left.width
            rightPageLeading.constant = pages.right.minX
        }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        layoutPages()
    }

    // Live balance updates can arrive in a burst. Animating a transparent card
    // reload retains outgoing cell snapshots and overlays several sets of rows.
    static func refresh(items: [SoramitsuTableViewItemProtocol], in tableView: SoramitsuTableView) {
        UIView.performWithoutAnimation {
            for item in items {
                for section in tableView.sora.sections {
                    guard let row = section.rows.firstIndex(where: { $0.isEqual(item) }) else { continue }
                    // Preserve the data source for future dequeues as well as
                    // updating the visible cell. Most wallet items mutate in place.
                    if section.rows[row] !== item { section.rows[row] = item }
                    (tableView.cellForItem(item: item) as? SoramitsuTableViewCellProtocol)?
                        .set(item: item, context: section.context)
                    break
                }
            }
            // Rebinding avoids UITableView's outgoing reload snapshots. Settle
            // capability-driven height changes before leaving this scope.
            tableView.beginUpdates()
            tableView.endUpdates()
            tableView.layoutIfNeeded()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        tableView.reloadData()
        if isTwoPage { sideTableView.reloadData() }
        portfolioBinding?.safeAreaDidChange()
        viewModel.portfolioHome.viewWillAppear()
        // Settings (the Taira switch) or the selected account may have changed.
        viewModel.refreshNetworkRows()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        portfolioBinding?.safeAreaDidChange()
        viewModel.portfolioHome.viewDidAppear()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        viewModel.portfolioHome.viewDidDisappear()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        portfolioBinding?.safeAreaDidChange()
    }

    private func setupView() {
        soramitsuView.sora.backgroundColor = .custom(uiColor: .clear)
        view.addSubview(tableView)
    }

    private func setupConstraints() {
        // The portfolio's sky runs under the status bar.
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 40)
        ])
        // The whole width on one page; `layoutPages` swaps this for the left page's width.
        onePageConstraints = [tableView.centerXAnchor.constraint(equalTo: view.centerXAnchor)]
        NSLayoutConstraint.activate(onePageConstraints)
    }
}

extension RedesignWalletViewController: RedesignWalletViewProtocol {}

/// Which rows of the Wallet home go on which page.
enum WalletHomePages {
    /// On two pages the hero, and the key warning under it, stay on the first page; the asset list and
    /// every card after it go on the second. On one page, and when there is nothing to put beside the
    /// hero, everything is on the first.
    static func split(_ items: [SoramitsuTableViewItemProtocol], twoPage: Bool)
        -> (first: [SoramitsuTableViewItemProtocol], second: [SoramitsuTableViewItemProtocol]) {
        guard twoPage,
              let cut = items.firstIndex(where: { !($0 is PortfolioHeroItem) && !($0 is PortfolioNoticeItem) }),
              cut > 0 else { return (items, []) }
        return (Array(items[..<cut]), Array(items[cut...]))
    }
}

extension RedesignWalletViewController: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }
    
    func applyLocalization() {
        tableView.reloadData()
        if isTwoPage { sideTableView.reloadData() }
    }
}
