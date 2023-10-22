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

protocol ActivityViewProtocol: ControllerBackedProtocol {
    func stopAnimating()
    func resetPagination()
}

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
        view.button.sora.associate(states: .pressed) { [weak tableView] _ in
            tableView?.resetPagination()
        }
        view.sora.isHidden = true
        return view
    }()
        

    private lazy var tableView: SoramitsuTableView = {
        let tableView = SoramitsuTableView()
        tableView.sora.estimatedRowHeight = UITableView.automaticDimension
        tableView.sora.context = SoramitsuTableViewContext(scrollView: tableView, viewController: self)
        tableView.sectionHeaderHeight = .zero
        return tableView
    }()
    
    private lazy var activityIndicator: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .large)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    var viewModel: ActivityViewModelProtocol

    init(viewModel: ActivityViewModelProtocol) {
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
        applyLocalization()
        
        tableView.sora.paginationHandler = viewModel
        
        viewModel.appendItems = { [weak self] items in
            DispatchQueue.main.async {
                self?.emptyLabel.sora.isHidden = true
                self?.errorView.sora.isHidden = true
                self?.tableView.sora.appendPageOnTop(items: items, resetPages: false)
            }
        }

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
        activityIndicator.startAnimating()
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
            
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
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
    
    @objc
    func refreshContent() {
        activityIndicator.startAnimating()
        tableView.resetPagination()
    }
}

extension ActivityViewController: ActivityViewProtocol {
    func stopAnimating() {
        DispatchQueue.main.async {
            self.tableView.refreshControl?.endRefreshing()
            self.activityIndicator.stopAnimating()
        }
    }
    
    func resetPagination() {
        activityIndicator.startAnimating()
        tableView.resetPagination()
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
