import UIKit
import CryptoKit
final class IrohaConnectViewController: UIViewController {
    private enum Action {
        case none
        case approve
        case sign
        case done
    }

    var onFinish: (() -> Void)?

    private let launch: IrohaConnectLaunch
    private let account: IrohaConnectWalletContext
    private let walletProvider: IrohaConnectWalletProvider
    private let engine: IrohaConnectSessionEngine
    private let authenticator = IrohaConnectAuthenticator()
    private let diagnosticView = UITextView()
    private lazy var detailsButton: UIButton = WalletUX.button("Technical details") { [weak self] in
        guard let self else { return }
        self.diagnosticView.isHidden.toggle()
        self.detailsButton.accessibilityValue = self.diagnosticView.isHidden ? WalletUX.text("Collapsed") : WalletUX.text("Expanded")
    }
    private let eyebrow = UILabel()
    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let detailView = UITextView()
    private let securityLabel = UILabel()
    private let primaryButton = UIButton(type: .system)
    private let secondaryButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private var socket: IrohaConnectWebSocket?
    private var expiryTimer: Timer?
    private var action: Action = .none
    private var connectedApp: IrohaConnectAppMetadata?
    private var didStart = false
    private var didFinish = false
    private var isTerminal = false

    init(
        launch: IrohaConnectLaunch,
        account: IrohaConnectWalletContext,
        walletProvider: IrohaConnectWalletProvider
    ) {
        self.launch = launch
        self.account = account
        self.walletProvider = walletProvider
        engine = IrohaConnectSessionEngine(launch: launch)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    deinit {
        expiryTimer?.invalidate()
        socket?.cancel()
    }


    override func viewDidLoad() {
        super.viewDidLoad()
        buildInterface()
        showConnecting()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didStart else { return }
        didStart = true
        startConnection()
    }

    func applicationDidEnterBackground() {
        finish(sendClose: true, reason: "Wallet moved to the background")
    }

    func showTransientMessage(_ message: String) {
        statusLabel.text = WalletUX.text(message)
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    private func buildInterface() {
        view.backgroundColor = WalletUX.page
        view.tintColor = WalletUX.accent
        eyebrow.text = WalletUX.text("SORA Wallet")
        eyebrow.textColor = WalletUX.secondary
        eyebrow.font = WalletUX.font(.subheadline)
        eyebrow.adjustsFontForContentSizeCategory = true
        titleLabel.text = WalletUX.text("Connect an app")
        titleLabel.textColor = WalletUX.foreground
        titleLabel.font = WalletUX.font(.title2)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0
        titleLabel.accessibilityTraits = .header
        statusLabel.numberOfLines = 0
        statusLabel.textColor = WalletUX.foreground
        statusLabel.font = WalletUX.font(.headline)
        statusLabel.adjustsFontForContentSizeCategory = true
        for textView in [detailView, diagnosticView] {
            textView.backgroundColor = WalletUX.surface
            textView.textColor = WalletUX.foreground
            textView.font = WalletUX.font()
            textView.isEditable = false
            textView.isScrollEnabled = false
            textView.layer.cornerRadius = 16
            textView.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 16, right: 12)
            textView.adjustsFontForContentSizeCategory = true
        }
        diagnosticView.font = UIFontMetrics(forTextStyle: .caption1).scaledFont(for: .monospacedSystemFont(ofSize: 13, weight: .regular))
        diagnosticView.isHidden = true
        detailsButton.isHidden = true
        securityLabel.text = WalletUX.text("Review the app, network, and account before continuing. You will approve each signature separately.")
        securityLabel.numberOfLines = 0
        securityLabel.textColor = WalletUX.secondary
        securityLabel.font = WalletUX.font(.subheadline)
        securityLabel.adjustsFontForContentSizeCategory = true
        configurePrimaryButton()
        secondaryButton.setTitle(WalletUX.text("Decline request"), for: .normal)
        secondaryButton.setTitleColor(WalletUX.accent, for: .normal)
        secondaryButton.titleLabel?.font = WalletUX.font(.headline)
        secondaryButton.titleLabel?.numberOfLines = 0
        secondaryButton.titleLabel?.adjustsFontForContentSizeCategory = true
        secondaryButton.addTarget(self, action: #selector(secondaryTapped), for: .touchUpInside)
        secondaryButton.isHidden = true
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = WalletUX.foreground
        closeButton.accessibilityLabel = WalletUX.text("Close app connection")
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        let content = UIStackView(arrangedSubviews: [eyebrow, titleLabel, statusLabel, detailView, detailsButton, diagnosticView, securityLabel, primaryButton, secondaryButton])
        content.axis = .vertical
        content.spacing = 20
        content.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(content)
        NSLayoutConstraint.activate([
            closeButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            closeButton.widthAnchor.constraint(equalToConstant: 48),
            closeButton.heightAnchor.constraint(equalToConstant: 48),
            scroll.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 8),
            scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            content.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 24),
            content.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -24),
            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 12),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
            content.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -48),
            primaryButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 54),
            secondaryButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 48)
        ])
    }

    private func configurePrimaryButton() {
        var configuration = UIButton.Configuration.filled()
        configuration.baseBackgroundColor = WalletUX.accent
        configuration.baseForegroundColor = WalletUX.surface
        configuration.cornerStyle = .capsule
        configuration.titleAlignment = .center
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = WalletUX.font(.headline)
            return attributes
        }
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20)
        primaryButton.configuration = configuration
        primaryButton.titleLabel?.numberOfLines = 0
        primaryButton.titleLabel?.textAlignment = .center
        primaryButton.titleLabel?.adjustsFontForContentSizeCategory = true
        primaryButton.addTarget(self, action: #selector(primaryTapped), for: .touchUpInside)
    }

    private func showConnecting() {
        statusLabel.text = WalletUX.text("Opening a secure relay")
        detailView.text = "\(WalletUX.text("Network")): \(networkName)\n\(WalletUX.text("Account")): \(account.accountId)"
        setAction(.none, title: "Connecting…")
    }

    private func startConnection() {
        let remaining = max(
            0,
            IrohaConnectSessionEngine.approvalLifetime -
                Date().timeIntervalSince(launch.receivedAt)
        )
        expiryTimer = Timer.scheduledTimer(withTimeInterval: remaining, repeats: false) { [weak self] _ in
            self?.fail(IrohaConnectError.expired)
        }
        let socket = IrohaConnectWebSocket(
            url: launch.webSocketURL,
            protocol: launch.webSocketProtocol
        )
        socket.onOpen = { [weak self] in
            guard let self, !self.isTerminal, !self.didFinish else { return }
            self.statusLabel.text = WalletUX.text("Secure relay ready — waiting for the app")
        }
        socket.onData = { [weak self] data in self?.receive(data) }
        socket.onClosed = { [weak self] reason in self?.showCompletion(reason) }
        socket.onFailure = { [weak self] error in self?.fail(error) }
        self.socket = socket
        socket.connect()
    }

    private func receive(_ data: Data) {
        guard !isTerminal, !didFinish else { return }
        do {
            let result = try engine.receive(data)
            result.outbound.forEach { socket?.send($0) }
            switch result.event {
            case let .open(metadata, permissions):
                showPairing(metadata: metadata, permissions: permissions)
            case let .signingRequest(request):
                showSigning(request)
            case let .display(title, body):
                statusLabel.text = String(title.prefix(200))
                detailView.text = String(body.prefix(4_000))
                setAction(.none, title: "Connected")
            case let .closed(reason):
                showCompletion(reason.isEmpty ? "Connection closed" : reason)
            case .none:
                break
            }
        } catch {
            fail(error)
        }
    }

    private func showPairing(
        metadata: IrohaConnectAppMetadata?,
        permissions: IrohaConnectPermissions?
    ) {
        connectedApp = metadata
        let appName = metadata?.name ?? WalletUX.text("Unknown app")
        statusLabel.text = WalletUX.format("Connect %@?", appName)
        var lines = [
            "\(WalletUX.text("App")): \(appName)",
            "\(WalletUX.text("Network")): \(networkName)",
            "\(WalletUX.text("Account")): \(account.accountId)",
        ]
        if let appURL = metadata?.url { lines.append("\(WalletUX.text("Website")): \(appURL)") }
        lines.append("\(WalletUX.text("Requested access")): \(permissionDescription(permissions))")
        lines.append("")
        lines.append(WalletUX.format("Only approve if you initiated this connection in %@.", appName))
        detailView.text = lines.joined(separator: "\n")
        secondaryButton.setTitle(WalletUX.text("Decline connection"), for: .normal)
        secondaryButton.isHidden = false
        setAction(.approve, title: "Authenticate & connect")
        UIAccessibility.post(notification: .screenChanged, argument: statusLabel)
    }

    private func showSigning(_ request: IrohaConnectSigningRequest) {
        expiryTimer?.invalidate()
        expiryTimer = Timer.scheduledTimer(
            withTimeInterval: IrohaConnectSessionEngine.requestLifetime,
            repeats: false
        ) { [weak self] _ in
            self?.expirePendingSignature()
        }
        let review = IrohaConnectSigningReview(request: request)
        let appDetails = "\(WalletUX.text("App")): \(connectedApp?.name ?? WalletUX.text("Unknown app"))" +
            (connectedApp?.url.map { "\n\(WalletUX.text("Website")): \($0)" } ?? "")
        let accountDetails = "\(appDetails)\n\n\(WalletUX.text("Network")): \(networkName)\n\(WalletUX.text("Account")): \(account.accountId)"
        if case let .raw(domain, _) = request, let message = review.readableMessage {
            titleLabel.text = WalletUX.text("Review message")
            statusLabel.text = WalletUX.text("Sign this message?")
            detailView.text = "\(accountDetails)\n\n\(WalletUX.text("Domain")): \(domain)\n\n\(WalletUX.text("Message"))\n\(message)"
            securityLabel.text = WalletUX.text("A signature can authorize an action in the requesting app. Sign only if you understand and agree to the complete message above.")
            setAction(.sign, title: WalletUX.text("Sign message"))
        } else {
            titleLabel.text = WalletUX.text("Cannot review request")
            statusLabel.text = WalletUX.text("Signing unavailable")
            detailView.text = "\(accountDetails)\n\n\(WalletUX.text(review.unavailableReason))"
            securityLabel.text = WalletUX.text("Nothing has been signed. Decline this request and return to the app.")
            setAction(.none, title: WalletUX.text("Cannot sign this request"))
        }
        diagnosticView.text = requestDetails(request.bytes).joined(separator: "\n")
        diagnosticView.isHidden = true
        detailsButton.isHidden = false
        detailsButton.accessibilityValue = WalletUX.text("Collapsed")
        secondaryButton.setTitle(WalletUX.text("Decline signature"), for: .normal)
        secondaryButton.isHidden = false
        UIAccessibility.post(notification: .screenChanged, argument: statusLabel)
    }

    private func requestDetails(_ bytes: Data) -> [String] {
        let digest = Data(SHA256.hash(data: bytes)).map { String(format: "%02x", $0) }.joined()
        let lines = [
            WalletUX.format("Size: %d bytes", bytes.count),
            "SHA-256   \(digest)",
        ]
        return lines
    }

    @objc private func primaryTapped() {
        switch action {
        case .approve:
            authenticateAndApprove()
        case .sign:
            authenticateAndSign()
        case .done:
            finish(sendClose: false, reason: "Done")
        case .none:
            break
        }
    }

    @objc private func secondaryTapped() {
        guard !isTerminal else { return }
        do {
            if engine.pendingRequest != nil {
                socket?.send(try engine.rejectPendingSignature())
                expiryTimer?.invalidate()
                expiryTimer = nil
                statusLabel.text = WalletUX.text("Signature declined — connection remains open")
                detailView.text = WalletUX.text("The app received a signed rejection. A new request will require a fresh review.")
                secondaryButton.isHidden = true
                setAction(.none, title: "Connected")
            } else {
                if let response = try engine.rejectPairing() { socket?.send(response) }
                finish(sendClose: false, reason: "Connection declined")
            }
        } catch {
            fail(error)
        }
    }

    @objc private func closeTapped() {
        finish(sendClose: true, reason: "Wallet closed the connection")
    }

    private func authenticateAndApprove() {
        beginAuthentication(title: "Authenticating…")
        authenticator.authenticate(
            reason: WalletUX.format("Approve the IrohaConnect connection for %@", networkName)
        ) { [weak self] result in
            guard let self, !self.isTerminal, !self.didFinish else { return }
            switch result {
            case .success:
                do {
                    let frame = try self.engine.approve(account: self.account) { preimage in
                        try self.walletProvider.sign(preimage, context: self.account)
                    }
                    self.socket?.send(frame)
                    self.expiryTimer?.invalidate()
                    self.expiryTimer = nil
                    self.statusLabel.text = WalletUX.text("Connected securely")
                    self.detailView.text = self.account.accountId + "\n\n" + WalletUX.text("The app may now request only the permissions you reviewed. Every signature still requires authentication.")
                    self.secondaryButton.isHidden = true
                    self.setAction(.none, title: "Waiting for a request…")
                } catch {
                    self.fail(error)
                }
            case .failure:
                self.showTransientMessage("Authentication was cancelled. Nothing was approved.")
                self.secondaryButton.isHidden = false
                self.setAction(.approve, title: "Authenticate & connect")
            }
        }
    }

    private func authenticateAndSign() {
        guard let request = engine.pendingRequest, IrohaConnectSigningReview(request: request).canSign else { return }
        beginAuthentication(title: "Authenticating signature…")
        authenticator.authenticate(
            reason: WalletUX.text("Sign the reviewed IrohaConnect request with your SORA 3 account")
        ) { [weak self] result in
            guard let self, !self.isTerminal, !self.didFinish else { return }
            switch result {
            case .success:
                do {
                    let frame = try self.engine.approvePendingSignature(account: self.account) { message in
                        try self.walletProvider.sign(message, context: self.account)
                    }
                    self.socket?.send(frame)
                    self.expiryTimer?.invalidate()
                    self.expiryTimer = nil
                    self.statusLabel.text = WalletUX.text("Signature returned securely")
                    self.detailView.text = WalletUX.text("The reviewed request was signed. The connection remains open for future requests.")
                    self.secondaryButton.isHidden = true
                    self.setAction(.none, title: "Connected")
                } catch {
                    self.fail(error)
                }
            case .failure:
                self.showTransientMessage("Authentication was cancelled. The request remains unsigned.")
                self.secondaryButton.isHidden = false
                self.setAction(.sign, title: "Authenticate & sign")
            }
        }
    }

    private func beginAuthentication(title: String) {
        statusLabel.text = WalletUX.text(title)
        primaryButton.isEnabled = false
        secondaryButton.isEnabled = false
        closeButton.isEnabled = false
    }

    private func expirePendingSignature() {
        guard engine.pendingRequest != nil else { return }
        do {
            socket?.send(try engine.rejectPendingSignature())
            expiryTimer?.invalidate()
            expiryTimer = nil
            statusLabel.text = WalletUX.text("Signature request expired")
            detailView.text = WalletUX.text("Nothing was signed. The app must send a fresh request for you to review.")
            secondaryButton.isHidden = true
            setAction(.none, title: "Connected")
        } catch {
            fail(error)
        }
    }

    private func setAction(_ action: Action, title: String) {
        self.action = action
        primaryButton.configuration?.title = WalletUX.text(title)
        primaryButton.isEnabled = action != .none
        secondaryButton.isEnabled = true
        closeButton.isEnabled = true
    }

    private func showCompletion(_ reason: String) {
        guard !isTerminal, !didFinish else { return }
        isTerminal = true
        _ = engine.close(reason: reason)
        expiryTimer?.invalidate()
        socket?.cancel()
        statusLabel.text = WalletUX.text("Connection closed")
        detailView.text = reason
        secondaryButton.isHidden = true
        setAction(.done, title: "Done")
    }

    private func fail(_ error: Error) {
        guard !isTerminal, !didFinish else { return }
        isTerminal = true
        _ = engine.close(reason: "Wallet blocked an invalid session").map { socket?.send($0) }
        expiryTimer?.invalidate()
        socket?.cancel()
        statusLabel.text = WalletUX.text("Request blocked")
        detailView.text = error.localizedDescription
        secondaryButton.isHidden = true
        setAction(.done, title: "Done")
        UIAccessibility.post(notification: .announcement, argument: error.localizedDescription)
    }

    private func finish(sendClose: Bool, reason: String) {
        guard !didFinish else { return }
        didFinish = true
        isTerminal = true
        if sendClose, let response = engine.close(reason: reason) { socket?.send(response) }
        expiryTimer?.invalidate()
        socket?.cancel()
        dismiss(animated: true) { [onFinish] in onFinish?() }
    }

    private var networkName: String {
        switch launch.networkId {
        case .taira: return "SORA Taira Testnet"
        case .minamoto: return "SORA Minamoto"
        case .sora2: return "Unsupported"
        }
    }

    private func permissionDescription(_ permissions: IrohaConnectPermissions?) -> String {
        guard let permissions else { return WalletUX.text("Connect only (no signing)") }
        var labels: [String] = []
        if permissions.methods.contains("sign_raw") {
            labels.append(WalletUX.format("Message signatures for %@", permissions.resources?.joined(separator: ", ") ?? WalletUX.text("No domains")))
        }
        if permissions.methods.contains("sign_transaction") {
            labels.append(WalletUX.text("transaction signatures"))
        }
        return labels.isEmpty ? WalletUX.text("Connect only (no signing)") : labels.joined(separator: "; ")
    }
}

extension IrohaConnectViewController {
 func prepareVisualFixture(blocked:Bool) {
  didStart=true
  loadViewIfNeeded()
  connectedApp=IrohaConnectAppMetadata(name:"Example app",url:"https://example.test",iconHash:nil)
  let request:IrohaConnectSigningRequest = blocked ? .transaction(bytes:Data("opaque transaction".utf8)) : .raw(domain:"example.test",bytes:Data("Authorize access to my public profile.\nThis message does not request a token transfer.\nSession: sample-review-2026".utf8))
  engine.pendingRequest=request
  showSigning(request)
  expiryTimer?.invalidate();expiryTimer=nil
 }
}
