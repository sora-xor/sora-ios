/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit

final class HelpViewController: UIViewController, AdaptiveDesignable {
    private struct Constants {
        static let leadingContentInsets = UIEdgeInsets(top: 25.0, left: 20.0, bottom: 28.0, right: 20.0)
        static let leadingDetailsTopSpacing: CGFloat = 24.0
        static let leadingSeparatorBottomMargin: CGFloat = 8.0
        static let normalContentInsets = UIEdgeInsets(top: 13.0, left: 20.0, bottom: 13.0, right: 20.0)
        static let normalDetailsTopSpacing: CGFloat = 15.0
        static let cellId = "helpItemCellId"
        static let headerContentInsets = UIEdgeInsets(top: 20.0, left: 20.0, bottom: 0.0, right: 20.0)
    }

	var presenter: HelpPresenterProtocol!

    @IBOutlet private var tableView: UITableView!

    var leadingItemLayoutMetadata = HelpItemLayoutMetadata()
    var normalItemLayoutMetadata = HelpItemLayoutMetadata()

    var supportLayoutMetadata: PosterLayoutMetadata {
        return headerViewFactory.createLayoutMetadata(from: Constants.headerContentInsets,
                                                      preferredWidth: headerWidth)
    }

    lazy var headerViewFactory: PosterViewFactoryProtocol.Type = SupportViewFactory.self
    var headerWidth: CGFloat = 375.0

    private(set) var viewModels: [HelpViewModelProtocol] = [] {
        didSet {
            tableView.reloadData()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        adjustLayout()
        configureLayoutMetadata()
        configureTableView()

        presenter.viewIsReady()
    }

    private func adjustLayout() {
        headerWidth *= designScaleRatio.width
    }

    private func configureLayoutMetadata() {
        leadingItemLayoutMetadata = leadingItemLayoutMetadata.with {
            $0.itemWidth *= designScaleRatio.width
            $0.contentInset = Constants.leadingContentInsets
            $0.titleColor = UIColor.helpLeadingItemTitle
            $0.titleFont = UIFont.helpLeadingItemTitle
            $0.detailsTopSpacing = Constants.leadingDetailsTopSpacing
            $0.detailsTitleColor = UIColor.helpLeadingItemDetails
            $0.detailsFont = UIFont.helpLeadingItemDetails
            $0.containsSeparator = true
            $0.separatorColor = UIColor.helpItemSeparatorColor
            $0.separatorBottomMargin = Constants.leadingSeparatorBottomMargin
        }

        normalItemLayoutMetadata = normalItemLayoutMetadata.with {
            $0.itemWidth *= designScaleRatio.width
            $0.contentInset = Constants.normalContentInsets
            $0.titleColor = UIColor.helpNormalItemTitle
            $0.titleFont = UIFont.helpNormalItemTitle
            $0.detailsTopSpacing = Constants.normalDetailsTopSpacing
            $0.detailsTitleColor = UIColor.helpNormalItemDetails
            $0.detailsFont = UIFont.helpNormalItemDetails
            $0.containsSeparator = false
        }
    }

    private func configureTableView() {
        tableView.register(HelpTableViewCell.self, forCellReuseIdentifier: Constants.cellId)
    }

    private func setupHeader(for viewModel: PosterViewModelProtocol) {
        let optionalHeaderView = headerViewFactory.createView(from: Constants.headerContentInsets,
                                                              preferredWidth: headerWidth)

        if let headerView = optionalHeaderView {
            headerView.delegate = self
            headerView.frame = CGRect(origin: .zero, size: viewModel.layout.itemSize)
            headerView.autoresizingMask = []

            headerView.bind(viewModel: viewModel)

            tableView.tableHeaderView = headerView
            tableView.setNeedsLayout()
        }
    }
}

extension HelpViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModels.count
    }

    // swiftlint:disable force_cast
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Constants.cellId,
                                                 for: indexPath) as! HelpTableViewCell

        let metadata = indexPath.row == 0 ? leadingItemLayoutMetadata : normalItemLayoutMetadata

        cell.bind(viewModel: viewModels[indexPath.row], layoutMetadata: metadata)

        return cell
    }
    // swiftlint:enable force_cast
}

extension HelpViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return viewModels[indexPath.row].layout.itemSize.height
    }
}

extension HelpViewController: HelpViewProtocol {
    func didReceive(supportItem: PosterViewModelProtocol) {
        setupHeader(for: supportItem)
    }

    func didLoad(viewModels: [HelpViewModelProtocol]) {
        self.viewModels = viewModels
    }
}

extension HelpViewController: PosterViewDelegate {
    func didSelectPoster(view: PosterView) {
        presenter.contactSupport()
    }
}
