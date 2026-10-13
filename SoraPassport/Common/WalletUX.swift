// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import AVFoundation
import BigInt
import SoraFoundation
import SoraUIKit
import UIKit

enum WalletUX {
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
            if result != value { return result }
        }
        return value
    }

    static func format(_ value: String, _ arguments: CVarArg...) -> String {
        String(format: text(value), arguments: arguments)
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

    static func button(_ title: String, primary: Bool = false, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        var configuration = primary ? UIButton.Configuration.filled() : .plain()
        configuration.title = text(title)
        configuration.baseBackgroundColor = accent
        configuration.baseForegroundColor = primary ? surface : accent
        configuration.cornerStyle = .capsule
        configuration.titleAlignment = .center
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFontMetrics(forTextStyle: .headline).scaledFont(for: FontType.headline2.font)
            return attributes
        }
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 18, bottom: 14, trailing: 18)
        button.configuration = configuration
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.textAlignment = .center
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
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

/// Shared native table treatment for portfolio and market destinations.
class WalletTableViewController: UITableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = WalletUX.page
        view.tintColor = WalletUX.accent
        tableView.estimatedRowHeight = 72
        tableView.rowHeight = UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = WalletUX.surface
        cell.tintColor = WalletUX.accent
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
