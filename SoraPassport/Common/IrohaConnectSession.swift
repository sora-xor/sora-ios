// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import CryptoKit
import Foundation
import IrohaCrypto
import LocalAuthentication
import SoraKeystore

struct IrohaConnectWalletContext: Equatable {
    let walletId: String
    let networkId: NetworkId
    let accountId: String
    let publicKey: Data
}

final class IrohaConnectWalletProvider {
    private let keystore: KeystoreProtocol
    private let store: WalletNetworkStore
    private let selectedAccount: () -> AccountItem?

    init(
        keystore: KeystoreProtocol = Keychain(),
        store: WalletNetworkStore? = nil,
        selectedAccount: @escaping () -> AccountItem? = {
            SelectedWalletSettings.shared.currentAccount
        }
    ) throws {
        self.keystore = keystore
        self.store = try store ?? WalletNetworkStore()
        self.selectedAccount = selectedAccount
    }

    func context(for launch: IrohaConnectLaunch) throws -> IrohaConnectWalletContext {
        guard
            let selected = selectedAccount(),
            let snapshot = try store.load(),
            snapshot.selectedWalletId == selected.address,
            snapshot.wallets.filter({ $0.id == selected.address }).count == 1,
            let wallet = snapshot.wallets.first(where: { $0.id == selected.address }),
            wallet.existingSoraAddress == selected.address,
            wallet.secretSource.supportsNexusDerivation
        else {
            throw IrohaConnectError.walletUnavailable
        }
        let matches = snapshot.accounts.filter {
            $0.walletId == selected.address && $0.networkId == launch.networkId
        }
        guard
            matches.count == 1,
            let account = matches.first,
            account.derivationVersion == 1,
            account.publicKey.count == 32,
            let configuration = NexusNetworkConfiguration.configuration(for: launch.networkId),
            configuration.satisfiesCurrentTairaContract
        else {
            throw IrohaConnectError.walletUnavailable
        }
        do {
            try configuration.validate(address: account.address)
        } catch {
            throw IrohaConnectError.walletUnavailable
        }
        return IrohaConnectWalletContext(
            walletId: selected.address,
            networkId: launch.networkId,
            accountId: account.address,
            publicKey: account.publicKey
        )
    }

    func sign(_ message: Data, context expected: IrohaConnectWalletContext) throws -> Data {
        guard !message.isEmpty else {
            throw IrohaConnectError.protocolViolation("empty signing message")
        }
        guard
            let selected = selectedAccount(),
            selected.address == expected.walletId,
            let snapshot = try store.load(),
            snapshot.selectedWalletId == expected.walletId,
            snapshot.accounts.filter({
                $0.walletId == expected.walletId &&
                    $0.networkId == expected.networkId &&
                    $0.derivationVersion == 1 &&
                    $0.publicKey == expected.publicKey &&
                    $0.address == expected.accountId
            }).count == 1,
            let configuration = NexusNetworkConfiguration.configuration(for: expected.networkId),
            configuration.satisfiesCurrentTairaContract
        else {
            throw IrohaConnectError.walletUnavailable
        }

        guard var entropy = try keystore.fetchEntropyForAddress(expected.walletId) else {
            throw IrohaConnectError.walletUnavailable
        }
        defer { entropy.resetBytes(in: entropy.startIndex ..< entropy.endIndex) }
        var mnemonic = try IRMnemonicCreator(language: .english)
            .mnemonic(fromEntropy: entropy)
            .toString()
        defer { mnemonic.removeAll(keepingCapacity: false) }
        var derived = try NexusKeyDerivation.derive(
            mnemonic: mnemonic,
            configuration: configuration
        )
        defer {
            derived.privateKey.resetBytes(in: derived.privateKey.startIndex ..< derived.privateKey.endIndex)
            derived.chainCode.resetBytes(in: derived.chainCode.startIndex ..< derived.chainCode.endIndex)
        }
        guard
            derived.derivationPath == configuration.derivationPath,
            derived.publicKey == expected.publicKey,
            derived.address == expected.accountId
        else {
            throw IrohaConnectError.walletUnavailable
        }
        let signingKey = try Curve25519.Signing.PrivateKey(rawRepresentation: derived.privateKey)
        guard signingKey.publicKey.rawRepresentation == expected.publicKey else {
            throw IrohaConnectError.walletUnavailable
        }
        let signature = try signingKey.signature(for: message)
        guard signature.count == 64 else {
            throw IrohaConnectError.protocolViolation("Ed25519 signing failed")
        }
        return signature
    }
}

enum IrohaConnectSessionEvent: Equatable {
    case none
    case open(metadata: IrohaConnectAppMetadata?, permissions: IrohaConnectPermissions?)
    case signingRequest(IrohaConnectSigningRequest)
    case display(title: String, body: String)
    case closed(reason: String)
}

struct IrohaConnectSessionResult: Equatable {
    let event: IrohaConnectSessionEvent
    let outbound: [Data]
}

final class IrohaConnectSessionEngine {
    private enum State {
        case awaitingOpen
        case awaitingApproval(IrohaConnectAppMetadata?, IrohaConnectPermissions?)
        case connected(IrohaConnectAppMetadata?, IrohaConnectPermissions?)
        case closed
    }

    static let approvalLifetime: TimeInterval = 120
    static let requestLifetime: TimeInterval = 120

    let launch: IrohaConnectLaunch
    private var state: State = .awaitingOpen
    private var expectedAppSequence: UInt64 = 1
    private var expectedServerSequence: UInt64 = 1
    private var nextWalletSequence: UInt64 = 1
    private var directionKeys: IrohaConnectDirectionKeys?
    private(set) var pendingRequest: IrohaConnectSigningRequest?
    private var pendingRequestReceivedAt: Date?
    private(set) var approvedAccount: IrohaConnectWalletContext?

    init(launch: IrohaConnectLaunch) {
        self.launch = launch
    }

    deinit { wipe() }

    var isClosed: Bool {
        if case .closed = state { return true }
        return false
    }

    func receive(_ data: Data, now: Date = Date()) throws -> IrohaConnectSessionResult {
        do {
            return try receiveValidated(data, now: now)
        } catch {
            if !isClosed {
                wipe()
                state = .closed
            }
            throw error
        }
    }

    private func receiveValidated(
        _ data: Data,
        now: Date
    ) throws -> IrohaConnectSessionResult {
        try requireActive(now)
        let frame = try IrohaConnectWire.decodeFrame(data)
        guard frame.sid == launch.sid, frame.direction == 0 else {
            throw closeWithViolation("session or direction mismatch")
        }
        if case .control(.serverEvent) = frame.kind {
            guard frame.sequence == expectedServerSequence else {
                throw closeWithViolation("out-of-order or replayed server event")
            }
            expectedServerSequence = try incrementSequence(
                expectedServerSequence,
                label: "server event"
            )
            return IrohaConnectSessionResult(event: .none, outbound: [])
        }
        guard frame.sequence == expectedAppSequence else {
            throw closeWithViolation("out-of-order or replayed app frame")
        }

        switch state {
        case .awaitingOpen:
            guard
                frame.sequence == 1,
                case let .control(.open(appPublicKey, metadata, network, permissions)) = frame.kind,
                appPublicKey == launch.appPublicKey,
                network == launch.network
            else {
                throw closeWithViolation("first frame is not the bound Open request")
            }
            try permissions?.validate()
            if let metadata {
                try validate(metadata: metadata)
            }
            expectedAppSequence = 2
            state = .awaitingApproval(metadata, permissions)
            return IrohaConnectSessionResult(
                event: .open(metadata: metadata, permissions: permissions),
                outbound: []
            )

        case let .connected(_, permissions):
            expectedAppSequence = try incrementSequence(
                expectedAppSequence,
                label: "application"
            )
            switch frame.kind {
            case let .control(.ping(nonce)):
                let response = IrohaConnectWire.encodePong(
                    sid: launch.sid,
                    sequence: try takeWalletSequence(),
                    nonce: nonce
                )
                return IrohaConnectSessionResult(event: .none, outbound: [response])
            case let .control(.close(_, _, reason, _)):
                wipe()
                state = .closed
                return IrohaConnectSessionResult(event: .closed(reason: reason), outbound: [])
            case let .ciphertext(direction, ciphertext):
                guard direction == 0, let keys = directionKeys else {
                    throw closeWithViolation("encrypted frame arrived before approval")
                }
                var plaintext = try IrohaConnectCrypto.decrypt(
                    ciphertext: ciphertext,
                    key: keys.appToWallet,
                    sid: launch.sid,
                    direction: 0,
                    sequence: frame.sequence
                )
                defer {
                    plaintext.resetBytes(
                        in: plaintext.startIndex ..< plaintext.endIndex
                    )
                }
                let (envelopeSequence, payload) = try IrohaConnectWire.decodeEnvelope(plaintext)
                guard envelopeSequence == frame.sequence else {
                    throw closeWithViolation("frame and envelope sequence mismatch")
                }
                return try handle(payload, permissions: permissions, now: now)
            default:
                throw closeWithViolation("unexpected control frame after approval")
            }

        case .awaitingApproval:
            throw closeWithViolation("app sent data before wallet approval")
        case .closed:
            throw IrohaConnectError.protocolViolation("session is already closed")
        }
    }

    func approve(
        account: IrohaConnectWalletContext,
        agreementPrivateKey: Data? = nil,
        signer: (Data) throws -> Data,
        now: Date = Date()
    ) throws -> Data {
        try requireActive(now)
        guard case let .awaitingApproval(metadata, permissions) = state else {
            throw closeWithViolation("session is not awaiting approval")
        }
        guard account.networkId == launch.networkId, account.publicKey.count == 32 else {
            throw closeWithViolation("wallet account does not match this network")
        }
        let agreementKey: Curve25519.KeyAgreement.PrivateKey
        if let agreementPrivateKey {
            agreementKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: agreementPrivateKey)
        } else {
            agreementKey = Curve25519.KeyAgreement.PrivateKey()
        }
        let walletPublicKey = agreementKey.publicKey.rawRepresentation
        var keys = try IrohaConnectCrypto.directionKeys(
            walletPrivateKey: agreementKey,
            appPublicKey: launch.appPublicKey,
            sid: launch.sid
        )
        do {
            let preimage = try IrohaConnectWire.approvalPreimage(
                launch: launch,
                walletKey: walletPublicKey,
                accountId: account.accountId,
                permissions: permissions
            )
            let signature = try signer(preimage)
            guard
                signature.count == 64,
                let signingKey = try? Curve25519.Signing.PublicKey(
                    rawRepresentation: account.publicKey
                ),
                signingKey.isValidSignature(signature, for: preimage)
            else {
                throw IrohaConnectError.protocolViolation(
                    "approval signature does not match the selected Ed25519 account"
                )
            }
            let response = try IrohaConnectWire.encodeApprove(
                sid: launch.sid,
                sequence: try takeWalletSequence(),
                walletKey: walletPublicKey,
                accountId: account.accountId,
                permissions: permissions,
                signature: signature
            )
            directionKeys = keys
            approvedAccount = account
            state = .connected(metadata, permissions)
            return response
        } catch {
            keys.wipe()
            throw error
        }
    }

    func rejectPairing(reason: String = "User declined the connection") throws -> Data? {
        guard case .awaitingApproval = state else {
            wipe()
            state = .closed
            return nil
        }
        let response = IrohaConnectWire.encodeReject(
            sid: launch.sid,
            sequence: try takeWalletSequence(),
            code: 4001,
            codeId: "user_rejected",
            reason: String(reason.prefix(512))
        )
        wipe()
        state = .closed
        return response
    }

    func approvePendingSignature(
        account: IrohaConnectWalletContext,
        signer: (Data) throws -> Data,
        now: Date = Date()
    ) throws -> Data {
        try requireActive(now)
        guard
            let request = pendingRequest,
            let receivedAt = pendingRequestReceivedAt,
            account == approvedAccount
        else {
            throw closeWithViolation("no matching signature request is pending")
        }
        if now.timeIntervalSince(receivedAt) < 0 ||
            now.timeIntervalSince(receivedAt) >= Self.requestLifetime {
            pendingRequest = nil
            pendingRequestReceivedAt = nil
            return try encryptedOutbound(
                .signError(
                    code: "REQUEST_EXPIRED",
                    message: "IrohaConnect request approval token has expired."
                )
            )
        }
        let review = IrohaConnectSigningReview(request: request)
        guard review.canSign else {
            pendingRequest = nil
            pendingRequestReceivedAt = nil
            return try encryptedOutbound(.signError(
                code: "UNREADABLE_REQUEST", message: review.unavailableReason
            ))
        }
        let signature = try signer(request.bytes)
        guard
            signature.count == 64,
            let signingKey = try? Curve25519.Signing.PublicKey(
                rawRepresentation: account.publicKey
            ),
            signingKey.isValidSignature(signature, for: request.bytes)
        else {
            throw closeWithViolation(
                "signature does not match the approved Ed25519 account"
            )
        }
        pendingRequest = nil
        pendingRequestReceivedAt = nil
        return try encryptedOutbound(.signResult(signature: signature))
    }

    func rejectPendingSignature(now: Date = Date()) throws -> Data {
        try requireActive(now)
        guard pendingRequest != nil, let receivedAt = pendingRequestReceivedAt else {
            throw closeWithViolation("no signature request is pending")
        }
        let expired = now.timeIntervalSince(receivedAt) < 0 ||
            now.timeIntervalSince(receivedAt) >= Self.requestLifetime
        pendingRequest = nil
        pendingRequestReceivedAt = nil
        return try encryptedOutbound(
            .signError(
                code: expired ? "REQUEST_EXPIRED" : "USER_REJECTED",
                message: expired
                    ? "IrohaConnect request approval token has expired."
                    : "Rejected by user."
            )
        )
    }

    func close(reason: String = "Wallet closed the connection") -> Data? {
        guard !isClosed else { return nil }
        defer {
            wipe()
            state = .closed
        }
        if directionKeys != nil {
            return try? encryptedOutbound(
                .close(who: 1, code: 1000, reason: String(reason.prefix(512)), retryable: false)
            )
        }
        return nil
    }

    private func handle(
        _ payload: IrohaConnectEnvelopePayload,
        permissions: IrohaConnectPermissions?,
        now: Date
    ) throws -> IrohaConnectSessionResult {
        switch payload {
        case let .signRequest(request):
            guard pendingRequest == nil else {
                throw closeWithViolation("a second signing request arrived before resolution")
            }
            guard !request.bytes.isEmpty, request.bytes.count <= 524_288,
                  permissions?.permits(request) == true else {
                throw closeWithViolation("signing request exceeds granted permission")
            }
            pendingRequest = request
            pendingRequestReceivedAt = now
            return IrohaConnectSessionResult(event: .signingRequest(request), outbound: [])
        case let .display(title, body):
            guard pendingRequest == nil else {
                throw closeWithViolation("display request arrived during signature review")
            }
            guard title.utf8.count <= 512, body.utf8.count <= 8_192 else {
                throw closeWithViolation("display request exceeds its limit")
            }
            return IrohaConnectSessionResult(event: .display(title: title, body: body), outbound: [])
        case let .close(_, _, reason, _):
            wipe()
            state = .closed
            return IrohaConnectSessionResult(event: .closed(reason: reason), outbound: [])
        case let .reject(_, _, reason):
            wipe()
            state = .closed
            return IrohaConnectSessionResult(event: .closed(reason: reason), outbound: [])
        case .signResult, .signError:
            throw closeWithViolation("app sent a wallet-only signing result")
        }
    }

    private func encryptedOutbound(_ payload: IrohaConnectEnvelopePayload) throws -> Data {
        guard let keys = directionKeys else {
            throw closeWithViolation("encryption keys are unavailable")
        }
        let sequence = try takeWalletSequence()
        var envelope = try IrohaConnectWire.encodeEnvelope(
            sequence: sequence,
            payload: payload
        )
        defer {
            envelope.resetBytes(in: envelope.startIndex ..< envelope.endIndex)
        }
        let ciphertext = try IrohaConnectCrypto.encrypt(
            envelope: envelope,
            key: keys.walletToApp,
            sid: launch.sid,
            direction: 1,
            sequence: sequence
        )
        return IrohaConnectWire.encodeCiphertext(
            sid: launch.sid,
            sequence: sequence,
            bytes: ciphertext
        )
    }

    private func takeWalletSequence() throws -> UInt64 {
        let current = nextWalletSequence
        nextWalletSequence = try incrementSequence(current, label: "wallet")
        return current
    }

    private func incrementSequence(
        _ sequence: UInt64,
        label: String
    ) throws -> UInt64 {
        guard sequence < UInt64.max else {
            throw closeWithViolation("\(label) sequence space is exhausted")
        }
        return sequence + 1
    }

    private func validate(metadata: IrohaConnectAppMetadata) throws {
        guard
            !metadata.name.isEmpty,
            metadata.name == metadata.name.trimmingCharacters(
                in: .whitespacesAndNewlines
            ),
            metadata.name.utf8.count <= 128,
            !metadata.name.unicodeScalars.contains(where: {
                CharacterSet.controlCharacters.contains($0)
            })
        else {
            throw closeWithViolation("application name is not canonical")
        }
        if let value = metadata.url {
            guard
                value == value.trimmingCharacters(in: .whitespacesAndNewlines),
                let components = URLComponents(string: value),
                components.scheme == "https",
                let host = components.host,
                !host.isEmpty,
                host == host.lowercased(),
                components.user == nil,
                components.password == nil,
                components.fragment == nil,
                components.url?.absoluteString == value
            else {
                throw closeWithViolation(
                    "application URL is not a canonical HTTPS origin"
                )
            }
        }
        if let iconHash = metadata.iconHash,
           iconHash.range(
               of: #"^[0-9a-fA-F]{64}$"#,
               options: .regularExpression
           ) == nil {
            throw closeWithViolation("application icon hash is invalid")
        }
    }

    private func requireActive(_ now: Date) throws {
        guard !isClosed else {
            throw IrohaConnectError.protocolViolation("session is already closed")
        }
        switch state {
        case .awaitingOpen, .awaitingApproval:
            guard now.timeIntervalSince(launch.receivedAt) >= 0,
                  now.timeIntervalSince(launch.receivedAt) < Self.approvalLifetime else {
                wipe()
                state = .closed
                throw IrohaConnectError.expired
            }
        case .connected:
            break
        case .closed:
            throw IrohaConnectError.protocolViolation("session is already closed")
        }
    }

    private func closeWithViolation(_ reason: String) -> IrohaConnectError {
        wipe()
        state = .closed
        return .protocolViolation(reason)
    }

    private func wipe() {
        directionKeys?.wipe()
        directionKeys = nil
        pendingRequest = nil
        pendingRequestReceivedAt = nil
        approvedAccount = nil
    }
}

final class IrohaConnectAuthenticator {
    func authenticate(reason: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            completion(.failure(error ?? IrohaConnectError.authenticationFailed))
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success {
                    completion(.success(()))
                } else {
                    completion(.failure(error ?? IrohaConnectError.authenticationFailed))
                }
            }
        }
    }
}

final class IrohaConnectWebSocket: NSObject, URLSessionWebSocketDelegate {
    var onOpen: (() -> Void)?
    var onData: ((Data) -> Void)?
    var onClosed: ((String) -> Void)?
    var onFailure: ((Error) -> Void)?

    private let url: URL
    private let expectedProtocol: String
    private var task: URLSessionWebSocketTask?
    private var didReportFailure = false
    private var cancelledLocally = false
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(
            configuration: configuration,
            delegate: self,
            delegateQueue: OperationQueue.main
        )
    }()

    init(url: URL, protocol expectedProtocol: String) {
        self.url = url
        self.expectedProtocol = expectedProtocol
        super.init()
    }

    deinit { cancel() }

    func connect() {
        guard task == nil else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue(expectedProtocol, forHTTPHeaderField: "Sec-WebSocket-Protocol")
        let task = session.webSocketTask(with: request)
        task.maximumMessageSize = IrohaConnectFrame.maximumBytes
        self.task = task
        task.resume()
    }

    func send(_ data: Data) {
        guard data.count <= IrohaConnectFrame.maximumBytes, let task else {
            report(IrohaConnectError.connectionFailed)
            return
        }
        task.send(.data(data)) { [weak self] error in
            if let error { DispatchQueue.main.async { self?.report(error) } }
        }
    }

    func cancel() {
        cancelledLocally = true
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        session.invalidateAndCancel()
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        guard `protocol` == expectedProtocol else {
            report(IrohaConnectError.protocolViolation("relay did not negotiate token authentication"))
            cancel()
            return
        }
        onOpen?()
        receive()
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error { report(error) }
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        guard !cancelledLocally else { return }
        let message = reason
            .flatMap { String(data: $0, encoding: .utf8) }
            .map { String($0.prefix(512)) }
            ?? "The relay closed the connection."
        onClosed?(message)
    }

    private func receive() {
        task?.receive { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case let .success(.data(data)):
                    guard data.count <= IrohaConnectFrame.maximumBytes else {
                        self.report(IrohaConnectError.protocolViolation("relay frame is too large"))
                        self.cancel()
                        return
                    }
                    self.onData?(data)
                    if self.task != nil { self.receive() }
                case .success(.string):
                    self.report(IrohaConnectError.protocolViolation("text relay frames are not supported"))
                    self.cancel()
                case let .failure(error):
                    self.report(error)
                @unknown default:
                    self.report(IrohaConnectError.connectionFailed)
                }
            }
        }
    }

    private func report(_ error: Error) {
        guard !cancelledLocally, !didReportFailure else { return }
        didReportFailure = true
        onFailure?(error)
    }
}
