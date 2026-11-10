// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: Apache-2.0

import Combine
import CoreImage
import NexusTransferCodec
import SoraFoundation
import SoraUIKit
import UIKit

// XOR on Taira and SORA Nexus is shown on SORA2's own screens: the same view
// controllers (Receive, Select recipient, Enter amount, Confirm sending,
// transaction details) and the same cards as SORA2's asset details, fed with
// the network's data. Only the network logic differs; nothing here may look
// different from the SORA2 XOR screens.

// MARK: - Presentation

enum NexusSora2Presentation {
    /// SORA2's modal presentation: a navigation controller over the blurred
    /// screen it was opened from.
    @MainActor
    static func present(
        _ root: UIViewController,
        from presenter: UIViewController,
        navigation: UINavigationController? = nil,
        completion: (() -> Void)? = nil
    ) {
        let navigationController = navigation ?? SoraNavigationController(rootViewController: root)
        navigationController.navigationBar.backgroundColor = .clear
        let container = BlurViewController()
        container.modalPresentationStyle = .overFullScreen
        container.add(navigationController)
        presenter.present(container, animated: true, completion: completion)
    }

    /// SORA2's presentation of transaction details: the screen itself over
    /// the blurred one below, without a navigation bar.
    @MainActor
    static func presentDetails(_ controller: UIViewController, from presenter: UIViewController) {
        let container = BlurViewController()
        container.modalPresentationStyle = .overFullScreen
        container.add(controller)
        presenter.present(container, animated: true)
    }

    static var xorAsset: AssetInfo? {
        AssetManager.networkAssets.first { $0.identifier == WalletAssetId.xor.rawValue }
    }

    static func xorImage(_ asset: AssetInfo?) -> UIImage? {
        asset?.icon.flatMap { RemoteSerializer.shared.image(with: $0) } ?? R.image.iconSora()
    }

    /// The avatar SORA2 shows before a recipient is chosen. Network addresses
    /// have no SORA2 identicon.
    static var recipientImage: UIImage? {
        UIImage(systemName: "person.crop.circle")
    }

    @MainActor
    static func showCopied(_ service: AppEventService) {
        let title = NSAttributedString(string: R.string.localizable.commonCopied(preferredLanguages: .currentLocale))
        let viewModel = AppEventViewController.ViewModel(title: title)
        service.showToasterIfNeeded(viewController: AppEventViewController(style: .custom(viewModel)))
    }

    @MainActor
    static func qrImage(_ value: String, side: CGFloat) -> UIImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(value.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage, output.extent.width > 0 else { return nil }
        let scale = max(1, (side * UIScreen.main.scale / output.extent.width).rounded(.down))
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let image = CIContext().createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: image, scale: UIScreen.main.scale, orientation: .up)
    }

    /// "1.25 XOR", or "+ 2.5 XOR" in the success colour for a transfer in,
    /// as SORA2 writes amounts in its activity. Network amounts are exact
    /// decimal strings and are shown as they are, never rounded.
    static func amountText(_ amount: String, incoming: Bool, font: FontData, alignment: NSTextAlignment) -> SoramitsuTextItem {
        let isRTL = LocalizationManager.shared.isRightToLeft
        let text = incoming
            ? (isRTL ? "XOR \(amount) +" : "+ \(amount) XOR")
            : (isRTL ? "XOR \(amount)" : "\(amount) XOR")
        return SoramitsuTextItem(text: text, fontData: font,
                                 textColor: incoming ? .statusSuccess : .fgPrimary,
                                 alignment: alignment)
    }

    static func status(of state: NexusPendingState) -> TransactionBase.Status {
        switch state {
        case .committed: return .success
        case .failedBeforeSubmission, .rejected, .expired: return .failed
        default: return .pending
        }
    }
}

// MARK: - Balance card (SORA2's TransferableCell)

enum NexusBalanceAction {
    case send
    case receive
    case faucet
}

struct NexusFaucetState: Equatable {
    var title: String
    var message: String
    var busy: Bool
    var enabled: Bool
}

final class NexusBalanceItem: NSObject {
    var balanceText: String
    var showsSend: Bool
    var receiveTitle: String
    var faucet: NexusFaucetState?
    var notes: [String]
    var actionHandler: ((NexusBalanceAction) -> Void)?

    init(balanceText: String,
         showsSend: Bool = false,
         receiveTitle: String = R.string.localizable.commonReceive(preferredLanguages: .currentLocale),
         faucet: NexusFaucetState? = nil,
         notes: [String] = []) {
        self.balanceText = balanceText
        self.showsSend = showsSend
        self.receiveTitle = receiveTitle
        self.faucet = faucet
        self.notes = notes
    }
}

extension NexusBalanceItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { NexusBalanceCell.self }
    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }
    var clipsToBounds: Bool { false }
}

/// SORA2's balance card, view for view: the "Liquid balance" title, the
/// amount, a divider and the round actions. Swap is left out because
/// Polkaswap does not run on these networks; Taira adds its faucet.
final class NexusBalanceCell: SoramitsuTableViewCell {
    private var item: NexusBalanceItem?
    private let localizationManager = LocalizationManager.shared

    private let containerView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .bgSurface
        view.sora.shadow = .small
        view.sora.cornerRadius = .max
        view.clipsToBounds = false
        view.sora.axis = .vertical
        view.sora.alignment = .center
        view.layoutMargins = UIEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        view.isLayoutMarginsRelativeArrangement = true
        return view
    }()

    private let transferableContainerView: SoramitsuView = {
        var view = SoramitsuView()
        view.sora.backgroundColor = .custom(uiColor: .clear)
        return view
    }()

    private let transferableLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline2
        label.sora.textColor = .fgPrimary
        label.sora.text = R.string.localizable.assetDetailsLiquidBalance(preferredLanguages: .currentLocale)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    let balanceLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.textBoldXS
        label.sora.textColor = .fgSecondary
        label.sora.numberOfLines = 0
        label.sora.text = " "
        label.accessibilityIdentifier = "nexus.balance"
        return label
    }()

    private let separatorView: SoramitsuView = {
        let view = SoramitsuView()
        view.sora.backgroundColor = .fgOutline
        return view
    }()

    private let actionsStackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.backgroundColor = .custom(uiColor: .clear)
        view.sora.axis = .horizontal
        view.sora.distribution = .equalSpacing
        view.sora.alignment = .center
        view.sora.shadow = .small
        view.spacing = 20
        view.clipsToBounds = false
        return view
    }()

    private(set) lazy var sendButton: AssetActionView = action(
        title: R.string.localizable.commonSend(preferredLanguages: .currentLocale),
        image: R.image.wallet.send(), identifier: "nexus.send", action: .send)

    private(set) lazy var receiveButton: AssetActionView = action(
        title: R.string.localizable.commonReceive(preferredLanguages: .currentLocale),
        image: R.image.wallet.receive(), identifier: "nexus.receive", action: .receive)

    private(set) lazy var faucetButton: AssetActionView = action(
        title: WalletUX.text("Get test XOR"),
        image: R.image.wallet.buy(), identifier: "taira.faucet.request", action: .faucet)

    private let faucetSpinner: UIActivityIndicatorView = {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.hidesWhenStopped = true
        spinner.isUserInteractionEnabled = false
        spinner.translatesAutoresizingMaskIntoConstraints = false
        return spinner
    }()

    let faucetStatusLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphXS
        label.sora.textColor = .fgSecondary
        label.sora.alignment = .center
        label.sora.numberOfLines = 0
        label.accessibilityIdentifier = "taira.faucet.status"
        return label
    }()

    let notesLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphXS
        label.sora.textColor = .fgSecondary
        label.sora.alignment = .center
        label.sora.numberOfLines = 0
        label.accessibilityIdentifier = "nexus.notes"
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(containerView)
        actionsStackView.addArrangedSubviews(sendButton, receiveButton, faucetButton)
        faucetButton.button.addSubview(faucetSpinner)
        transferableContainerView.addSubviews(transferableLabel, balanceLabel)
        containerView.addArrangedSubviews(transferableContainerView, separatorView, actionsStackView,
                                          faucetStatusLabel, notesLabel)
        containerView.setCustomSpacing(16, after: transferableContainerView)
        containerView.setCustomSpacing(24, after: separatorView)
        containerView.setCustomSpacing(16, after: actionsStackView)
        containerView.setCustomSpacing(8, after: faucetStatusLabel)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            containerView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            containerView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor),

            transferableContainerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            transferableContainerView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            separatorView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            separatorView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            separatorView.heightAnchor.constraint(equalToConstant: 1),

            transferableLabel.leadingAnchor.constraint(equalTo: transferableContainerView.leadingAnchor),
            transferableLabel.trailingAnchor.constraint(lessThanOrEqualTo: transferableContainerView.trailingAnchor),
            transferableLabel.topAnchor.constraint(equalTo: transferableContainerView.topAnchor),

            balanceLabel.leadingAnchor.constraint(equalTo: transferableContainerView.leadingAnchor),
            balanceLabel.trailingAnchor.constraint(equalTo: transferableContainerView.trailingAnchor),
            balanceLabel.topAnchor.constraint(equalTo: transferableLabel.bottomAnchor, constant: 4),
            balanceLabel.bottomAnchor.constraint(equalTo: transferableContainerView.bottomAnchor),

            actionsStackView.heightAnchor.constraint(equalToConstant: 76),

            faucetStatusLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            faucetStatusLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            notesLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            notesLabel.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),

            faucetSpinner.centerXAnchor.constraint(equalTo: faucetButton.button.centerXAnchor),
            faucetSpinner.centerYAnchor.constraint(equalTo: faucetButton.button.centerYAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func action(title: String, image: UIImage?, identifier: String, action: NexusBalanceAction) -> AssetActionView {
        let view = AssetActionView()
        // The label may be wider than SORA2's round button ("Get test XOR"):
        // centred, it is shown whole instead of being cut to the circle.
        view.stackView.sora.alignment = .center
        view.titleLabel.sora.text = title
        view.button.sora.leftImage = image
        view.button.sora.horizontalOffset = 16
        view.accessibilityIdentifier = identifier
        view.accessibilityLabel = title
        view.isAccessibilityElement = true
        view.accessibilityTraits = .button
        view.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.item?.actionHandler?(action)
        }
        return view
    }
}

extension NexusBalanceCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? NexusBalanceItem else {
            assertionFailure("Incorect type of item")
            return
        }
        self.item = item
        balanceLabel.sora.text = item.balanceText
        balanceLabel.sora.alignment = localizationManager.isRightToLeft ? .right : .left
        transferableLabel.sora.alignment = localizationManager.isRightToLeft ? .right : .left
        sendButton.sora.isHidden = !item.showsSend
        receiveButton.titleLabel.sora.text = item.receiveTitle
        receiveButton.accessibilityLabel = item.receiveTitle
        if let faucet = item.faucet {
            faucetButton.sora.isHidden = false
            faucetButton.titleLabel.sora.text = faucet.title
            faucetButton.accessibilityLabel = faucet.title
            // A cooldown keeps the action tappable: the tap says when to retry.
            faucetButton.isEnabled = faucet.enabled && !faucet.busy
            faucetButton.alpha = faucet.busy ? 0.5 : 1
            faucet.busy ? faucetSpinner.startAnimating() : faucetSpinner.stopAnimating()
            faucetStatusLabel.sora.text = faucet.message
            faucetStatusLabel.sora.isHidden = faucet.message.isEmpty
        } else {
            faucetButton.sora.isHidden = true
            faucetSpinner.stopAnimating()
            faucetStatusLabel.sora.isHidden = true
        }
        let notes = item.notes.joined(separator: "\n\n")
        notesLabel.sora.text = notes
        notesLabel.sora.isHidden = notes.isEmpty
    }
}

// MARK: - Recent activity card (SORA2's RecentActivityCell)

final class NexusActivityItem: NSObject {
    var rows: [ActivityContentViewModel]
    var notice: String?
    /// "Show more", or nil when every transfer is already listed.
    var moreTitle: String?
    var openDetails: ((String) -> Void)?
    var openMore: (() -> Void)?
    var openNotice: (() -> Void)?

    init(rows: [ActivityContentViewModel], notice: String? = nil, moreTitle: String? = nil) {
        self.rows = rows
        self.notice = notice
        self.moreTitle = moreTitle
    }
}

extension NexusActivityItem: SoramitsuTableViewItemProtocol {
    var cellType: AnyClass { NexusActivityCell.self }
    var backgroundColor: SoramitsuColor { .custom(uiColor: .clear) }
    var clipsToBounds: Bool { false }
}

/// SORA2's "Recent activity" card with SORA2's activity rows.
final class NexusActivityCell: SoramitsuTableViewCell {
    private var item: NexusActivityItem?
    private let localizationManager = LocalizationManager.shared

    private let titleLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.headline2
        label.sora.textColor = .fgPrimary
        label.sora.text = R.string.localizable.assetDetailsRecentActivity(preferredLanguages: .currentLocale)
        return label
    }()

    private let containerView: SoramitsuView = {
        var view = SoramitsuView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.sora.backgroundColor = .bgSurface
        view.sora.cornerRadius = .max
        return view
    }()

    private let fullStackView: SoramitsuStackView = {
        var view = SoramitsuStackView()
        view.sora.axis = .vertical
        view.sora.distribution = .fill
        return view
    }()

    private lazy var noticeControl: SoramitsuControl = {
        let control = SoramitsuControl()
        control.sora.backgroundColor = .custom(uiColor: .clear)
        control.addSubview(noticeLabel)
        control.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.item?.openNotice?()
        }
        control.accessibilityIdentifier = "nexus.activity.notice"
        return control
    }()

    let noticeLabel: SoramitsuLabel = {
        let label = SoramitsuLabel()
        label.sora.font = FontType.paragraphXS
        label.sora.textColor = .fgSecondary
        label.sora.numberOfLines = 0
        label.isUserInteractionEnabled = false
        return label
    }()

    private(set) lazy var moreButton: SoramitsuButton = {
        let button = SoramitsuButton(size: .small, type: .text(.primary))
        button.sora.horizontalOffset = 0
        button.sora.addHandler(for: .touchUpInside) { [weak self] in
            self?.item?.openMore?()
        }
        button.accessibilityIdentifier = "nexus.activity.more"
        return button
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(containerView)
        containerView.addSubview(fullStackView)
        fullStackView.addArrangedSubviews(titleLabel)
        fullStackView.setCustomSpacing(16, after: titleLabel)
        noticeLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            containerView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            fullStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 24),
            fullStackView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            fullStackView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            fullStackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 24),

            noticeLabel.leadingAnchor.constraint(equalTo: noticeControl.leadingAnchor),
            noticeLabel.trailingAnchor.constraint(equalTo: noticeControl.trailingAnchor),
            noticeLabel.topAnchor.constraint(equalTo: noticeControl.topAnchor, constant: 8),
            noticeLabel.bottomAnchor.constraint(equalTo: noticeControl.bottomAnchor, constant: -8),

            moreButton.heightAnchor.constraint(equalToConstant: 32),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func update(with item: NexusActivityItem) {
        fullStackView.arrangedSubviews.filter { $0 !== titleLabel }.forEach { subview in
            fullStackView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
        let alignment: NSTextAlignment = localizationManager.isRightToLeft ? .right : .left
        titleLabel.sora.alignment = alignment
        fullStackView.semanticContentAttribute = localizationManager.isRightToLeft ? .forceRightToLeft : .forceLeftToRight

        // Built as SORA2's RecentActivityCell builds its rows.
        let views = item.rows.map { model -> ActivityView in
            let view = ActivityView()
            view.isUserInteractionEnabled = true
            if let image = model.firstAssetImageViewModel {
                view.firstCurrencyImageView.sora.picture = .logo(image: image)
            }
            view.firstCurrencyImageView.sora.loadingPlaceholder.type = .none
            view.secondCurrencyImageView.isHidden = true
            view.oneCurrencyImageView.isHidden = false
            view.firstCurrencyHeightContstaint?.constant = 40
            view.titleLabel.sora.text = model.title
            view.titleLabel.sora.loadingPlaceholder.type = .none
            view.subtitleLabel.sora.text = model.subtitle
            view.subtitleLabel.sora.loadingPlaceholder.type = .none
            if let image = model.typeTransactionImage {
                view.transactionTypeImageView.sora.picture = .logo(image: image)
            }
            view.transactionTypeImageView.sora.loadingPlaceholder.type = .none
            view.amountUpLabel.sora.attributedText = model.firstBalanceText
            view.amountUpLabel.sora.loadingPlaceholder.type = .none
            view.amountView.sora.loadingPlaceholder.type = .none
            if let image = model.status.image {
                view.statusImageView.sora.picture = .logo(image: image)
            }
            view.statusImageView.sora.isHidden = model.status.image == nil
            view.accessibilityIdentifier = "nexus.activity.row"
            view.isAccessibilityElement = true
            view.accessibilityTraits = .button
            view.accessibilityLabel = [model.title, model.firstBalanceText.attributedString.string, model.subtitle]
                .filter { !$0.isEmpty }.joined(separator: ", ")
            view.sora.addHandler(for: .touchUpInside) { [weak self] in
                self?.item?.openDetails?(model.txHash)
            }
            view.isRightToLeft = localizationManager.isRightToLeft
            return view
        }
        fullStackView.addArrangedSubviews(views)
        if let last = views.last {
            fullStackView.setCustomSpacing(8, after: last)
        }
        if let notice = item.notice {
            noticeLabel.sora.text = notice
            noticeLabel.sora.alignment = alignment
            fullStackView.addArrangedSubviews(noticeControl)
            fullStackView.setCustomSpacing(8, after: noticeControl)
        }
        if let moreTitle = item.moreTitle {
            moreButton.sora.attributedText = SoramitsuTextItem(text: moreTitle,
                                                               fontData: FontType.buttonM,
                                                               textColor: .accentPrimary,
                                                               alignment: alignment)
            fullStackView.addArrangedSubviews(moreButton)
        } else {
            // The card ends 24 pt below its last row, as SORA2's does above its button.
            let spacer = SoramitsuView()
            spacer.sora.backgroundColor = .custom(uiColor: .clear)
            spacer.heightAnchor.constraint(equalToConstant: 16).isActive = true
            fullStackView.addArrangedSubviews(spacer)
        }
        setNeedsLayout()
    }
}

extension NexusActivityCell: SoramitsuTableViewCellProtocol {
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        guard let item = item as? NexusActivityItem else {
            assertionFailure("Incorect type of item")
            return
        }
        self.item = item
        update(with: item)
    }
}

// MARK: - Transaction details (SORA2's ActivityDetailsViewController)

final class NexusActivityDetailsViewModel {
    struct Model {
        var title: String
        var incoming: Bool
        var amount: String?
        var status: TransactionBase.Status
        var statusText: String
        var date: Date?
        var fee: String?
        var transactionId: String?
        var sender: String?
        var recipient: String?
        var note: String?
    }

    weak var view: ActivityDetailsViewProtocol?
    /// Runs after the screen was closed with its Close button.
    var completion: (() -> Void)?
    private(set) var items: [SoramitsuTableViewItemProtocol] = []
    let model: Model
    private let xorImage: UIImage?
    private let appEventService = AppEventService()
    private let isCurrent: @MainActor () -> Bool
    /// Opens the network's explorer; nil leaves the button out.
    private let openExplorer: (@MainActor () -> Void)?

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = LocalizationManager.shared.dateFormat
        formatter.locale = !LocalizationManager.shared.isArabic ? LocalizationManager.shared.selectedLocale : nil
        return formatter
    }()

    init(model: Model, xorImage: UIImage?,
         isCurrent: @escaping @MainActor () -> Bool = { true },
         openExplorer: (@MainActor () -> Void)? = nil) {
        self.model = model
        self.xorImage = xorImage
        self.isCurrent = isCurrent
        self.openExplorer = openExplorer
    }

    static func transfer(_ item: NexusTransferHistoryItem, account: String) -> Model {
        let outgoing = item.sender == account
        let type: TransferTransaction.TransferType = outgoing ? .outcoming : .incoming
        return Model(
            title: type.detailsTitle, incoming: !outgoing, amount: item.amount.rawValue,
            status: .success, statusText: TransactionBase.Status.success.title,
            date: Date(timeIntervalSince1970: TimeInterval(item.timestampMilliseconds) / 1000),
            fee: nil, transactionId: item.transactionHash,
            sender: item.sender, recipient: item.receiver, note: nil)
    }

    static func pending(_ row: NexusPortfolioPresentationPolicy.PendingRow) -> Model {
        let item = row.transaction
        let isRecovery = row.kind == .assetRecovery
        return Model(
            title: isRecovery ? WalletUX.text("Pending asset recovery")
                : TransferTransaction.TransferType.outcoming.detailsTitle,
            incoming: false,
            amount: isRecovery ? nil : item.amount.rawValue,
            status: NexusSora2Presentation.status(of: item.state),
            statusText: WalletUX.status(item.state),
            date: item.updatedAt,
            fee: isRecovery ? nil : item.fee.rawValue,
            transactionId: item.hash,
            sender: item.sender, recipient: item.receiver,
            note: isRecovery
                ? WalletUX.format("%@ units · Pending asset recovery", item.amount.rawValue) + "\n\n" + WalletUX.statusDetail(item.state)
                : WalletUX.statusDetail(item.state))
    }

    private func detailText(_ text: String, color: SoramitsuColor = .fgPrimary) -> SoramitsuTextItem {
        SoramitsuTextItem(text: text, fontData: FontType.textS, textColor: color, alignment: .right)
    }

    private func makeItems() -> [SoramitsuTableViewItemProtocol] {
        var items: [SoramitsuTableViewItemProtocol] = []

        var headerDetails = [DetailViewModel(
            title: R.string.localizable.walletTxDetailsStatus(preferredLanguages: .currentLocale),
            statusAssetImage: model.status.image,
            assetAmountText: detailText(model.statusText, color: model.status.color))]
        if let date = model.date {
            headerDetails.append(DetailViewModel(
                title: R.string.localizable.transactionDate(preferredLanguages: .currentLocale),
                assetAmountText: detailText(dateFormatter.string(from: date))))
        }
        if let fee = model.fee {
            headerDetails.append(DetailViewModel(
                title: R.string.localizable.networkFee(preferredLanguages: .currentLocale),
                assetAmountText: detailText("\(fee) XOR")))
        }
        let amount = model.amount.map {
            NexusSora2Presentation.amountText($0, incoming: model.incoming, font: FontType.headline3, alignment: .center)
                .attributedString
        } ?? NSAttributedString(string: "")
        let type: TransferTransaction.TransferType = model.incoming ? .incoming : .outcoming
        items.append(HeaderActivityDetailsItem(typeText: model.title,
                                               typeTransactionImage: type.image,
                                               firstAssetImageViewModel: xorImage,
                                               firstBalanceText: amount,
                                               details: headerDetails))
        items.append(SoramitsuTableViewSpacerItem(space: 16, color: .custom(uiColor: .clear)))

        var details: [ActivityDetailViewModel] = []
        if let transactionId = model.transactionId, !transactionId.isEmpty {
            details.append(ActivityDetailViewModel(title: WalletUX.text("Transaction ID"), value: transactionId))
        }
        if let recipient = model.recipient {
            details.append(ActivityDetailViewModel(
                title: R.string.localizable.commonRecipient(preferredLanguages: .currentLocale), value: recipient))
        }
        if let sender = model.sender {
            details.append(ActivityDetailViewModel(
                title: R.string.localizable.commonSender(preferredLanguages: .currentLocale), value: sender))
        }
        if !details.isEmpty {
            let detailsItem = ActivityDetailsItem(detailViewModels: details)
            detailsItem.copyToClipboardHander = { [weak self] value in
                Task { @MainActor [weak self] in
                    guard let self, self.isCurrent() else { return }
                    UIPasteboard.general.string = value
                    NexusSora2Presentation.showCopied(self.appEventService)
                }
            }
            items.append(detailsItem)
            items.append(SoramitsuTableViewSpacerItem(space: 16, color: .custom(uiColor: .clear)))
        }
        if let note = model.note {
            items.append(WalletInlineNoticeItem(note))
            items.append(SoramitsuTableViewSpacerItem(space: 16, color: .custom(uiColor: .clear)))
        }
        if let openExplorer {
            let title = SoramitsuTextItem(text: WalletUX.text("Open explorer"), fontData: FontType.buttonM,
                                          textColor: .accentTertiary, alignment: .center)
            items.append(SoramitsuButtonItem(title: title, buttonBackgroudColor: .bgSurface, handler: {
                Task { @MainActor in openExplorer() }
            }))
            items.append(SoramitsuTableViewSpacerItem(space: 16, color: .custom(uiColor: .clear)))
        }
        let closeTitle = SoramitsuTextItem(text: R.string.localizable.commonClose(preferredLanguages: .currentLocale),
                                           fontData: FontType.buttonM, textColor: .accentTertiary, alignment: .center)
        items.append(SoramitsuButtonItem(title: closeTitle, buttonBackgroudColor: .bgSurface, handler: { [weak self] in
            self?.dismiss()
        }))
        return items
    }
}

extension NexusActivityDetailsViewModel: ActivityDetailsViewModelProtocol {
    func updateContent(completion: ([SoramitsuTableViewItemProtocol]) -> Void) {
        items = makeItems()
        completion(items)
    }

    func dismiss() {
        view?.controller.dismiss(animated: true, completion: completion)
    }
}

// MARK: - Receive (SORA2's ReceiveViewController)

final class NexusReceiveViewModel: ReceiveViewModelProtocol {
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    weak var view: ReceiveViewProtocol?
    let address: String
    let name: String
    let notice: String?
    private let avatar: UIImage?
    private let isCurrent: @MainActor () -> Bool
    private let appEventService = AppEventService()
    private(set) var item: ReceiveItem?

    init(address: String, name: String, notice: String?, avatar: UIImage?,
         isCurrent: @escaping @MainActor () -> Bool) {
        self.address = address
        self.name = name
        self.notice = notice
        self.avatar = avatar
        self.isCurrent = isCurrent
    }

    func viewDidLoad() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let side = UIScreen.main.bounds.width - 112
            let qrImage = NexusSora2Presentation.qrImage(address, side: side)
            let item = ReceiveItem(name: name, address: address, qrImage: qrImage,
                                   avatar: avatar, notice: notice)
            item.shareHandler = { [weak self] in
                Task { @MainActor [weak self] in self?.share(qrImage) }
            }
            item.accountTapHandler = { [weak self] in
                Task { @MainActor [weak self] in self?.copy() }
            }
            self.item = item
            setupItems?([item])
        }
    }

    @MainActor
    func copy() {
        guard isCurrent() else { return }
        UIPasteboard.general.string = address
        NexusSora2Presentation.showCopied(appEventService)
    }

    @MainActor
    private func share(_ qrImage: UIImage?) {
        guard isCurrent(), let controller = view?.controller else { return }
        let sources: [Any] = [address] + (qrImage.map { [$0] } ?? [])
        controller.present(UIActivityViewController(activityItems: sources, applicationActivities: nil), animated: true)
    }
}

// MARK: - Select recipient (SORA2's ContactsViewController)

final class NexusRecipientSearchViewModel: ContactsViewModelProtocol {
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    weak var view: ContactsViewProtocol?
    /// The chosen address. The screen closes itself first.
    var completion: ((String) -> Void)?
    private let ownAddress: String
    private let isValid: (String) -> Bool
    private(set) var items: [SoramitsuTableViewItemProtocol] = []

    init(ownAddress: String, isValid: @escaping (String) -> Bool) {
        self.ownAddress = ownAddress
        self.isValid = isValid
    }

    func viewDidLoad() {
        show([])
    }

    func search(_ pattern: String) {
        let address = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !address.isEmpty else {
            show([])
            return
        }
        guard isValid(address) else {
            show([ContactHeaderCellItem(
                title: R.string.localizable.addressNotFound1(preferredLanguages: .currentLocale).uppercased())])
            return
        }
        let header = R.string.localizable.contactsSearchResults(preferredLanguages: .currentLocale).uppercased()
        show([
            ContactHeaderCellItem(title: header),
            ContactCellItem(title: address, image: NexusSora2Presentation.recipientImage) { [weak self] in
                self?.select(address)
            },
            ContactFooterItem()
        ])
    }

    func openQR() {
        guard let controller = view?.controller else { return }
        let scanner = WalletAddressScanner { [weak self] value in
            let address = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let self else { return }
            if self.isValid(address), address != self.ownAddress {
                self.select(address)
            } else {
                (self.view?.controller as? ContactsViewController)?.field.sora.text = address
                self.search(address)
            }
        }
        controller.present(UINavigationController(rootViewController: scanner), animated: true)
    }

    func select(_ address: String) {
        guard address != ownAddress else {
            view?.show(error: R.string.localizable.invoiceScanErrorMatch(preferredLanguages: .currentLocale))
            return
        }
        guard let controller = view?.controller else {
            completion?(address)
            return
        }
        controller.dismiss(animated: true) { [weak self] in
            self?.completion?(address)
        }
    }

    private func show(_ items: [SoramitsuTableViewItemProtocol]) {
        self.items = items
        setupItems?(items)
    }
}

// MARK: - Enter amount (SORA2's InputAssetAmountViewController)

final class NexusInputAmountViewModel: InputAssetAmountViewModelProtocol {
    weak var view: InputAssetAmountViewController?
    var inputedFirstAmount: Decimal = 0 {
        didSet { updateButton() }
    }
    private(set) var recipient = ""
    private(set) var balance: String
    var isBusy = false {
        didSet { updateButton() }
    }
    /// Once a send may have reached the network, this screen sends nothing more.
    var isLocked = false {
        didSet { updateButton() }
    }
    var onReview: ((String, String) -> Void)?
    var onSelectRecipient: (() -> Void)?
    /// The warning the screen shows, if any.
    private(set) var warning: String?
    private let xorImage: UIImage?

    init(balance: String, xorImage: UIImage?) {
        self.balance = balance
        self.xorImage = xorImage
    }

    func viewDidLoad() {
        guard let view else { return }
        view.updateFirstAsset(symbol: "XOR", image: xorImage)
        view.assetView.sora.assetArrow = nil
        view.updateFirstAsset(fiatText: "")
        update(balance: balance)
        view.setupButton(isEnabled: false)
        show(recipient: recipient)
    }

    func update(balance: String) {
        self.balance = balance
        view?.updateFirstAsset(balance: balance)
    }

    func set(recipient: String) {
        self.recipient = recipient
        show(recipient: recipient)
        hideWarning()
        updateButton()
        view?.focusFirstField()
    }

    /// The amount as typed, with a "." decimal separator. The network reads
    /// exact decimals, so the text is never rounded through a number.
    var amountText: String {
        let input = (view?.assetView.textField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let separator = Locale.current.decimalSeparator ?? "."
        let grouping = Locale.current.groupingSeparator ?? ","
        let ungrouped = grouping == separator ? input : input.replacingOccurrences(of: grouping, with: "")
        return separator == "." ? ungrouped : ungrouped.replacingOccurrences(of: separator, with: ".")
    }

    func choiceBaseAssetButtonTapped() {}

    func selectAddress() {
        guard !isBusy, !isLocked else { return }
        onSelectRecipient?()
    }

    func reviewButtonTapped() {
        guard !isBusy, !isLocked else { return }
        let amount = amountText
        guard !recipient.isEmpty, !amount.isEmpty else {
            showWarning(WalletUX.text("Enter a recipient address and the amount you want to send."))
            return
        }
        hideWarning()
        onReview?(recipient, amount)
    }

    func didSelect(variant: Decimal) {
        guard !isBusy, !isLocked, let total = Decimal(string: balance, locale: Locale(identifier: "en_US_POSIX")) else { return }
        let scale = balance.split(separator: ".").dropFirst().first?.count ?? 0
        var value = total * variant
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, scale, .down)
        let formatter = NumberFormatter()
        formatter.locale = Locale.current
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = scale
        let text = formatter.string(from: rounded as NSDecimalNumber) ?? ""
        view?.assetView.textField.sora.text = text
        inputedFirstAmount = rounded
    }

    func showWarning(_ message: String) {
        warning = message
        view?.updateWarinignView(model: WarningViewModel(
            descriptionText: message, isHidden: false,
            containterBackgroundColor: .statusErrorContainer, contentColor: .statusError))
    }

    func hideWarning() {
        warning = nil
        view?.updateWarinignView(model: WarningViewModel(
            descriptionText: "", isHidden: true,
            containterBackgroundColor: .statusErrorContainer, contentColor: .statusError))
    }

    private func show(recipient: String) {
        guard let view else { return }
        view.updateRecipientView(with: recipient)
        if !recipient.isEmpty {
            view.recipientView.contactView.accountImageView.image = NexusSora2Presentation.recipientImage
        }
    }

    private func updateButton() {
        let ready = !isBusy && !isLocked && !recipient.isEmpty && inputedFirstAmount > 0
        view?.setupButton(isEnabled: ready)
    }
}

// MARK: - Confirm sending (SORA2's ConfirmViewController)

final class NexusConfirmSendViewModel: ConfirmViewModelProtocol {
    var setupItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    var reloadItems: (([SoramitsuTableViewItemProtocol]) -> Void)?
    weak var view: ConfirmViewProtocol?
    let prepared: NexusPreparedTransfer
    let total: String
    var onConfirm: ((NexusPreparedTransfer) -> Void)?
    private let network: String
    private let xorAsset: AssetInfo?
    private(set) var items: [SoramitsuTableViewItemProtocol] = []
    private(set) var confirmItem: SoramitsuButtonItem?
    private(set) var notice: String?
    var isBusy = false {
        didSet { render() }
    }
    /// A confirmation is used once: after it was tapped, or after the send
    /// failed or may have started, it never sends again.
    private(set) var isUsed = false

    var title: String? { R.string.localizable.confirmSending(preferredLanguages: .currentLocale) }
    var imageName: String? { nil }

    init(prepared: NexusPreparedTransfer, total: String, network: String, xorAsset: AssetInfo?) {
        self.prepared = prepared
        self.total = total
        self.network = network
        self.xorAsset = xorAsset
    }

    func viewDidLoad() {
        render()
    }

    func show(notice: String) {
        self.notice = notice
        render()
    }

    func confirm() {
        guard !isBusy, !isUsed else { return }
        isUsed = true
        render()
        onConfirm?(prepared)
    }

    func markUsed() {
        isUsed = true
        render()
    }

    private func detail(_ title: String, _ value: String) -> DetailViewModel {
        DetailViewModel(title: title, assetAmountText: SoramitsuTextItem(text: value, fontData: FontType.textS,
                                                                         textColor: .fgPrimary, alignment: .right))
    }

    private func render() {
        let sendAsset = SendAssetItem(imageViewModel: WalletSvgImageViewModel(svgString: xorAsset?.icon ?? ""),
                                      symbol: "XOR",
                                      amount: prepared.request.amount.rawValue,
                                      balance: prepared.availableBalance.rawValue,
                                      fiat: "")
        let details = ConfirmDetailsItem(detailViewModels: [
            detail(WalletUX.text("Network"), network),
            detail(R.string.localizable.networkFee(preferredLanguages: .currentLocale), "\(prepared.quote.fee.rawValue) XOR"),
            detail(WalletUX.text("Total including fee"), "\(total) XOR")
        ])
        let enabled = !isBusy && !isUsed
        let buttonText = SoramitsuTextItem(text: R.string.localizable.commonConfirm(preferredLanguages: .currentLocale),
                                           fontData: FontType.buttonM,
                                           textColor: enabled ? .bgSurface : .fgSecondary,
                                           alignment: .center)
        let button = SoramitsuButtonItem(title: buttonText, isEnable: enabled) { [weak self] in
            self?.confirm()
        }
        confirmItem = button
        var items: [SoramitsuTableViewItemProtocol] = [
            RecipientAddressItem(address: prepared.canonicalReceiver, image: NexusSora2Presentation.recipientImage),
            SoramitsuTableViewSpacerItem(space: 16, color: .custom(uiColor: .clear)),
            sendAsset,
            SoramitsuTableViewSpacerItem(space: 16, color: .custom(uiColor: .clear)),
            details,
            SoramitsuTableViewSpacerItem(space: 16, color: .custom(uiColor: .clear))
        ]
        if let notice {
            items.append(WalletInlineNoticeItem(notice))
        }
        items.append(button)
        self.items = items
        setupItems?(items)
    }
}

// MARK: - Send flow

/// Sends XOR on a network through SORA2's send screens: Select recipient,
/// Enter amount, Confirm sending, then the transaction's details. Entry and
/// review share one draft; going back from the review drops its quote.
@MainActor
final class NexusSendFlow {
    var onReview: ((String, String) -> Void)?
    var onConfirm: ((NexusPreparedTransfer) -> Void)?
    /// The flow closed after a result: show the network's activity.
    var onActivity: (() -> Void)?

    let network: String
    private let configuration: NexusNetworkConfiguration
    private let ownAddress: String
    private let xorAsset: AssetInfo?
    private let xorImage: UIImage?
    private(set) var completed = false
    private(set) var busy = false
    let amountViewModel: NexusInputAmountViewModel
    private(set) var amountController: InputAssetAmountViewController?
    private(set) var recipientViewModel: NexusRecipientSearchViewModel?
    private(set) var confirmViewModel: NexusConfirmSendViewModel?
    private(set) var resultViewModel: NexusActivityDetailsViewModel?
    private(set) weak var container: UIViewController?
    private weak var navigation: UINavigationController?
    private var spinner: UIView?

    init(network: String, balance: String, configuration: NexusNetworkConfiguration,
         ownAddress: String, xorAsset: AssetInfo?) {
        self.network = network
        self.configuration = configuration
        self.ownAddress = ownAddress
        self.xorAsset = xorAsset
        let image = NexusSora2Presentation.xorImage(xorAsset)
        self.xorImage = image
        self.amountViewModel = NexusInputAmountViewModel(balance: balance, xorImage: image)
        amountViewModel.onReview = { [weak self] receiver, amount in
            self?.review(receiver: receiver, amount: amount)
        }
        amountViewModel.onSelectRecipient = { [weak self] in
            self?.showRecipientSearch()
        }
    }

    var isPresented: Bool { container?.presentingViewController != nil }

    /// Opens Enter amount; with no recipient yet, Select recipient opens on
    /// top of it, as in SORA2's send.
    func present(from presenter: UIViewController) {
        let navigation = makeNavigation()
        guard let controller = amountController else { return }
        NexusSora2Presentation.present(controller, from: presenter, navigation: navigation) { [weak self] in
            guard let self, self.amountViewModel.recipient.isEmpty else { return }
            self.showRecipientSearch()
        }
        container = navigation.parent
    }

    /// Enter amount in its navigation controller, which the caller keeps.
    func makeNavigation() -> UINavigationController {
        let controller = InputAssetAmountViewController(viewModel: amountViewModel)
        amountViewModel.view = controller
        amountController = controller
        let navigation = UINavigationController(rootViewController: controller)
        navigation.addCustomTransitioning()
        self.navigation = navigation
        return navigation
    }

    func showRecipientSearch() {
        guard !busy, !completed, let presenter = amountController else { return }
        let viewModel = NexusRecipientSearchViewModel(ownAddress: ownAddress) { [configuration] address in
            (try? configuration.validate(address: address)) != nil
        }
        viewModel.completion = { [weak self] address in
            self?.amountViewModel.set(recipient: address)
        }
        let controller = ContactsViewController(viewModel: viewModel)
        viewModel.view = controller
        recipientViewModel = viewModel
        let navigation = UINavigationController(rootViewController: controller)
        navigation.addCustomTransitioning()
        NexusSora2Presentation.present(controller, from: presenter, navigation: navigation)
    }

    private func review(receiver: String, amount: String) {
        guard !busy, !completed else { return }
        onReview?(receiver, amount)
    }

    func setBusy(_ busy: Bool) {
        self.busy = busy
        amountViewModel.isBusy = busy
        confirmViewModel?.isBusy = busy
        container?.isModalInPresentation = busy
        navigation?.topViewController?.navigationItem.rightBarButtonItem?.isEnabled = !busy
        navigation?.topViewController?.navigationItem.hidesBackButton = busy
        if busy {
            showSpinner()
        } else {
            spinner?.removeFromSuperview()
            spinner = nil
        }
    }

    /// SORA2's activity indicator, over the screen that waits.
    private func showSpinner() {
        guard spinner == nil, let host = navigation?.view else { return }
        let overlay = UIView(frame: host.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.05)
        overlay.accessibilityIdentifier = "nexus.send.busy"
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.startAnimating()
        overlay.addSubview(indicator)
        NSLayoutConstraint.activate([
            indicator.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
            indicator.centerYAnchor.constraint(equalTo: overlay.centerYAnchor)
        ])
        host.addSubview(overlay)
        spinner = overlay
    }

    /// An error of the draft or the review: the draft stays as it is.
    func showError(_ message: String) {
        setBusy(false)
        if let confirm = confirmViewModel, navigation?.topViewController is ConfirmViewController {
            confirm.show(notice: message)
        } else {
            amountViewModel.showWarning(message)
        }
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    /// Nothing was sent: back to the draft, which needs a new review.
    func showUnsentError(_ message: String) {
        setBusy(false)
        returnToDraft()
        amountViewModel.showWarning(message)
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    func showReview(_ transfer: NexusPreparedTransfer) {
        guard let total = WalletUX.total(amount: transfer.request.amount, fee: transfer.quote.fee) else {
            showUnsentError(WalletUX.text("The send total could not be verified. Review a new quote."))
            return
        }
        setBusy(false)
        guard !completed else { return }
        amountViewModel.update(balance: transfer.availableBalance.rawValue)
        let viewModel = NexusConfirmSendViewModel(prepared: transfer, total: total, network: network, xorAsset: xorAsset)
        viewModel.onConfirm = { [weak self] prepared in
            guard let self, !self.busy, !self.completed else { return }
            self.onConfirm?(prepared)
        }
        let controller = ConfirmViewController(viewModel: viewModel)
        viewModel.view = controller
        confirmViewModel = viewModel
        amountController?.view.endEditing(true)
        navigation?.pushViewController(controller, animated: true)
        UIAccessibility.post(notification: .screenChanged, argument: controller.view)
    }

    func showResult(_ transaction: NexusPendingTransaction) {
        setBusy(false)
        if transaction.state == .failedBeforeSubmission {
            showUnsentError(WalletUX.statusDetail(transaction.state))
            return
        }
        finish(with: NexusActivityDetailsViewModel.Model(
            title: TransferTransaction.TransferType.outcoming.detailsTitle,
            incoming: false, amount: transaction.amount.rawValue,
            status: NexusSora2Presentation.status(of: transaction.state),
            statusText: WalletUX.status(transaction.state), date: transaction.updatedAt,
            fee: transaction.fee.rawValue, transactionId: transaction.hash,
            sender: transaction.sender, recipient: transaction.receiver,
            note: WalletUX.statusDetail(transaction.state)))
    }

    /// The send may already be processing: only its activity is offered.
    func showUncertainSubmission(_ message: String) {
        setBusy(false)
        let prepared = confirmViewModel?.prepared
        finish(with: NexusActivityDetailsViewModel.Model(
            title: TransferTransaction.TransferType.outcoming.detailsTitle,
            incoming: false, amount: prepared?.request.amount.rawValue,
            status: .pending, statusText: WalletUX.status(.submissionUnknown), date: Date(),
            fee: prepared?.quote.fee.rawValue, transactionId: nil,
            sender: nil, recipient: prepared?.canonicalReceiver,
            note: message))
    }

    private func finish(with model: NexusActivityDetailsViewModel.Model) {
        completed = true
        amountViewModel.isLocked = true
        confirmViewModel?.markUsed()
        let viewModel = NexusActivityDetailsViewModel(model: model, xorImage: xorImage)
        resultViewModel = viewModel
        viewModel.completion = { [weak self] in
            guard let self else { return }
            self.container?.dismiss(animated: true) { [weak self] in
                self?.onActivity?()
            }
        }
        let controller = ActivityDetailsViewController(viewModel: viewModel)
        viewModel.view = controller
        if let top = navigation?.topViewController {
            NexusSora2Presentation.presentDetails(controller, from: top)
        }
        UIAccessibility.post(notification: .screenChanged, argument: controller.view)
    }

    private func returnToDraft() {
        guard !completed else { return }
        confirmViewModel?.markUsed()
        confirmViewModel = nil
        if let amountController, navigation?.topViewController !== amountController {
            navigation?.popToViewController(amountController, animated: true)
        }
    }
}
