// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import AVFoundation
import BigInt
import SoraFoundation
import SoraUIKit
import UIKit

enum WalletUX {
    /// SORA Neon tokens for the theme being shown.
    static var tokens: NeonTokens { NeonTokens.current }
    static var page: UIColor { SoramitsuUI.shared.theme.palette.color(.bgPage) }
    static var surface: UIColor { SoramitsuUI.shared.theme.palette.color(.bgSurface) }
    static var accent: UIColor { SoramitsuUI.shared.theme.palette.color(.accentPrimary) }
    static var foreground: UIColor { SoramitsuUI.shared.theme.palette.color(.fgPrimary) }
    static var secondary: UIColor {
        let candidate = SoramitsuUI.shared.theme.palette.color(.fgSecondary)
        return contrast(candidate, page) >= 4.5 && contrast(candidate, surface) >= 4.5 ? candidate : foreground
    }

    static func text(_ value: String, language: String? = nil, bundle: Bundle = .main) -> String {
        let selected = language ?? LocalizationManager.shared.selectedLocalization
        for locale in [selected, "en"] {
            guard let path = bundle.path(forResource: locale, ofType: "lproj"),
                  let localized = Bundle(path: path) else { continue }
            let result = localized.localizedString(forKey: value, value: value, table: "Localizable")
            if !result.isEmpty && result != value { return result }
        }
        return value
    }

    static func format(_ value: String, _ arguments: CVarArg...) -> String {
        String(format: text(value), arguments: arguments)
    }

    /// Shown in place of a fiat total while no price is known.
    static var priceUnavailableText: String { text("Price unavailable") }

    /// A fiat total for display. Without prices the total is unknown, not
    /// zero: a wallet that holds tokens must never read "$0" because the
    /// price service could not be reached.
    static func fiatTotalText(_ total: Decimal, pricesAvailable: Bool) -> String {
        guard pricesAvailable else { return priceUnavailableText }
        return "$" + (NumberFormatter.fiat.stringFromDecimal(total) ?? "")
    }

    /// "Prices as of 09:02" (with the date when it is not today): shown
    /// next to a total valued with the last prices PI could give, while PI
    /// cannot be read.
    static func pricesAsOfText(
        _ date: Date,
        now: Date = Date(),
        language: String? = nil,
        calendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) -> String {
        var calendar = calendar
        calendar.timeZone = timeZone
        let formatter = DateFormatter()
        formatter.locale = Locale(
            identifier: language ?? LocalizationManager.shared.selectedLocalization
        )
        formatter.timeZone = timeZone
        formatter.timeStyle = .short
        formatter.dateStyle = calendar.isDate(date, inSameDayAs: now) ? .none : .medium
        return String(
            format: text("Prices as of %@", language: language),
            formatter.string(from: date)
        )
    }

    /// The fiat value of `amount` at `price`, or no text at all when the
    /// price is not known. A missing price is never shown as "$0".
    static func fiatText(amount: Decimal, price: Decimal?, prefix: String = "$") -> String {
        guard let price else { return "" }
        return prefix + (NumberFormatter.fiat.stringFromDecimal(amount * price) ?? "")
    }

    /// The same for a balance row, where a value below one cent reads
    /// "<$0.01" and a real zero reads "$0".
    static func balanceFiatText(amount: Decimal, price: Decimal?) -> String {
        guard let price else { return "" }
        return (amount * price).priceText()
    }

    /// How long a wallet total without prices waits before asking again:
    /// 20 s, then twice as long each time, up to 5 minutes. The price
    /// service applies its own backoff, so asking is cheap.
    static func priceRetryDelay(afterFailures failures: Int) -> TimeInterval {
        min(300, 20 * pow(2, Double(max(0, min(failures, 8)))))
    }

    static func contrast(_ first: UIColor, _ second: UIColor) -> CGFloat {
        func luminance(_ color: UIColor) -> CGFloat {
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return 0 }
            func linear(_ value: CGFloat) -> CGFloat {
                value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        }
        let a = luminance(first), b = luminance(second)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    static func readableAttributedText(_ text: NSAttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString(attributedString: text)
        text.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: text.length)) { color, range, _ in
            guard let color = color as? UIColor,
                  contrast(color, page) < 4.5 || contrast(color, surface) < 4.5 else { return }
            result.addAttribute(.foregroundColor, value: foreground, range: range)
        }
        return result
    }

    /// Presentation uses the same exact decimal arithmetic as send validation.
    static func total(amount: PIQuantity, fee: PIQuantity) -> String? {
        guard let amount = NexusExactDecimal(amount.rawValue), let fee = NexusExactDecimal(fee.rawValue),
              amount.unscaled >= 0, fee.unscaled >= 0 else { return nil }
        let sum = amount + fee
        let digits = String(sum.unscaled)
        guard sum.scale > 0 else { return digits }
        let padded = String(repeating: "0", count: max(0, sum.scale + 1 - digits.count)) + digits
        let point = padded.index(padded.endIndex, offsetBy: -sum.scale)
        return String(padded[..<point]) + "." + String(padded[point...])
    }

    static func font(_ style: UIFont.TextStyle = .body) -> UIFont {
        let base = style == .title2 ? FontType.headline1.font :
            (style == .headline ? FontType.headline2.font : FontType.textM.font)
        return UIFontMetrics(forTextStyle: style).scaledFont(for: base)
    }

    static func label(_ text: String = "", style: UIFont.TextStyle = .body) -> UILabel {
        let label = UILabel()
        label.text = text
        label.numberOfLines = 0
        label.font = font(style)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = foreground
        return label
    }

    /// Button font: Sora SemiBold 16, scaled with Dynamic Type up to 26 pt.
    static var buttonFont: UIFont {
        UIFontMetrics(forTextStyle: .body).scaledFont(for: FontType.buttonM.font, maximumPointSize: 26)
    }

    /// `primary` is the neon CTA; otherwise a glass secondary button.
    static func button(_ title: String, primary: Bool = false, action: @escaping () -> Void) -> UIButton {
        button(title, style: primary ? .primary : .secondary, action: action)
    }

    static func button(_ title: String, style: WalletButtonStyle, action: @escaping () -> Void) -> UIButton {
        let button = WalletNeonButton(style: style)
        // Only the configuration title: callers update it later through
        // `configuration?.title`, which a `setTitle(_:for:)` value would override.
        button.configuration?.title = text(title)
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    /// Sets a fixed title on a configuration button and in its state table,
    /// so `title(for: .normal)` reads it back.
    static func setTitle(_ title: String, on button: UIButton) {
        button.setTitle(title, for: .normal)
        if button.configuration != nil {
            button.configuration?.title = title
        }
    }

    static func sendError(_ error: Error) -> String {
        guard let error = error as? NexusToriiError else {
            return text("This send could not be completed. Check Activity before starting another transfer.")
        }
        switch error {
        case .insufficientBalance:
            return text("You need enough XOR for both the amount and the network fee. Reduce the amount or receive more XOR.")
        case .quoteChanged, .quoteExpired:
            return text("The network fee changed. Edit this send and review the updated fee.")
        case .wrongWalletOrNetwork:
            return text("Your account or network changed. Close this screen and start from the account you want to use.")
        case .ambiguousSubmission, .confirmationAlreadySubmitted, .transactionHashMismatch:
            return text("The send may already be processing. Check Activity before starting another transfer.")
        case .sendsDisabled, .nativeBridgeUnavailable, .finalizedHeadUnavailable:
            return text("Sending is unavailable on this network right now. You can still receive funds and check Activity.")
        default:
            return text("This network is unavailable. Check your connection and try refreshing your balance.")
        }
    }

    static func sendOutcomeNeedsChecking(_ error: Error, submissionMayHaveStarted: Bool? = nil) -> Bool {
        if let error = error as? NexusToriiError, case .confirmationAlreadySubmitted = error { return true }
        if let submissionMayHaveStarted { return submissionMayHaveStarted }
        guard let error = error as? NexusToriiError else { return true }
        switch error {
        case .insufficientBalance, .quoteChanged, .quoteExpired, .wrongWalletOrNetwork,
             .nativeBridgeUnavailable, .finalizedHeadUnavailable, .sendsDisabled:
            return false
        default:
            // Transport/response errors may be rethrown after submission.
            // Their error type cannot prove that nothing was sent.
            return true
        }
    }

    static func status(_ state: NexusPendingState) -> String {
        switch state {
        case .signing: return text("Awaiting signature")
        case .failedBeforeSubmission: return text("Not sent")
        case .submitting: return text("Sending")
        case .submissionUnknown: return text("Checking send status")
        case .submitted, .approved: return text("Awaiting confirmation")
        case .committedPendingReconciliation: return text("Updating balance")
        case .committed: return text("Completed")
        case .rejected: return text("Rejected by network")
        case .expired: return text("Expired")
        }
    }

    static func statusDetail(_ state: NexusPendingState) -> String {
        switch state {
        case .committed: return text("Your transfer is complete.")
        case .failedBeforeSubmission: return text("Nothing was sent. You can edit the details and review a new send.")
        case .rejected: return text("The network rejected this transfer. Check Activity for details before trying again.")
        case .expired: return text("This transfer expired. Check Activity before reviewing a new send.")
        default: return text("Your wallet is checking this transfer. Follow its progress in Activity; do not send it again.")
        }
    }
}

/// Shared native table treatment for portfolio and market destinations:
/// the aurora behind, glass rows (no blur in cells), Neon dividers.
class WalletTableViewController: UITableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = WalletUX.page
        view.tintColor = WalletUX.tokens.cyan
        tableView.backgroundView = AuroraView(style: .standard)
        tableView.separatorColor = WalletUX.tokens.divider
        tableView.estimatedRowHeight = 72
        tableView.rowHeight = UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        var background = tableView.style == .plain ? UIBackgroundConfiguration.listPlainCell()
                                                   : UIBackgroundConfiguration.listGroupedCell()
        background.backgroundColor = FxPolicy.current.opaqueGlass ? WalletUX.tokens.glassSolid : WalletUX.tokens.cardFill
        cell.backgroundConfiguration = background
        cell.tintColor = WalletUX.tokens.cyan
        if var content = cell.contentConfiguration as? UIListContentConfiguration {
            content.textProperties.color = WalletUX.foreground
            content.textProperties.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: FontType.textM.font)
            content.secondaryTextProperties.color = WalletUX.secondary
            content.secondaryTextProperties.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: FontType.textS.font)
            cell.contentConfiguration = content
        } else {
            cell.textLabel?.textColor = WalletUX.foreground
            cell.textLabel?.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: FontType.textM.font)
            cell.detailTextLabel?.textColor = WalletUX.secondary
            cell.textLabel?.adjustsFontForContentSizeCategory = true
            cell.detailTextLabel?.adjustsFontForContentSizeCategory = true
        }
    }
}

final class WalletInlineNoticeItem: NSObject, SoramitsuTableViewItemProtocol {
    let message: String
    init(_ message: String) { self.message = message }
    var cellType: AnyClass { WalletInlineNoticeCell.self }
}

final class WalletInlineNoticeCell: SoramitsuTableViewCell, SoramitsuTableViewCellProtocol {
    private let label = WalletUX.label()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        label.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    func set(item: SoramitsuTableViewItemProtocol, context: SoramitsuTableViewContext?) {
        label.text = (item as? WalletInlineNoticeItem)?.message
    }
}

/// Entry and review share one draft; changing details invalidates the old quote.
final class NexusSendViewController: UIViewController {
    var onReview: ((String, String) -> Void)?
    var onConfirm: ((NexusPreparedTransfer) -> Void)?
    var onActivity: (() -> Void)?
    private let network: String
    private let balance: String
    private lazy var availableLabel = WalletUX.label(WalletUX.format("Available: %@ XOR", balance))
    private let recipient = UITextView()
    private let amount = UITextField()
    private let entry = UIStackView()
    private let review = UIStackView()
    private let addressActions = UIStackView()
    private let notice = WalletUX.label()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private var prepared: NexusPreparedTransfer?
    private var completed = false
    private var busy = false
    private lazy var primary = WalletUX.button("Review send", primary: true) { [weak self] in self?.proceed() }
    private lazy var edit = WalletUX.button("Edit details") { [weak self] in self?.editDraft() }
    private lazy var activity = WalletUX.button("View Activity", primary: true) { [weak self] in
        self?.dismiss(animated: true) { self?.onActivity?() }
    }

    init(network: String, balance: String) {
        self.network = network
        self.balance = balance
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = WalletUX.text("Send XOR")
        view.backgroundColor = WalletUX.page
        view.tintColor = WalletUX.accent
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
        let scroll = UIScrollView()
        scroll.keyboardDismissMode = .interactive
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        let content = UIStackView()
        content.axis = .vertical
        content.spacing = 24
        content.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(content)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            content.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 24),
            content.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -24),
            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 24),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            content.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -48)
        ])
        content.addArrangedSubview(WalletUX.label(network, style: .headline))
        content.addArrangedSubview(availableLabel)
        entry.axis = .vertical
        entry.spacing = 12
        entry.addArrangedSubview(WalletUX.label(WalletUX.text("Recipient address")))
        recipient.backgroundColor = WalletUX.surface
        recipient.textColor = WalletUX.foreground
        recipient.font = UIFont.preferredFont(forTextStyle: .body)
        recipient.adjustsFontForContentSizeCategory = true
        recipient.layer.cornerRadius = 12
        recipient.textContainerInset = UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)
        recipient.autocapitalizationType = .none
        recipient.autocorrectionType = .no
        recipient.isScrollEnabled = false
        recipient.accessibilityLabel = WalletUX.text("Recipient address")
        recipient.heightAnchor.constraint(greaterThanOrEqualToConstant: 88).isActive = true
        entry.addArrangedSubview(recipient)
        [
            WalletUX.button("Paste address") { [weak self] in
                guard let value = UIPasteboard.general.string, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    self?.showError(WalletUX.text("The clipboard does not contain an address.")); return
                }
                self?.recipient.text = value
            },
            WalletUX.button("Scan QR") { [weak self] in self?.scan() }
        ].forEach { addressActions.addArrangedSubview($0) }
        addressActions.distribution = .fillEqually
        addressActions.axis = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? .vertical : .horizontal
        entry.addArrangedSubview(addressActions)
        entry.addArrangedSubview(WalletUX.label(WalletUX.text("Use a receive address from this same network."), style: .subheadline))
        entry.addArrangedSubview(WalletUX.label(WalletUX.text("Amount in XOR")))
        amount.borderStyle = .roundedRect
        amount.backgroundColor = WalletUX.surface
        amount.textColor = WalletUX.foreground
        amount.font = .preferredFont(forTextStyle: .title2)
        amount.adjustsFontForContentSizeCategory = true
        amount.keyboardType = .decimalPad
        amount.placeholder = "0"
        amount.accessibilityLabel = WalletUX.text("Amount in XOR")
        amount.heightAnchor.constraint(greaterThanOrEqualToConstant: 56).isActive = true
        entry.addArrangedSubview(amount)
        entry.addArrangedSubview(WalletUX.label(WalletUX.text("The network fee is shown before you confirm."), style: .subheadline))
        review.axis = .vertical
        review.spacing = 16
        review.isHidden = true
        edit.isHidden = true
        activity.isHidden = true
        notice.isHidden = true
        spinner.hidesWhenStopped = true
        [entry, review, notice, spinner, primary, edit, activity].forEach { content.addArrangedSubview($0) }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        addressActions.axis = traitCollection.preferredContentSizeCategory.isAccessibilityCategory ? .vertical : .horizontal
    }

    func setBusy(_ busy: Bool) {
        self.busy = busy
        primary.isEnabled = !busy
        edit.isEnabled = !busy
        entry.isUserInteractionEnabled = !busy
        navigationItem.leftBarButtonItem?.isEnabled = !busy
        isModalInPresentation = busy
        busy ? spinner.startAnimating() : spinner.stopAnimating()
    }

    func showError(_ message: String) {
        setBusy(false)
        notice.text = message
        notice.isHidden = false
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    func showUnsentError(_ message: String) {
        setBusy(false)
        editDraft()
        showError(message)
    }

    func showReview(_ transfer: NexusPreparedTransfer) {
        guard let total = WalletUX.total(amount: transfer.request.amount, fee: transfer.quote.fee) else {
            showUnsentError(WalletUX.text("The send total could not be verified. Review a new quote.")); return
        }
        setBusy(false)
        prepared = transfer
        availableLabel.text = WalletUX.format("Available: %@ XOR", transfer.availableBalance.rawValue)
        view.endEditing(true)
        clearReview()
        for (name, value) in [(WalletUX.text("You send"), "\(transfer.request.amount.rawValue) XOR"),
                              (WalletUX.text("Network fee"), "\(transfer.quote.fee.rawValue) XOR"),
                              (WalletUX.text("Total including fee"), "\(total) XOR"),
                              (WalletUX.text("Recipient"), transfer.canonicalReceiver)] {
            let title = WalletUX.label(name, style: .subheadline)
            title.textColor = WalletUX.secondary
            review.addArrangedSubview(title)
            let detail = WalletUX.label(value, style: .headline)
            detail.lineBreakMode = .byCharWrapping
            review.addArrangedSubview(detail)
        }
        entry.isHidden = true
        notice.isHidden = true
        review.isHidden = false
        edit.isHidden = false
        primary.configuration?.title = WalletUX.text("Confirm and send")
        UIAccessibility.post(notification: .screenChanged, argument: review)
    }

    func showResult(_ transaction: NexusPendingTransaction) {
        setBusy(false)
        if transaction.state == .failedBeforeSubmission {
            editDraft()
            showError(WalletUX.statusDetail(transaction.state))
            return
        }
        completed = true
        availableLabel.isHidden = true
        clearReview()
        review.addArrangedSubview(WalletUX.label(WalletUX.status(transaction.state), style: .headline))
        review.addArrangedSubview(WalletUX.label(WalletUX.statusDetail(transaction.state)))
        if let hash = transaction.hash {
            review.addArrangedSubview(WalletUX.button("Copy transaction ID") { UIPasteboard.general.string = hash })
        }
        entry.isHidden = true
        review.isHidden = false
        primary.isHidden = true
        edit.isHidden = true
        notice.isHidden = true
        activity.isHidden = false
        UIAccessibility.post(notification: .screenChanged, argument: review)
    }

    func showUncertainSubmission(_ message: String) {
        setBusy(false)
        completed = true
        availableLabel.isHidden = true
        notice.text = message
        notice.isHidden = false
        entry.isHidden = true
        primary.isHidden = true
        edit.isHidden = true
        activity.isHidden = false
        UIAccessibility.post(notification: .screenChanged, argument: notice)
    }

    private func clearReview() {
        review.arrangedSubviews.forEach { review.removeArrangedSubview($0); $0.removeFromSuperview() }
    }
    private func editDraft() {
        guard !completed, !busy else { return }
        prepared = nil
        entry.isHidden = false
        review.isHidden = true
        edit.isHidden = true
        notice.isHidden = true
        primary.configuration?.title = WalletUX.text("Review send")
        UIAccessibility.post(notification: .screenChanged, argument: recipient)
    }
    private func proceed() {
        guard !completed, !busy else { return }
        if let prepared { onConfirm?(prepared); return }
        let receiver = recipient.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let input = (amount.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let separator = Locale.current.decimalSeparator ?? "."
        let value = separator == "." ? input : input.replacingOccurrences(of: separator, with: ".")
        guard !receiver.isEmpty, !value.isEmpty else {
            showError(WalletUX.text("Enter a recipient address and the amount you want to send.")); return
        }
        onReview?(receiver, value)
    }
    private func scan() {
        let scanner = WalletAddressScanner { [weak self] value in self?.recipient.text = value }
        present(UINavigationController(rootViewController: scanner), animated: true)
    }
}

/// QR scanning only fills the draft. Network/address admission still happens at review.
private final class WalletAddressScanner: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "sora.wallet.qr-camera")
    private let completion: (String) -> Void
    private var preview: AVCaptureVideoPreviewLayer?
    private var received = false
    init(completion: @escaping (String) -> Void) {
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }
    override func viewDidLoad() {
        super.viewDidLoad()
        title = WalletUX.text("Scan receive address")
        view.backgroundColor = WalletUX.page
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) })
        AVCaptureDevice.requestAccess(for: .video) { [weak self] allowed in
            DispatchQueue.main.async {
                guard let self, self.view.window != nil else { return }
                allowed ? self.startCamera() : self.showUnavailable()
            }
        }
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preview?.frame = view.bounds
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        queue.async { [session] in session.stopRunning() }
    }
    private func startCamera() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
            showUnavailable(); return
        }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { showUnavailable(); return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        self.preview = preview
        view.setNeedsLayout()
        queue.async { [session] in session.startRunning() }
    }
    private func showUnavailable() {
        let label = WalletUX.label(WalletUX.text("Camera access is unavailable. Close this screen to paste the address, or enable Camera in Settings."))
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !received, let value = (metadataObjects.first as? AVMetadataMachineReadableCodeObject)?.stringValue else { return }
        received = true
        dismiss(animated: true) { [completion] in completion(value) }
    }
}

// MARK: - SORA Neon buttons

/// Spec §7.1. One `.primary` (or `.safe`) per screen.
enum WalletButtonStyle {
    /// Neon CTA: `cta.primary` gradient, ink label in dark, `glow.primary`.
    case primary
    /// Glass: `glass.fill`, hairline border, `text.primary` label.
    case secondary
    /// Text: `accent.cyan` label.
    case tertiary
    /// Safe Mode CTA (recovery, backup, upgrade): mint-to-cyan, static glow,
    /// never pulses, never red.
    case safe
}

/// A `UIButton.Configuration` button in the SORA Neon styles. Re-styles on
/// theme changes and for disabled, pressed and reduced-effects states.
final class WalletNeonButton: UIButton {
    var neonStyle: WalletButtonStyle {
        didSet {
            if neonStyle != oldValue { setNeedsUpdateConfiguration() }
        }
    }
    private var glowSpec: GlowSpec?

    init(style: WalletButtonStyle) {
        neonStyle = style
        super.init(frame: .zero)
        var configuration: UIButton.Configuration = style == .tertiary ? .plain() : .filled()
        configuration.cornerStyle = .capsule
        configuration.titleAlignment = .center
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 15, leading: 20, bottom: 15, trailing: 20)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = WalletUX.buttonFont
            return attributes
        }
        self.configuration = configuration
        configurationUpdateHandler = { button in
            (button as? WalletNeonButton)?.applyNeonStyle()
        }
        titleLabel?.numberOfLines = 0
        titleLabel?.textAlignment = .center
        titleLabel?.adjustsFontForContentSizeCategory = true
        heightAnchor.constraint(greaterThanOrEqualToConstant: style == .tertiary ? 44 : 52).isActive = true
        layer.masksToBounds = false
        SoramitsuUI.updates.addObserver(self)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    private func applyNeonStyle() {
        guard var configuration else { return }
        let tokens = WalletUX.tokens
        let fx = FxPolicy.current
        var background = configuration.background
        background.customView = nil
        background.strokeWidth = 0
        background.strokeColor = nil
        glowSpec = nil
        switch neonStyle {
        case .primary, .safe:
            if isEnabled {
                let fill = NeonGradientView()
                fill.apply(neonStyle == .safe ? tokens.ctaSafe : tokens.ctaPrimary)
                background.customView = fill
                background.backgroundColor = .clear
                configuration.baseBackgroundColor = .clear
                configuration.baseForegroundColor = tokens.onAccent
                glowSpec = neonStyle == .safe ? tokens.glowSafe : tokens.glowPrimary
            } else {
                background.backgroundColor = tokens.ctaDisabled
                configuration.baseBackgroundColor = tokens.ctaDisabled
                configuration.baseForegroundColor = tokens.textDisabled
            }
        case .secondary:
            let fill = fx.opaqueGlass ? tokens.glassSolid : (isHighlighted ? tokens.glassFillPressed : tokens.glassFill)
            background.backgroundColor = fill
            configuration.baseBackgroundColor = fill
            background.strokeColor = isEnabled ? tokens.hairline : .clear
            background.strokeWidth = fx.highContrast ? 2 : 1
            configuration.baseForegroundColor = isEnabled ? tokens.textPrimary : tokens.textDisabled
        case .tertiary:
            background.backgroundColor = isHighlighted ? tokens.cyan.withAlphaComponent(0.10) : .clear
            configuration.baseForegroundColor = isEnabled ? tokens.link : tokens.textDisabled
        }
        configuration.background = background
        self.configuration = configuration
        applyGlow(fx: fx)
        if !fx.reduceMotion, neonStyle != .tertiary {
            let scale: CGFloat = isHighlighted ? 0.98 : 1
            UIView.animate(withDuration: isHighlighted ? NeonMotion.press : NeonMotion.fast, delay: 0,
                           options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.transform = CGAffineTransform(scaleX: scale, y: scale)
            }
        }
    }

    private func applyGlow(fx: FxPolicy) {
        guard let glowSpec, fx.glows, fx.tier != .minimal else {
            layer.shadowOpacity = 0
            return
        }
        layer.applyNeonGlow(glowSpec, path: UIBezierPath(roundedRect: bounds, cornerRadius: bounds.height / 2).cgPath,
                            alpha: isHighlighted ? glowSpec.pressed : glowSpec.rest)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if layer.shadowOpacity > 0 {
            layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: bounds.height / 2).cgPath
        }
    }
}

extension WalletNeonButton: SoramitsuObserver {
    func styleDidChange(options: UpdateOptions) {
        if options.contains(.palette) { setNeedsUpdateConfiguration() }
    }
}

// MARK: - Safe Mode kit (spec §7.17, §9.4)

/// Building blocks for recovery, upgrade and other safety screens: the safe
/// aurora (cyan and mint, no red), a shield emblem, calm type and Safe
/// Mode buttons. Everything follows the app theme.
enum WalletSafeMode {
    /// Safe aurora behind a screen's content.
    static func installBackdrop(in view: UIView) {
        view.backgroundColor = WalletUX.page
        let aurora = AuroraView(style: .safe)
        aurora.frame = view.bounds
        aurora.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.insertSubview(aurora, at: 0)
    }

    /// A glass circle with a mint ring and shield, and a static mint glow.
    static func shieldEmblem(size: CGFloat = 72) -> UIView {
        let tokens = WalletUX.tokens
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.isAccessibilityElement = false
        let glow = GlowHostView()
        glow.shape = .capsule
        let disc = GlassView()
        disc.shape = .capsule
        disc.fill = .strong
        disc.border = .safe
        let icon = UIImageView(image: UIImage(systemName: "checkmark.shield",
                                              withConfiguration: UIImage.SymbolConfiguration(pointSize: size * 0.42,
                                                                                             weight: .semibold)))
        icon.tintColor = tokens.success
        icon.contentMode = .center
        [glow, disc, icon].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview($0)
            NSLayoutConstraint.activate([
                $0.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                $0.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                $0.widthAnchor.constraint(equalToConstant: size),
                $0.heightAnchor.constraint(equalToConstant: size)
            ])
        }
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: size),
            container.heightAnchor.constraint(equalToConstant: size)
        ])
        glow.configure(tokens.glowSafe)
        return container
    }

    /// Wraps the emblem so it sits centred in a vertical stack.
    static func centered(_ view: UIView) -> UIView {
        let row = UIView()
        row.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.centerXAnchor.constraint(equalTo: row.centerXAnchor),
            view.topAnchor.constraint(equalTo: row.topAnchor, constant: 8),
            view.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -8)
        ])
        return row
    }

    /// Safe Mode title: `headline1`, `text.primary`, scales with Dynamic Type.
    static func title(_ label: UILabel, _ text: String) {
        label.text = text
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = UIFontMetrics(forTextStyle: .title2).scaledFont(for: FontType.headline1.font)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = WalletUX.tokens.textPrimary
        label.accessibilityTraits.insert(.header)
    }

    /// Body copy: `paragraphM`, `text.secondary`.
    static func body(_ label: UILabel, alignment: NSTextAlignment = .center) {
        label.numberOfLines = 0
        label.textAlignment = alignment
        label.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: FontType.paragraphM.font)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = WalletUX.tokens.textSecondary
    }

    /// Small status or detail line: `textS`, `text.secondary`.
    static func detail(_ label: UILabel, alignment: NSTextAlignment = .center) {
        label.numberOfLines = 0
        label.textAlignment = alignment
        label.font = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: FontType.textS.font)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = WalletUX.tokens.textSecondary
    }

    /// Technical details (codes, versions): platform monospace, tertiary.
    static func technical(_ label: UILabel) {
        label.numberOfLines = 0
        label.textAlignment = .natural
        label.font = UIFontMetrics(forTextStyle: .footnote).scaledFont(for: FontType.mono.font)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = WalletUX.tokens.textTertiary
    }

    /// A Safe Mode button replacing a plain system button. Keeps the title
    /// set through `setTitle(_:for:)` (and tests that read it).
    static func button(_ style: WalletButtonStyle, title: String) -> WalletNeonButton {
        let button = WalletNeonButton(style: style)
        WalletUX.setTitle(title, on: button)
        return button
    }
}

extension NSLayoutConstraint {
    /// The same constraint with another priority (for inline activation).
    func prioritized(_ priority: UILayoutPriority) -> NSLayoutConstraint {
        self.priority = priority
        return self
    }
}
