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
import Combine

final class ActivityViewController: SoramitsuViewController {
    
    public var backgroundColor: SoramitsuColor = .custom(uiColor: .clear)
    private let bottomOffset: Int = 32
    
    private let emptyLabel: SoramitsuLabel = {
        let emptyLabel = SoramitsuLabel()
        emptyLabel.sora.font = FontType.paragraphM
        emptyLabel.sora.textColor = .fgSecondary
        emptyLabel.sora.alignment = .center
        emptyLabel.sora.numberOfLines = 0
        emptyLabel.sora.isHidden = true
        return emptyLabel
    }()
    
    private let emptyIcon: UIImageView = {
        let icon = UIImageView(image: UIImage(systemName: "clock.arrow.circlepath", withConfiguration: UIImage.SymbolConfiguration(pointSize: 36, weight: .light)))
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.tintColor = Lit.lacquerText
        icon.isHidden = true
        icon.isAccessibilityElement = false
        return icon
    }()

    private var loadingDeadline: DispatchWorkItem?

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
        tableView.register(ActivityNoticeCell.self, forCellReuseIdentifier: "ActivityNoticeCell")
        tableView.register(SoramitsuCell<SoramitsuTableViewSpaceView>.self, forCellReuseIdentifier: "SoramitsuSpaceCell")
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        tableView.sora.cancelsTouchesOnDragging = true
        tableView.sora.clipsToBounds = true
        tableView.sora.cornerRadius = .extraLarge
        tableView.sora.cornerMask = .top
        return tableView
    }()
    
    private lazy var activityIndicator: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .large)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var paginationView: SoramitsuView = {
        let view = SoramitsuView()
        view.frame = CGRect(origin: .zero, size: .init(width: Int(tableView.frame.size.width),
                                                       height: Int(paginationIndicator.sora.size.height) + bottomOffset))
        view.sora.backgroundColor = .bgSurface
        view.sora.useAutoresizingMask = true
        view.addSubview(paginationIndicator)
        return view
    }()

    private lazy var paginationIndicator: SoramitsuActivityIndicatorView = {
        let view = SoramitsuActivityIndicatorView()
        view.frame = CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: view.sora.size.height)
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
            case .notice(let item):
                let cell: ActivityNoticeCell? = tableView.dequeueReusableCell(withIdentifier: "ActivityNoticeCell",
                                                                              for: indexPath) as? ActivityNoticeCell
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

        viewModel.setupEmptyLabel = { [weak self] in
            DispatchQueue.main.async {
                self?.emptyLabel.sora.text = R.string.localizable.activityEmptyContentTitle(preferredLanguages: .currentLocale)
                self?.emptyIcon.isHidden = false
                self?.emptyLabel.sora.isHidden = false
                self?.errorView.sora.isHidden = true
            }
        }

        viewModel.setupErrorContent = { [weak self] in
            DispatchQueue.main.async {
                self?.errorView.sora.isHidden = false
                self?.emptyIcon.isHidden = true
                self?.emptyLabel.sora.isHidden = true
            }
        }

        viewModel.hideErrorContent = { [weak self] in
            DispatchQueue.main.async {
                self?.errorView.sora.isHidden = true
                self?.emptyIcon.isHidden = true
                self?.emptyLabel.sora.isHidden = true
            }
        }
        if !LitMotion.allowed {
            emptyLabel.sora.text = R.string.localizable.loading(preferredLanguages: .currentLocale)
            emptyLabel.sora.isHidden = false
            tableView.isHidden = true
        }
        scheduleLoadingDeadline()
        viewModel.viewDidLoad()
    }

    private func scheduleLoadingDeadline() {
        loadingDeadline?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.tableView.isHidden = true
            self.activityIndicator.stopAnimating()
            self.emptyIcon.isHidden = true
            self.emptyLabel.isHidden = true
            self.errorView.sora.isHidden = false
        }
        loadingDeadline = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 12, execute: work)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationItem.title = viewModel.title

        navigationController?.navigationBar.prefersLargeTitles = true

        // A list that is the saved copy asks for the current one again
        // when the user comes back to it.
        viewModel.viewWillAppear()
    }

    private func setupView() {
        let closeButton = UIBarButtonItem(image: R.image.wallet.cross(),
                                     style: .plain,
                                     target: self,
                                     action: #selector(close))

        closeButton.accessibilityLabel = R.string.localizable.commonClose(preferredLanguages: .currentLocale)
        navigationItem.rightBarButtonItem = viewModel.isNeedCloseButton ? closeButton : nil

        soramitsuView.sora.backgroundColor = backgroundColor
        view.addSubviews(tableView, emptyIcon, emptyLabel, errorView)
        view.addSubview(activityIndicator)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: errorView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: errorView.centerYAnchor),

            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            // The list is a card in the content column; the empty and failed states keep to it too.
            tableView.leadingAnchor.constraint(equalTo: view.litColumnGuide.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.litColumnGuide.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyIcon.centerXAnchor.constraint(equalTo: emptyLabel.centerXAnchor),
            emptyIcon.bottomAnchor.constraint(equalTo: emptyLabel.topAnchor, constant: -12),
            emptyLabel.leadingAnchor.constraint(equalTo: view.litColumnGuide.leadingAnchor, constant: 16),
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            errorView.leadingAnchor.constraint(equalTo: view.litColumnGuide.leadingAnchor, constant: 16),
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
        
        if section == 0 {
            headerView.sora.cornerRadius = .extraLarge
            headerView.sora.cornerMask = .top
        }

        let headerLabel = SoramitsuLabel()
        headerLabel.sora.font = FontType.headline4
        headerLabel.sora.textColor = .fgSecondary
        headerLabel.sora.alignment = LocalizationManager.shared.isRightToLeft ? .right : .left
        headerLabel.sora.text = title

        headerView.addSubview(headerLabel)

        headerLabel.topAnchor.constraint(equalTo: headerView.topAnchor, constant: section == 0 ? 24 : 8).isActive = true
        headerLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 24).isActive = true
        headerLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor).isActive = true
        headerLabel.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -8).isActive = true

        return headerView
    }
}

extension ActivityViewController: ActivityViewProtocol {
    func stopAnimating() {
        DispatchQueue.main.async {
            self.loadingDeadline?.cancel()
            self.tableView.isHidden = false
            self.activityIndicator.stopAnimating()
        }
    }

    func resetPagination() {
        scheduleLoadingDeadline()
        errorView.sora.isHidden = true
        emptyIcon.isHidden = true
        emptyLabel.isHidden = true
        activityIndicator.startAnimating()
        viewModel.resetPagination()
    }

    func startPaginationLoader() {
        paginationIndicator.start()
        tableView.tableFooterView = paginationView
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
                                                                 textColor: .fgInverted,
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
