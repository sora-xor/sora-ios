// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import CryptoKit
import UIKit

final class IrohaConnectCoordinator {
    static let shared = IrohaConnectCoordinator()

    private weak var activeController: IrohaConnectViewController?

    private init() {}

    func canHandle(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return false
        }
        return ["iroha", "irohaconnect"].contains(components.scheme?.lowercased() ?? "") &&
            components.host == "connect"
    }

    @discardableResult
    func handle(_ url: URL, in window: UIWindow?) -> Bool {
        guard canHandle(url) else { return false }
        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, let window else { return }
            guard self.activeController == nil else {
                self.activeController?.showTransientMessage(
                    "Finish or close the current IrohaConnect request before opening another."
                )
                return
            }
            do {
                let launch = try IrohaConnectLaunch.parse(url)
                let provider = try IrohaConnectWalletProvider()
                let account = try provider.context(for: launch)
                let controller = IrohaConnectViewController(
                    launch: launch,
                    account: account,
                    walletProvider: provider
                )
                controller.onFinish = { [weak self] in self?.activeController = nil }
                controller.modalPresentationStyle = .fullScreen
                self.activeController = controller
                self.topController(from: window.rootViewController)?.present(
                    controller,
                    animated: true
                )
            } catch {
                self.presentError(error, in: window)
            }
        }
        return true
    }

    func applicationDidEnterBackground() {
        activeController?.applicationDidEnterBackground()
    }

    private func presentError(_ error: Error, in window: UIWindow) {
        let alert = UIAlertController(
            title: "IrohaConnect request blocked",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        topController(from: window.rootViewController)?.present(alert, animated: true)
    }

    private func topController(from root: UIViewController?) -> UIViewController? {
        if let presented = root?.presentedViewController {
            return topController(from: presented)
        }
        if let navigation = root as? UINavigationController {
            return topController(from: navigation.visibleViewController)
        }
        if let tab = root as? UITabBarController {
            return topController(from: tab.selectedViewController)
        }
        return root
    }
}

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
    private let backdrop = IrohaConnectSakuraBackdropView()
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

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

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
        statusLabel.text = message
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    private func buildInterface() {
        view.backgroundColor = UIColor(rgb: 0x120609)
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backdrop)

        eyebrow.text = "SORA 3 WALLET"
        eyebrow.textColor = UIColor(rgb: 0xD6A94D)
        eyebrow.font = .soraConnect(size: 12, weight: .semibold)
        eyebrow.textAlignment = .center
        eyebrow.accessibilityTraits = .header

        titleLabel.text = "IROHA CONNECT"
        titleLabel.textColor = UIColor(rgb: 0xFFF6E5)
        titleLabel.font = .soraConnect(size: 30, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontForContentSizeCategory = true

        let mark = IrohaConnectSakuraMarkView()
        mark.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.numberOfLines = 0
        statusLabel.textAlignment = .center
        statusLabel.textColor = UIColor(rgb: 0xFFF6E5)
        statusLabel.font = .soraConnect(size: 19, weight: .semibold)
        statusLabel.adjustsFontForContentSizeCategory = true

        detailView.backgroundColor = UIColor(rgb: 0x260D12).withAlphaComponent(0.92)
        detailView.textColor = UIColor(rgb: 0xF1DFCE)
        detailView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        detailView.isEditable = false
        detailView.isScrollEnabled = true
        detailView.layer.cornerRadius = 18
        detailView.layer.borderWidth = 1
        detailView.layer.borderColor = UIColor(rgb: 0x6C2935).cgColor
        detailView.textContainerInset = UIEdgeInsets(top: 16, left: 14, bottom: 16, right: 14)
        detailView.adjustsFontForContentSizeCategory = true

        securityLabel.text = "Every connection and every signature requires device authentication. Private keys never leave this wallet."
        securityLabel.numberOfLines = 0
        securityLabel.textAlignment = .center
        securityLabel.textColor = UIColor(rgb: 0xC9AAA7)
        securityLabel.font = .soraConnect(size: 12, weight: .regular)
        securityLabel.adjustsFontForContentSizeCategory = true

        configurePrimaryButton()
        secondaryButton.setTitle("Decline request", for: .normal)
        secondaryButton.setTitleColor(UIColor(rgb: 0xE9B8B7), for: .normal)
        secondaryButton.titleLabel?.font = .soraConnect(size: 15, weight: .semibold)
        secondaryButton.addTarget(self, action: #selector(secondaryTapped), for: .touchUpInside)
        secondaryButton.isHidden = true

        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = UIColor(rgb: 0xFFF6E5)
        closeButton.backgroundColor = UIColor(rgb: 0x3B151C).withAlphaComponent(0.9)
        closeButton.layer.cornerRadius = 20
        closeButton.accessibilityLabel = "Close IrohaConnect"
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)

        let header = UIStackView(arrangedSubviews: [mark, eyebrow, titleLabel])
        header.axis = .vertical
        header.alignment = .center
        header.spacing = 5

        let actions = UIStackView(arrangedSubviews: [primaryButton, secondaryButton])
        actions.axis = .vertical
        actions.spacing = 10

        let content = UIStackView(arrangedSubviews: [header, statusLabel, detailView, securityLabel, actions])
        content.axis = .vertical
        content.spacing = 20
        content.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(content)

        NSLayoutConstraint.activate([
            backdrop.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backdrop.topAnchor.constraint(equalTo: view.topAnchor),
            backdrop.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            closeButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -18),
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40),
            content.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            content.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            content.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: 28),
            content.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            content.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            mark.widthAnchor.constraint(equalToConstant: 72),
            mark.heightAnchor.constraint(equalToConstant: 72),
            detailView.heightAnchor.constraint(greaterThanOrEqualToConstant: 160),
            detailView.heightAnchor.constraint(lessThanOrEqualToConstant: 270),
            primaryButton.heightAnchor.constraint(equalToConstant: 54),
            secondaryButton.heightAnchor.constraint(equalToConstant: 42),
        ])
    }

    private func configurePrimaryButton() {
        primaryButton.backgroundColor = UIColor(rgb: 0xE92135)
        primaryButton.setTitleColor(.white, for: .normal)
        primaryButton.setTitleColor(UIColor.white.withAlphaComponent(0.45), for: .disabled)
        primaryButton.titleLabel?.font = .soraConnect(size: 16, weight: .bold)
        primaryButton.layer.cornerRadius = 16
        primaryButton.addTarget(self, action: #selector(primaryTapped), for: .touchUpInside)
    }

    private func showConnecting() {
        statusLabel.text = "Opening a secure relay"
        detailView.text = "Network  \(networkName)\nEndpoint  \(launch.node.host ?? "—")\nAccount   \(account.accountId)"
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
            self.statusLabel.text = "Secure relay ready — waiting for the app"
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
        let appName = metadata?.name ?? "Unknown app"
        statusLabel.text = "Connect \(appName)?"
        var lines = [
            "APP       \(appName)",
            "NETWORK   \(networkName)",
            "ACCOUNT   \(account.accountId)",
        ]
        if let appURL = metadata?.url { lines.append("ORIGIN    \(appURL)") }
        lines.append("ACCESS    \(permissionDescription(permissions))")
        lines.append("")
        lines.append("Only approve if you initiated this connection in \(appName).")
        detailView.text = lines.joined(separator: "\n")
        secondaryButton.setTitle("Decline connection", for: .normal)
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
        statusLabel.text = "Approve this signature?"
        var detail: [String] = []
        switch request {
        case let .raw(domain, bytes):
            detail.append("TYPE      Raw message")
            detail.append("DOMAIN    \(domain)")
            detail.append(contentsOf: requestDetails(bytes))
        case let .transaction(bytes):
            detail.append("TYPE      SORA 3 transaction")
            detail.append(contentsOf: requestDetails(bytes))
        }
        detail.append("NETWORK   \(networkName)")
        detail.append("ACCOUNT   \(account.accountId)")
        detailView.text = detail.joined(separator: "\n")
        secondaryButton.setTitle("Decline signature", for: .normal)
        secondaryButton.isHidden = false
        setAction(.sign, title: "Authenticate & sign")
        UIAccessibility.post(notification: .screenChanged, argument: statusLabel)
    }

    private func requestDetails(_ bytes: Data) -> [String] {
        let digest = Data(SHA256.hash(data: bytes)).map { String(format: "%02x", $0) }.joined()
        var lines = [
            "SIZE      \(bytes.count) bytes",
            "SHA-256   \(digest)",
        ]
        if bytes.count <= 512,
           let text = String(data: bytes, encoding: .utf8),
           !text.unicodeScalars.contains(where: {
               CharacterSet.controlCharacters.contains($0)
                   && $0.value != 10
                   && $0.value != 9
           }) {
            lines.append("MESSAGE   \(text)")
        }
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
                statusLabel.text = "Signature declined — connection remains open"
                detailView.text = "The app received a signed rejection. A new request will require a fresh review."
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
            reason: "Approve the IrohaConnect connection for \(networkName)"
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
                    self.statusLabel.text = "Connected securely"
                    self.detailView.text = "\(self.account.accountId)\n\nThe app may now request only the permissions you reviewed. Every signature still requires authentication."
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
        beginAuthentication(title: "Authenticating signature…")
        authenticator.authenticate(
            reason: "Sign the reviewed IrohaConnect request with your SORA 3 account"
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
                    self.statusLabel.text = "Signature returned securely"
                    self.detailView.text = "The reviewed request was signed. The connection remains open for future requests."
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
        statusLabel.text = title
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
            statusLabel.text = "Signature request expired"
            detailView.text = "Nothing was signed. The app must send a fresh request for you to review."
            secondaryButton.isHidden = true
            setAction(.none, title: "Connected")
        } catch {
            fail(error)
        }
    }

    private func setAction(_ action: Action, title: String) {
        self.action = action
        primaryButton.setTitle(title, for: .normal)
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
        statusLabel.text = "Connection closed"
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
        statusLabel.text = "Request blocked"
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
        guard let permissions else { return "Connect only (no signing)" }
        var labels: [String] = []
        if permissions.methods.contains("sign_raw") {
            labels.append("raw signatures for \(permissions.resources?.joined(separator: ", ") ?? "no domains")")
        }
        if permissions.methods.contains("sign_transaction") {
            labels.append("transaction signatures")
        }
        return labels.isEmpty ? "Connect only (no signing)" : labels.joined(separator: "; ")
    }
}

final class IrohaConnectSakuraMarkView: UIView {
    override class var layerClass: AnyClass { CAShapeLayer.self }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let root = layer as? CAShapeLayer else { return }
        root.sublayers?.forEach { $0.removeFromSuperlayer() }
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        for index in 0 ..< 5 {
            let petal = CAShapeLayer()
            petal.path = Self.petalPath(scale: 0.88).cgPath
            petal.fillColor = (index == 0 ? UIColor(rgb: 0xD6A94D) : UIColor(rgb: 0xE92135)).cgColor
            petal.position = center
            petal.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(index) * .pi * 2 / 5))
            root.addSublayer(petal)
        }
        let core = CAShapeLayer()
        core.path = UIBezierPath(ovalIn: CGRect(x: -5, y: -5, width: 10, height: 10)).cgPath
        core.position = center
        core.fillColor = UIColor(rgb: 0xFFF6E5).cgColor
        root.addSublayer(core)
    }

    static func petalPath(scale: CGFloat = 1) -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: -5 * scale))
        path.addCurve(
            to: CGPoint(x: 0, y: -31 * scale),
            controlPoint1: CGPoint(x: 11 * scale, y: -14 * scale),
            controlPoint2: CGPoint(x: 12 * scale, y: -27 * scale)
        )
        path.addCurve(
            to: CGPoint(x: 0, y: -5 * scale),
            controlPoint1: CGPoint(x: -12 * scale, y: -27 * scale),
            controlPoint2: CGPoint(x: -11 * scale, y: -14 * scale)
        )
        path.close()
        return path
    }
}

final class IrohaConnectSakuraBackdropView: UIView {
    private let gradient = CAGradientLayer()
    private var petals: [CAShapeLayer] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        gradient.colors = [
            UIColor(rgb: 0x2A0910).cgColor,
            UIColor(rgb: 0x120609).cgColor,
            UIColor(rgb: 0x090306).cgColor,
        ]
        gradient.locations = [0, 0.58, 1]
        layer.addSublayer(gradient)
        buildPetals()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(rebuildForAccessibility),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    deinit { NotificationCenter.default.removeObserver(self) }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradient.frame = bounds
        layoutPetals(animated: !UIAccessibility.isReduceMotionEnabled)
    }

    @objc private func rebuildForAccessibility() {
        petals.forEach { $0.removeAllAnimations() }
        setNeedsLayout()
    }

    private func buildPetals() {
        for index in 0 ..< 12 {
            let petal = CAShapeLayer()
            petal.path = IrohaConnectSakuraMarkView.petalPath(scale: 0.3 + CGFloat(index % 3) * 0.05).cgPath
            petal.fillColor = UIColor(rgb: index.isMultiple(of: 4) ? 0xD6A94D : 0xE92135)
                .withAlphaComponent(0.18 + CGFloat(index % 4) * 0.04).cgColor
            layer.addSublayer(petal)
            petals.append(petal)
        }
    }

    private func layoutPetals(animated: Bool) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, petal) in petals.enumerated() {
            let x = bounds.width * CGFloat((index * 37) % 100) / 100
            let y = bounds.height * CGFloat((index * 23 + 11) % 100) / 100
            petal.position = CGPoint(x: x, y: y)
            petal.transform = CATransform3DMakeRotation(CGFloat(index) * 0.7, 0, 0, 1)
            petal.removeAllAnimations()
            guard animated, window != nil else { continue }
            let path = UIBezierPath()
            path.move(to: CGPoint(x: x, y: -30 - CGFloat(index * 7)))
            path.addCurve(
                to: CGPoint(x: x + CGFloat((index % 2 == 0 ? 1 : -1) * 70), y: bounds.height + 50),
                controlPoint1: CGPoint(x: x + 65, y: bounds.height * 0.28),
                controlPoint2: CGPoint(x: x - 55, y: bounds.height * 0.68)
            )
            let fall = CAKeyframeAnimation(keyPath: "position")
            fall.path = path.cgPath
            fall.duration = 10 + Double(index % 5) * 1.7
            fall.beginTime = CACurrentMediaTime() + Double(index) * 0.55
            fall.repeatCount = .infinity
            fall.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            let spin = CABasicAnimation(keyPath: "transform.rotation.z")
            spin.fromValue = CGFloat(index) * 0.7
            spin.toValue = CGFloat(index) * 0.7 + .pi * 3
            spin.duration = 6 + Double(index % 3)
            spin.repeatCount = .infinity
            petal.add(fall, forKey: "sakura-fall")
            petal.add(spin, forKey: "sakura-spin")
        }
        CATransaction.commit()
    }
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

private extension UIFont {
    static func soraConnect(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let name: String
        switch weight {
        case .bold, .heavy, .black: name = "Sora-Bold"
        case .semibold: name = "Sora-SemiBold"
        default: name = "Sora-Regular"
        }
        return UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: weight)
    }
}
