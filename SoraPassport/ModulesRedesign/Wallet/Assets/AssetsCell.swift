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

import UIKit
import SoraUIKit
import SoraFoundation
import Combine

/// How the Wallet home's cards load: the rows are there at once, values fade
/// in as they arrive, and a small spinner stands where a total is not known
/// yet. No skeleton bars.
enum WalletHomeLoading {
    static let fadeDuration: CFTimeInterval = 0.25

    /// Cross-fades the next change of `view`'s content. An explicit layer
    /// transition also runs inside `UIView.performWithoutAnimation`, which
    /// the wallet's reloads use.
    static func fade(_ view: UIView) {
        guard !UIAccessibility.isReduceMotionEnabled else {
            view.layer.removeAnimation(forKey: "wallet.home.fade")
            return
        }
        let transition = CATransition()
        transition.type = .fade
        transition.duration = fadeDuration
        transition.timingFunction = CAMediaTimingFunction(name: .easeOut)
        view.layer.add(transition, forKey: "wallet.home.fade")
    }

    static func makeSpinner() -> UIActivityIndicatorView {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true
        spinner.color = SoramitsuUI.shared.theme.palette.color(.fgSecondary)
        spinner.accessibilityLabel = WalletUX.text("Loading…")
        return spinner
    }

    /// Shows `text` in a total's place, or the spinner while it is empty.
    static func applyTotal(_ text: String, to label: SoramitsuLabel, spinner: UIActivityIndicatorView,
                           animated: Bool = true) {
        let shown = (label.text ?? "").trimmingCharacters(in: .whitespaces)
        if !animated {
            label.layer.removeAnimation(forKey: "wallet.home.fade")
        } else if shown != text {
            fade(label)
        }
        label.sora.loadingPlaceholder.type = .none
        label.sora.cornerRadius = .zero
        label.sora.text = text.isEmpty ? " " : text
        if text.isEmpty {
            spinner.startAnimating()
        } else {
            spinner.stopAnimating()
        }
    }
}

final class AssetsCell: SoramitsuTableViewCell {

    private var cancellables: Set<AnyCancellable> = []
    private var heightUpdateScheduled = false

    private var assetsItem: AssetsItem? {
        didSet {
            guard let item = assetsItem else { return }
            item.service?.$moneyText
                .receive(on: DispatchQueue.main)
                .sink { [weak self] value in
                    self?.applyTotal(value)
                    self?.scheduleHeightUpdate()
                }
                .store(in: &cancellables)
            item.service?.$priceNoteText
                .receive(on: DispatchQueue.main)
                .sink { [weak self] value in
                    self?.applyPriceNote(value)
                    self?.scheduleHeightUpdate()
                }
                .store(in: &cancellables)
            item.service?.$assetViewModels
                .receive(on: DispatchQueue.main)
                .sink { [weak self] value in
                    guard let self = self else { return }
                    self.updateContent(with: value, animated: true)
                    self.scheduleHeightUpdate()
                }
                .store(in: &cancellables)
        }
    }

    private var views: [MainScreenAssetView] = []
    private var renderedIdentifiers: [String] = []
    private var networkViews: [MainScreenAssetView] = []
    private var renderedNetworkRows: [NetworkAssetRow] = []
    private var localizationManager = LocalizationManager.shared

    private lazy var arrowButton: WalletHeaderView = {
        let button = WalletHeaderView()
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.assetsItem?.arrowButtonHandler?()
        }
        return button
    }()

    /// The 3.8.6 total: Bold, beside the title. A total too wide for the
    /// row shrinks rather than being cut off.
    private lazy var moneyLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.text = " "
        label.sora.font = FontType.headline2
        label.sora.textColor = .fgPrimary
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.sora.loadingPlaceholder.type = .none
        label.sora.alignment = localizationManager.isRightToLeft ? .left : .right
        return label
    }()

    /// Where the total goes, while it is not known yet.
    private let totalSpinner = WalletHomeLoading.makeSpinner()

    /// "Prices as of 09:02", under the total, while the prices shown are
    /// not current.
    private lazy var priceNoteLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textXS
        label.sora.numberOfLines = 0
        label.sora.textColor = .fgSecondary
        label.sora.alignment = .natural
        label.sora.isHidden = true
        return label
    }()

    private let containerView: SoramitsuView = {
        var view = SoramitsuView()
        view.sora.backgroundColor = .bgSurface
        view.sora.material = .glass
        view.sora.cornerRadius = .max
        return view
    }()

    private let fullStackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.axis = .vertical
        view.sora.distribution = .fill
        return view
    }()

    /// The title on the leading side, the total on the trailing side, as in 3.8.6.
    private let mainInfoView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.sora.axis = .horizontal
        view.sora.alignment = .center
        view.sora.distribution = .fill
        return view
    }()

    private lazy var openFullListAssetsButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .extraSmall, type: .text(.primary))
        button.sora.horizontalOffset = 0
        button.sora.attributedText = SoramitsuTextItem(text: R.string.localizable.commonExpand(preferredLanguages: .currentLocale),
                                                       fontData: FontType.buttonM,
                                                       textColor: .accentPrimary,
                                                       alignment: .natural)
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.assetsItem?.expandButtonHandler?()
        }
        return button
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupView()
        setupConstraints()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setupView() {
        contentView.addSubview(containerView)
        containerView.addSubview(fullStackView)

        mainInfoView.addArrangedSubviews(arrowButton, moneyLabel)
        mainInfoView.spacing = 12
        mainInfoView.addSubview(totalSpinner)
        totalSpinner.accessibilityIdentifier = "wallet.assets.total-loading"
        totalSpinner.startAnimating()
        fullStackView.addArrangedSubviews(mainInfoView)
        fullStackView.setCustomSpacing(16, after: mainInfoView)
        fullStackView.addArrangedSubviews(priceNoteLabel)
        fullStackView.setCustomSpacing(16, after: priceNoteLabel)

        let localizableTitle = LocalizableResource { locale in
            R.string.localizable.commonExpand(preferredLanguages: locale.rLanguages)
        }

        localizationManager.addObserver(with: openFullListAssetsButton) { [weak openFullListAssetsButton, weak arrowButton] (_, _) in
            guard let assetsItem = self.assetsItem else { return }
            let currentTitle = localizableTitle.value(for: self.localizationManager.selectedLocale)
            arrowButton?.configure(title: assetsItem.title, isExpand: assetsItem.isExpand)
            openFullListAssetsButton?.sora.attributedText = SoramitsuTextItem(text: currentTitle,
                                                           fontData: FontType.buttonM,
                                                           textColor: .accentPrimary,
                                                                              alignment: .natural)
        }
    }

    private func setupConstraints() {
        // The total's place keeps its width while it loads; a long title wins.
        let placeholderWidth = moneyLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 100)
        placeholderWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            placeholderWidth,
            totalSpinner.trailingAnchor.constraint(equalTo: moneyLabel.trailingAnchor),
            totalSpinner.centerYAnchor.constraint(equalTo: moneyLabel.centerYAnchor),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            containerView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),

            fullStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            fullStackView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            fullStackView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            fullStackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),
        ])
    }

    /// Published prices can arrive after UITableView has cached this row's
    /// initial height. Coalesce one sizing pass for a burst of price/asset updates.
    private func scheduleHeightUpdate() {
        guard !heightUpdateScheduled else { return }
        heightUpdateScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.heightUpdateScheduled = false
            // Adaptive token columns must settle before UITableView measures
            // this cell; otherwise an old stacked amount can leave a tall gap.
            self.views.forEach { $0.setNeedsLayout(); $0.layoutIfNeeded() }
            self.contentView.setNeedsLayout()
            self.contentView.layoutIfNeeded()
            var ancestor = self.superview
            while let view = ancestor, !(view is UITableView) { ancestor = view.superview }
            guard let table = ancestor as? UITableView,
                  table.window != nil, table.indexPath(for: self) != nil else { return }
            UIView.performWithoutAnimation {
                table.beginUpdates()
                table.endUpdates()
            }
        }
    }

    /// The same assets as shown are updated in place, so a balance or a
    /// value that arrives fades in instead of the whole list being redrawn.
    private func updateContent(with viewModels: [AssetViewModel], animated: Bool) {
        guard viewModels.map(\.identifier) == renderedIdentifiers, views.count == viewModels.count else {
            rebuildRows(with: viewModels)
            return
        }
        for (view, assetModel) in zip(views, viewModels) {
            apply(assetModel, to: view, animated: animated)
        }
        renderNetworkRows()
    }

    private func rebuildRows(with viewModels: [AssetViewModel]) {
        fullStackView.arrangedSubviews.filter { $0 is MainScreenAssetView }.forEach { subview in
            fullStackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }

        views = viewModels.map { assetModel -> MainScreenAssetView in
            let assetView = MainScreenAssetView()
            apply(assetModel, to: assetView, animated: false)
            return assetView
        }
        renderedIdentifiers = viewModels.map(\.identifier)

        fullStackView.addArrangedSubviews(views)

        if let assetView = views.last {
            fullStackView.setCustomSpacing(8, after: assetView)
        }

        fullStackView.addArrangedSubviews(openFullListAssetsButton)
        renderNetworkRows(force: true)
        setNeedsLayout()
    }

    /// One token row: its name and icon at once, then its amount (the
    /// symbol alone while the balance is read), its value and its change.
    private func apply(_ assetModel: AssetViewModel, to view: MainScreenAssetView, animated: Bool) {
        view.sora.isHidden = !(assetsItem?.isExpand ?? false)

        if let icon = assetModel.icon {
            view.assetImageView.sora.picture = .logo(image: icon)
        }
        view.assetImageView.sora.loadingPlaceholder.type = .none

        view.titleLabel.sora.text = sora2Title(assetModel.title)
        view.titleLabel.sora.loadingPlaceholder.type = .none

        let subtitle = assetModel.subtitle.isEmpty ? " " : assetModel.subtitle
        if animated, view.subtitleLabel.text != subtitle {
            WalletHomeLoading.fade(view.subtitleLabel)
        }
        view.subtitleLabel.sora.textColor = assetModel.balanceIsLoading ? .fgSecondary : .fgPrimary
        view.subtitleLabel.sora.text = subtitle
        view.subtitleLabel.sora.loadingPlaceholder.type = .none

        applyPrice(of: assetModel, to: view, animated: animated)
        view.sora.removeAllHandlers(for: .touchUpInside)
        view.sora.addHandler(for: .touchUpInside) { [weak assetsItem] in
            assetsItem?.assetHandler?(assetModel.identifier)
        }
    }

    /// SORA2 rows carry the network's name only once SORA2 is no longer the
    /// main network.
    private func sora2Title(_ title: String) -> String {
        guard let label = assetsItem?.sora2RowLabel else { return title }
        return "\(title) · \(label)"
    }

    /// XOR on other networks, in the same list: rows on the main network
    /// before the SORA2 rows, the others after them, above Expand. The same
    /// networks are updated in place.
    private func renderNetworkRows(force: Bool = false) {
        let rows = assetsItem?.networkRows ?? []
        let leadingRows = rows.filter(\.isMain)
        let trailingRows = rows.filter { !$0.isMain }
        let ordered = leadingRows + trailingRows
        let sameNetworks = ordered.map(\.account) == renderedNetworkRows.map(\.account)
            && ordered.map(\.isMain) == renderedNetworkRows.map(\.isMain)
            && networkViews.count == ordered.count
        if !force, sameNetworks {
            for (view, row) in zip(networkViews, ordered) {
                configure(view, with: row, animated: true)
            }
            renderedNetworkRows = ordered
            return
        }
        networkViews.forEach { view in
            fullStackView.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        let leading = leadingRows.map(makeNetworkView)
        let trailing = trailingRows.map(makeNetworkView)
        let firstRow = views.first.flatMap { fullStackView.arrangedSubviews.firstIndex(of: $0) }
            ?? fullStackView.arrangedSubviews.firstIndex(of: openFullListAssetsButton)
            ?? fullStackView.arrangedSubviews.count
        for (offset, view) in leading.enumerated() {
            fullStackView.insertArrangedSubview(view, at: firstRow + offset)
        }
        let expand = fullStackView.arrangedSubviews.firstIndex(of: openFullListAssetsButton)
            ?? fullStackView.arrangedSubviews.count
        for (offset, view) in trailing.enumerated() {
            fullStackView.insertArrangedSubview(view, at: expand + offset)
        }
        networkViews = leading + trailing
        renderedNetworkRows = ordered
        if let lastAsset = views.last {
            fullStackView.setCustomSpacing(trailing.isEmpty ? 8 : UIStackView.spacingUseDefault, after: lastAsset)
        }
        if let lastNetwork = trailing.last {
            fullStackView.setCustomSpacing(8, after: lastNetwork)
        }
    }

    private func makeNetworkView(_ row: NetworkAssetRow) -> MainScreenAssetView {
        let view = MainScreenAssetView()
        configure(view, with: row, animated: false)
        return view
    }

    private func configure(_ view: MainScreenAssetView, with row: NetworkAssetRow, animated: Bool) {
        view.sora.isHidden = !(assetsItem?.isExpand ?? false)
        if let icon = row.icon {
            view.assetImageView.sora.picture = .logo(image: icon)
        }
        view.assetImageView.sora.loadingPlaceholder.type = .none
        view.titleLabel.sora.text = row.title
        view.titleLabel.sora.loadingPlaceholder.type = .none
        // Blank while the balance is read; it fades in when it arrives.
        let amount = row.amount.isEmpty ? " " : row.amount
        if animated, view.subtitleLabel.text != amount {
            WalletHomeLoading.fade(view.subtitleLabel)
        }
        view.subtitleLabel.sora.text = amount
        view.subtitleLabel.sora.loadingPlaceholder.type = .none
        // Where a SORA2 row shows its value, a testnet or not-yet-live network
        // says why it has none.
        switch row.tag {
        case .testnet:
            view.amountUpLabel.sora.text = row.tag?.title
            view.amountUpLabel.sora.textColor = .custom(uiColor: .systemOrange)
        case .comingSoon:
            view.amountUpLabel.sora.text = row.tag?.title
            view.amountUpLabel.sora.textColor = .fgSecondary
        case .main, nil:
            view.amountUpLabel.sora.text = ""
        }
        view.amountUpLabel.sora.font = FontType.textBoldXS
        view.amountUpLabel.sora.loadingPlaceholder.type = .none
        view.amountDownLabel.sora.text = ""
        view.amountDownLabel.sora.loadingPlaceholder.type = .none
        view.accessibilityIdentifier = "wallet.network-row.\(row.account.networkId.rawValue)"
        view.sora.removeAllHandlers(for: .touchUpInside)
        view.sora.addHandler(for: .touchUpInside) { [weak assetsItem] in
            assetsItem?.networkRowHandler?(row.account)
        }
    }
}

private extension AssetsCell {
    /// The fiat value and 24-hour change of one row. While the price read
    /// is running a row keeps what it shows (nothing at first); once it
    /// has finished, a row without a price shows nothing there. Values
    /// fade in; no placeholder is drawn.
    func applyPrice(of assetModel: AssetViewModel, to view: MainScreenAssetView, animated: Bool) {
        let waiting = !assetModel.priceLoadFinished

        if !assetModel.fiatText.isEmpty || !waiting {
            if animated, (view.amountUpLabel.text ?? "") != assetModel.fiatText {
                WalletHomeLoading.fade(view.amountUpLabel)
            }
            view.amountUpLabel.sora.text = assetModel.fiatText
        }
        view.amountUpLabel.sora.loadingPlaceholder.type = .none

        if let delta = assetModel.deltaPriceText {
            let text = WalletUX.readableAttributedText(delta.attributedString)
            if animated, view.amountDownLabel.attributedText?.string != text.string {
                WalletHomeLoading.fade(view.amountDownLabel)
            }
            view.amountDownLabel.sora.attributedText = text
        } else if !waiting {
            view.amountDownLabel.sora.attributedText = NSAttributedString(string: "")
        }
        view.amountDownLabel.sora.loadingPlaceholder.type = .none
    }

    /// The total, or the spinner while it is not known. "Price unavailable"
    /// is a quiet notice, not an amount.
    func applyTotal(_ value: String, animated: Bool = true) {
        let unavailable = assetsItem?.service?.priceIsUnavailable ?? false
        moneyLabel.sora.font = unavailable ? FontType.textS : FontType.headline2
        moneyLabel.sora.textColor = unavailable ? .fgSecondary : .fgPrimary
        WalletHomeLoading.applyTotal(value, to: moneyLabel, spinner: totalSpinner, animated: animated)
    }

    func applyPriceNote(_ text: String) {
        priceNoteLabel.sora.text = text
        priceNoteLabel.sora.isHidden = text.isEmpty
        // A hidden row takes its spacing with it.
        fullStackView.setCustomSpacing(text.isEmpty ? 16 : 4, after: mainInfoView)
    }
}

extension AssetsCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? AssetsItem else {
            assertionFailure("Incorect type of item")
            return
        }

        let isNewItem = assetsItem !== item
        if isNewItem {
            cancellables.removeAll()
            assetsItem = item
        }

        arrowButton.configure(title: item.title, isExpand: item.isExpand)

        let viewModels = Array((item.service?.assetViewModels ?? []))
        if isNewItem {
            // A new item may belong to another wallet with the same token IDs.
            // Retained values and transitions must never cross that boundary.
            rebuildRows(with: viewModels)
            applyTotal(item.service?.moneyText ?? "", animated: false)
            applyPriceNote(item.service?.priceNoteText ?? "")
        } else {
            updateContent(with: viewModels, animated: true)
        }

        openFullListAssetsButton.sora.isHidden = !item.isExpand

        let alignment: NSTextAlignment = localizationManager.isRightToLeft ? .right : .left
        openFullListAssetsButton.sora.attributedText = SoramitsuTextItem(text: R.string.localizable.commonExpand(preferredLanguages: .currentLocale),
                                                                          fontData: FontType.buttonM,
                                                                          textColor: .accentPrimary,
                                                                          alignment: alignment)
    }
}
