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
import SoraFoundation
import Combine

final class ActivityViewController: SoramitsuViewController {
    
    public var backgroundColor: SoramitsuColor = .custom(uiColor: .clear)
    
    private let emptyLabel: SoramitsuLabel = {
        let emptyLabel = SoramitsuLabel()
        emptyLabel.sora.font = FontType.paragraphM
        emptyLabel.sora.textColor = .fgSecondary
        emptyLabel.sora.alignment = .center
        emptyLabel.sora.numberOfLines = 0
        emptyLabel.sora.isHidden = true
        return emptyLabel
    }()
    
    private lazy var errorView: ErrorView = {
        let view = ErrorView()
        view.button.sora.associate(states: .pressed) { [weak self] _ in
            self?.resetPagination()
        }
        view.sora.isHidden = true
        return view
    }()
    
    private lazy var tableView: UITableView = {
        let tableView = SoramitsuTableView()
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.sectionHeaderHeight = .zero
        tableView.estimatedRowHeight = UITableView.automaticDimension
        tableView.register(ActivityCell.self, forCellReuseIdentifier: "ActivityCell")
        tableView.register(ActivityErrorCell.self, forCellReuseIdentifier: "ActivityErrorCell")
        tableView.register(SoramitsuCell<SoramitsuTableViewSpaceView>.self, forCellReuseIdentifier: "SoramitsuSpaceCell")
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 32, right: 0)
        tableView.sora.cancelsTouchesOnDragging = true
        tableView.sora.backgroundColor = .bgSurface
        tableView.sora.cornerRadius = .extraLarge
        return tableView
    }()
    
    private lazy var activityIndicator: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .large)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var paginationIndicator: SoramitsuActivityIndicatorView = {
        let view = SoramitsuActivityIndicatorView()
        view.sora.backgroundColor = .bgSurface
        view.sora.useAutoresizingMask = true
        return view
    }()

    var viewModel: ActivityViewModelProtocol {
        didSet {
            setupSubscription()
        }
    }

    private var cancellables: Set<AnyCancellable> = []

    private lazy var dataSource: ActivityDataSource = {
        ActivityDataSource(tableView: tableView) { tableView, indexPath, item in
            switch item {
            case .activity(let item):
                let cell: ActivityCell? = tableView.dequeueReusableCell(withIdentifier: "ActivityCell",
                                                                        for: indexPath) as? ActivityCell
                cell?.set(item: item)
                return cell ?? UITableViewCell()
            case .error(let item):
                let cell: ActivityErrorCell? = tableView.dequeueReusableCell(withIdentifier: "ActivityErrorCell",
                                                                        for: indexPath) as? ActivityErrorCell
                cell?.set(item: item)
                return cell ?? UITableViewCell()
            case .space(let item):
                let cell: SoramitsuCell<SoramitsuTableViewSpaceView>? = tableView.dequeueReusableCell(withIdentifier: "SoramitsuSpaceCell",
                                                                                                      for: indexPath) as? SoramitsuCell<SoramitsuTableViewSpaceView>
                cell?.set(item: item, context: nil)
                return cell ?? UITableViewCell()
            }
        }
    }()

    init(viewModel: ActivityViewModelProtocol) {
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
        applyLocalization()

        viewModel.viewDidLoad()

        viewModel.setupEmptyLabel = { [weak self] in
            DispatchQueue.main.async {
                self?.emptyLabel.sora.isHidden = false
                self?.errorView.sora.isHidden = true
            }
        }

        viewModel.setupErrorContent = { [weak self] in
            DispatchQueue.main.async {
                self?.errorView.sora.isHidden = false
                self?.emptyLabel.sora.isHidden = true
            }
        }

        viewModel.hideErrorContent = { [weak self] in
            DispatchQueue.main.async {
                self?.errorView.sora.isHidden = true
                self?.emptyLabel.sora.isHidden = true
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationItem.title = viewModel.title

        navigationController?.navigationBar.prefersLargeTitles = true
    }

    private func setupView() {
        let closeButton = UIBarButtonItem(image: R.image.wallet.cross(),
                                     style: .plain,
                                     target: self,
                                     action: #selector(close))

        navigationItem.rightBarButtonItem = viewModel.isNeedCloseButton ? closeButton : nil

        soramitsuView.sora.backgroundColor = backgroundColor
        view.addSubviews(tableView, emptyLabel, errorView)
        tableView.addSubview(activityIndicator)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: errorView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: errorView.centerYAnchor),

            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            tableView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            errorView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            errorView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    private func setupSubscription() {
        viewModel.snapshotPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] snapshot in
                self?.dataSource.apply(snapshot, animatingDifferences: false)
            }
            .store(in: &cancellables)
    }

    private func headerView(for section: Int) -> UIView? {
        guard let title = viewModel.headerText(for: section) else { return nil }

        let headerView = SoramitsuView()
        headerView.sora.backgroundColor = .bgSurface
        headerView.sora.useAutoresizingMask = true

        let headerLabel = SoramitsuLabel()
        headerLabel.sora.font = FontType.headline4
        headerLabel.sora.textColor = .fgSecondary
        headerLabel.sora.alignment = LocalizationManager.shared.isRightToLeft ? .right : .left
        headerLabel.sora.text = title

        headerView.addSubview(headerLabel)

        headerLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: section == 0 ? 0 : 8).isActive = true
        headerLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 24).isActive = true
        headerLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor).isActive = true
        headerLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -8).isActive = true

        return headerView
    }
}

extension ActivityViewController: ActivityViewProtocol {
    func stopAnimating() {
        DispatchQueue.main.async {
            self.activityIndicator.stopAnimating()
        }
    }

    func resetPagination() {
        activityIndicator.startAnimating()
        viewModel.resetPagination()
    }

    func startPaginationLoader() {
        paginationIndicator.start()
        tableView.tableFooterView = paginationIndicator
    }

    func stopPaginationLoader() {
        DispatchQueue.main.async {
            self.paginationIndicator.stop()
            self.tableView.tableFooterView = nil
        }
    }
}

extension ActivityViewController: Localizable {
    private var languages: [String]? {
        localizationManager?.preferredLocalizations
    }

    func applyLocalization() {
        let languages = localizationManager?.preferredLocalizations
        navigationItem.title = viewModel.title
        emptyLabel.sora.text = R.string.localizable.activityEmptyContentTitle(preferredLanguages: languages)
        errorView.titleLabel.sora.text = R.string.localizable.activityErrorTitle(preferredLanguages: languages)
        errorView.button.sora.attributedText = SoramitsuTextItem(text: R.string.localizable.commonRefresh(preferredLanguages: languages),
                                                                 fontData: FontType.textBoldS,
                                                                 textColor: .fgSecondary,
                                                                 alignment: .center)
    }
}

extension ActivityViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let item = dataSource.itemIdentifier(for: indexPath) else {
            return UITableView.automaticDimension
        }

        switch item {
        case .space:
            return 24
        default:
            return UITableView.automaticDimension
        }
    }

    public func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let lastSection = tableView.numberOfSections
        let lastRow = tableView.numberOfRows(inSection: lastSection - 1)
        let last = IndexPath(row: lastRow - 1, section: lastSection - 1)
        if last == indexPath {
            viewModel.updateContent()
        }
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let header = headerView(for: section) else { return nil }
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return viewModel.isNeedHeader(for: section) ? UITableView.automaticDimension : .zero
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        viewModel.didSelect(with: item)
    }
}
