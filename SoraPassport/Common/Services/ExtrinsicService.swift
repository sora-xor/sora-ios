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

import CoreFoundation
import Foundation
import UIKit
import SSFUtils
import RobinHood
import IrohaCrypto
import BigInt
import SSFModels

typealias FeeExtrinsicResult = Result<RuntimeDispatchInfo, Error>
typealias ExtrinsicBuilderClosure = (ExtrinsicBuilderProtocol) throws -> (ExtrinsicBuilderProtocol)
typealias EstimateFeeClosure = (Result<String, Error>) -> Void
typealias ExtrinsicSubmitClosure = (Result<String, Error>, _ extrinsicHash: String?, _ extrinsic: Extrinsic?) -> Void
typealias SubmitAndWatchExtrinsicResult = (result: Result<String, Error>, extrinsicHash: String?)
typealias SubmitExtrinsicResult = Result<String, Error>

struct ExtrinsicInfo {
    let data: Data
    let object: Extrinsic
    let recoveryContext: Sora2SubmissionRecoveryContext
}

struct PreparedExtrinsicFeeQualification {
    let prepared: PreparedExtrinsicSubmission
    let rawFee: String
}

private struct StagedExtrinsicInfo {
    let info: ExtrinsicInfo
    let pending: Sora2PendingSubmission
}

enum ExtrinsicServiceError: Error {
    case lifecycleSignerRequired
    case invalidLocalHash
    case duplicatePreparedSubmission
    case pendingSubmissionCapacityExceeded
    case invalidPendingSubmissionTransition
    case preparedSubmissionAlreadyConsumed
    case unsupportedRuntime(spec: UInt32, transaction: UInt32)
    case unsupportedRuntimeMetadata
    /// The connected node already runs a newer runtime than the metadata the
    /// app holds. The runtime sync service is fetching it; nothing was signed.
    case runtimeUpgradeInProgress(spec: UInt32, transaction: UInt32)
    /// The signing account is not bound to a verified SORA2 account on this
    /// device (missing or mismatched network row, or a read-only account).
    /// Nothing was signed; this is not a network or runtime problem.
    case signingAccountUnavailable
    /// The connected node is not SORA2 mainnet (block zero differs).
    case unexpectedNetwork
    /// The live runtime lists a signed extension that carries data this
    /// version of the app does not write (or expects data the app would
    /// write where the runtime has none). A transaction built anyway would
    /// be rejected by every node, so nothing is signed until the app is
    /// updated.
    case unsupportedSignedExtension(identifier: String)
    /// The connection moved to another node while the runtime was being
    /// checked. Nothing was signed; the next attempt checks the new node.
    case connectionChanged
}

extension ExtrinsicServiceError: LocalizedError {
    var errorDescription: String? {
        Self.runtimeUserMessage(for: self)
    }

    /// A calm, user-facing message for runtime-related failures, or nil when
    /// the error is not runtime related.
    static func runtimeUserMessage(for error: Error) -> String? {
        if let transport = error as? PreparedExtrinsicTransportError {
            return runtimeUserMessage(for: transport.underlyingError)
        }
        if let nodeMessage = Sora2BoundedHTTPJSONRPCError
            .signingRouteUserMessage(for: error) {
            return nodeMessage
        }
        guard let error = error as? ExtrinsicServiceError else {
            return nil
        }
        switch error {
        case .unsupportedSignedExtension:
            return WalletUX.text(
                "The SORA network was upgraded and this version of the app can't send transactions on it yet. Nothing was signed and your funds are safe. Please update the app."
            )
        case .connectionChanged:
            return WalletUX.text(
                "The connection to the SORA network changed while the transaction was being prepared, so nothing was signed. Please try again."
            )
        case .runtimeUpgradeInProgress:
            return WalletUX.text(
                "The SORA network was just upgraded. The app is updating its network data. Please try again in a few seconds."
            )
        case .unsupportedRuntimeMetadata:
            return WalletUX.text(
                "The app could not confirm the SORA network version, so nothing was signed. Please try again in a moment."
            )
        case .unsupportedRuntime, .unexpectedNetwork:
            return WalletUX.text(
                "The connected node does not match the SORA network this app uses, so nothing was signed. Choose another node and try again."
            )
        case .signingAccountUnavailable:
            return WalletUX.text(
                "This account can't sign on this device right now, so nothing was signed. Your funds are not affected. Try again, or restore this account with its recovery phrase to send from it."
            )
        default:
            return nil
        }
    }
}

/// What the connected SORA2 node reports as its current runtime.
struct Sora2LiveRuntime: Equatable {
    let specVersion: UInt32
    let transactionVersion: UInt32
    /// `PolkamarktRuntimeContract.rawMetadataSHA256` of the node's current
    /// metadata (SHA-256 of its lowercase `0x` hex plus a newline).
    let metadataSHA256: String
}

/// The proven live metadata hash per SORA2 node and runtime version.
///
/// An entry is stored only after metadata downloaded from that node proved,
/// through its `System.Version`, that it belongs to exactly that runtime
/// version: by the extrinsic service's own download, or by the runtime sync
/// service, which downloads the same bytes from the same node when the
/// runtime changes. Entries are kept across launches (they are not wallet
/// data). After the first proof for a node, each fee estimate, prepare or
/// submit on that node needs only `chain_getRuntimeVersion`. Concurrent
/// proofs for one node and runtime share a single download.
///
/// A proof is never carried from one node to another: metadata a node
/// served is what that node claims, not a fact about the chain. A node
/// selected later (another custom node, or a bundled node after a custom
/// one) proves its own metadata before the app's stored metadata is used to
/// sign there, and a mismatch replaces the stored metadata from that node.
final class Sora2LiveRuntimeIdentityCache {
    static let shared = Sora2LiveRuntimeIdentityCache(defaults: .standard)
    /// Version 1 was keyed by runtime version only and is no longer read.
    static let persistenceKey = "sora2.mainnet.liveRuntimeMetadataProofs.v2"
    static let maximumEntries = 48

    private struct Key: Hashable {
        let node: String
        let specVersion: UInt32
        let transactionVersion: UInt32

        var persisted: String { "\(specVersion):\(transactionVersion) \(node)" }

        init(node: String, specVersion: UInt32, transactionVersion: UInt32) {
            self.node = node
            self.specVersion = specVersion
            self.transactionVersion = transactionVersion
        }

        init?(persisted: String) {
            guard let separator = persisted.firstIndex(of: " ") else {
                return nil
            }
            let node = String(persisted[persisted.index(after: separator)...])
            let parts = persisted[..<separator].split(
                separator: ":",
                omittingEmptySubsequences: false
            )
            guard
                parts.count == 2,
                let spec = UInt32(parts[0]),
                let transaction = UInt32(parts[1]),
                spec >= Sora2RuntimeIdentity.minimumSpecVersion,
                transaction > 0,
                Sora2LiveRuntimeIdentityCache.isNodeIdentity(node)
            else {
                return nil
            }
            self.init(
                node: node,
                specVersion: spec,
                transactionVersion: transaction
            )
        }
    }

    /// One download in progress; later callers wait for its result.
    private final class Flight {
        let group = DispatchGroup()
        var result: Result<Sora2LiveRuntime, Error>?
    }

    private let defaults: UserDefaults?
    private let lock = NSLock()
    private var values: [Key: String]
    private var flights: [Key: Flight] = [:]

    /// `defaults: nil` keeps entries in memory only.
    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults
        values = Self.load(from: defaults)
    }

    /// The identity under which proofs of the node behind `url` are kept:
    /// its HTTPS JSON-RPC endpoint (the route every signing request uses),
    /// lowercased. Nil when the node has no such route.
    static func nodeIdentity(for url: URL?) -> String? {
        guard
            let endpoint = try? Sora2BoundedHTTPJSONRPCEngine
                .httpEndpoint(for: url)
        else {
            return nil
        }
        let identity = endpoint.absoluteString.lowercased()
        return isNodeIdentity(identity) ? identity : nil
    }

    func metadataSHA256(
        node: String,
        specVersion: UInt32,
        transactionVersion: UInt32
    ) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return values[Key(
            node: node,
            specVersion: specVersion,
            transactionVersion: transactionVersion
        )]
    }

    func store(
        metadataSHA256: String,
        node: String,
        specVersion: UInt32,
        transactionVersion: UInt32
    ) {
        guard
            Self.isHash(metadataSHA256),
            Self.isNodeIdentity(node),
            specVersion >= Sora2RuntimeIdentity.minimumSpecVersion,
            transactionVersion > 0
        else {
            return
        }
        lock.lock()
        defer { lock.unlock() }
        values[Key(
            node: node,
            specVersion: specVersion,
            transactionVersion: transactionVersion
        )] = metadataSHA256
        while values.count > Self.maximumEntries,
              let oldest = values.keys.min(by: {
                  ($0.specVersion, $0.transactionVersion, $0.node) <
                      ($1.specVersion, $1.transactionVersion, $1.node)
              }) {
            values[oldest] = nil
        }
        persist()
    }

    /// Records metadata that the runtime sync service downloaded from
    /// `node` and admitted for this runtime version.
    func recordAdmittedMetadata(
        _ metadata: Data,
        node: String,
        specVersion: UInt32,
        transactionVersion: UInt32
    ) {
        store(
            metadataSHA256: PolkamarktRuntimeContract.rawMetadataSHA256(metadata),
            node: node,
            specVersion: specVersion,
            transactionVersion: transactionVersion
        )
    }

    /// The live runtime of `node` for `version`: from a proof stored for
    /// that node, or by proving the node's current metadata
    /// (`fetchMetadataHex`) against it. Only one download per node and
    /// runtime version runs at a time; other callers wait for it (up to
    /// `waitTimeout`).
    func liveRuntime(
        for version: RuntimeVersion,
        node: String,
        waitTimeout: TimeInterval = 75,
        fetchMetadataHex: () throws -> String
    ) throws -> Sora2LiveRuntime {
        guard Self.isNodeIdentity(node) else {
            throw Sora2BoundedHTTPJSONRPCError.invalidEndpoint
        }
        let key = Key(
            node: node,
            specVersion: version.specVersion,
            transactionVersion: version.transactionVersion
        )
        lock.lock()
        if let proven = values[key] {
            lock.unlock()
            return Sora2LiveRuntime(
                specVersion: version.specVersion,
                transactionVersion: version.transactionVersion,
                metadataSHA256: proven
            )
        }
        if let flight = flights[key] {
            lock.unlock()
            guard flight.group.wait(timeout: .now() + waitTimeout) == .success else {
                throw URLError(.timedOut)
            }
            lock.lock()
            let result = flight.result
            lock.unlock()
            guard let result else {
                throw URLError(.cancelled)
            }
            return try result.get()
        }
        let flight = Flight()
        flight.group.enter()
        flights[key] = flight
        lock.unlock()

        let result = Result<Sora2LiveRuntime, Error> {
            try Sora2LiveRuntimeValidator.liveRuntime(
                version: version,
                metadataHex: try fetchMetadataHex()
            )
        }
        if case let .success(live) = result {
            store(
                metadataSHA256: live.metadataSHA256,
                node: node,
                specVersion: live.specVersion,
                transactionVersion: live.transactionVersion
            )
        }
        lock.lock()
        flight.result = result
        flights[key] = nil
        lock.unlock()
        flight.group.leave()
        return try result.get()
    }

    private func persist() {
        guard let defaults else {
            return
        }
        var persisted: [String: String] = [:]
        for (key, value) in values {
            persisted[key.persisted] = value
        }
        defaults.set(persisted, forKey: Self.persistenceKey)
    }

    private static func load(from defaults: UserDefaults?) -> [Key: String] {
        guard
            let stored = defaults?.dictionary(forKey: persistenceKey)
        else {
            return [:]
        }
        var values: [Key: String] = [:]
        for (rawKey, rawValue) in stored {
            guard
                values.count < maximumEntries,
                let key = Key(persisted: rawKey),
                let value = rawValue as? String,
                isHash(value)
            else {
                continue
            }
            values[key] = value
        }
        return values
    }

    private static func isHash(_ value: String) -> Bool {
        value.utf8.count == 64 && value.utf8.allSatisfy {
            (48 ... 57).contains($0) || (97 ... 102).contains($0)
        }
    }

    fileprivate static func isNodeIdentity(_ value: String) -> Bool {
        value.hasPrefix("https://") &&
            value.utf8.count > 8 &&
            value.utf8.count <= 512 &&
            value == value.lowercased() &&
            !value.unicodeScalars.contains(where: {
                $0 == " " || CharacterSet.controlCharacters.contains($0)
            })
    }
}

/// Validates the runtime a SORA2 extrinsic is about to be encoded with
/// against the live chain. This replaces the former pin to runtime 130: any
/// mainnet runtime at or above the reviewed floor is accepted, provided the
/// local metadata is exactly the one the connected node runs now. Chain
/// identity (genesis) is checked separately against the same live engine.
enum Sora2LiveRuntimeValidator {
    static func validate(
        factory: RuntimeCoderFactoryProtocol,
        live: Sora2LiveRuntime
    ) throws {
        guard
            live.specVersion >= Sora2RuntimeIdentity.minimumSpecVersion,
            live.transactionVersion > 0
        else {
            throw ExtrinsicServiceError.unsupportedRuntime(
                spec: live.specVersion,
                transaction: live.transactionVersion
            )
        }
        guard
            factory.specVersion == live.specVersion,
            factory.txVersion == live.transactionVersion
        else {
            throw ExtrinsicServiceError.runtimeUpgradeInProgress(
                spec: live.specVersion,
                transaction: live.transactionVersion
            )
        }
        do {
            try Sora2RuntimeIdentity.requireDeclaredIdentity(
                of: factory.metadata,
                specVersion: factory.specVersion,
                transactionVersion: factory.txVersion
            )
        } catch {
            throw ExtrinsicServiceError.unsupportedRuntimeMetadata
        }
        // Versions alone are not a metadata identity: pallet and call indices
        // and the types used for the signed bytes must be exactly those of
        // the runtime the node executes.
        guard
            try PolkamarktRuntimeContract.signingMetadataSHA256(
                for: factory
            ) == live.metadataSHA256
        else {
            throw ExtrinsicServiceError.unsupportedRuntimeMetadata
        }
        // The metadata is the live one. The encoder still writes a fixed
        // set of signed extensions: refuse to sign when this runtime wants
        // bytes the encoder would not write (or the reverse), instead of
        // submitting a transaction every node must reject.
        do {
            try Sora2SignedExtensionSupport.validate(metadata: factory.metadata)
        } catch let error as Sora2SignedExtensionSupport.Unsupported {
            throw ExtrinsicServiceError.unsupportedSignedExtension(
                identifier: error.identifier
            )
        }
    }

    /// Binds a metadata download to the runtime version the node reported.
    /// Both reads are separate RPC calls, so a runtime upgrade between them
    /// is detected here instead of caching a hash under the wrong version.
    static func liveRuntime(
        version: RuntimeVersion,
        metadataHex: String
    ) throws -> Sora2LiveRuntime {
        guard
            let metadataSHA256 =
                PolkamarktRuntimeContract.wireMetadataSHA256(metadataHex),
            let metadataBytes = try? Data(hexStringSSF: metadataHex),
            metadataBytes.count <=
                ReviewedSoraRuntimeSnapshotAdmission.maximumMetadataBytes
        else {
            throw ExtrinsicServiceError.unsupportedRuntimeMetadata
        }
        let metadata: RuntimeMetadata
        do {
            metadata = try RuntimeMetadata(
                scaleDecoder: try ScaleDecoder(data: metadataBytes)
            )
        } catch {
            throw ExtrinsicServiceError.unsupportedRuntimeMetadata
        }
        let declared: Sora2RuntimeIdentity
        do {
            declared = try Sora2RuntimeIdentity.declared(by: metadata)
        } catch {
            // No readable `System.Version`: not a SORA2 runtime.
            throw ExtrinsicServiceError.unsupportedRuntime(
                spec: version.specVersion,
                transaction: version.transactionVersion
            )
        }
        guard
            declared.specName == Sora2RuntimeIdentity.reviewedSpecName,
            declared.specVersion >= Sora2RuntimeIdentity.minimumSpecVersion
        else {
            // Not a SORA2 runtime this app can sign for. Waiting for a
            // runtime sync would not change that.
            throw ExtrinsicServiceError.unsupportedRuntime(
                spec: declared.specVersion,
                transaction: declared.transactionVersion
            )
        }
        guard
            declared.specVersion == version.specVersion,
            declared.transactionVersion == version.transactionVersion
        else {
            // The runtime changed between the two reads.
            throw ExtrinsicServiceError.runtimeUpgradeInProgress(
                spec: declared.specVersion,
                transaction: declared.transactionVersion
            )
        }
        return Sora2LiveRuntime(
            specVersion: version.specVersion,
            transactionVersion: version.transactionVersion,
            metadataSHA256: metadataSHA256
        )
    }

    /// Asks the runtime sync service to fetch the live runtime when the app's
    /// metadata is behind the node. A sync that is already running or
    /// scheduled is left alone.
    static func requestRuntimeRefresh(
        after error: Error,
        live: RuntimeVersion?,
        refresh: @escaping (RuntimeVersion, Bool) -> Void = { version, replacingCachedMetadata in
            ChainRegistryFacade.sharedRegistry.requestRuntimeRefresh(
                for: Chain.sora.genesisHash(),
                liveVersion: version,
                replacingCachedMetadata: replacingCachedMetadata
            )
        }
    ) {
        guard let live, let serviceError = error as? ExtrinsicServiceError else { return }
        let replacingCachedMetadata: Bool
        switch serviceError {
        case .runtimeUpgradeInProgress: replacingCachedMetadata = false
        case .unsupportedRuntimeMetadata: replacingCachedMetadata = true
        default: return
        }
        // Registry construction reads the app's active scene. A failed background
        // fee or signing operation must schedule that work on the UI thread.
        DispatchQueue.main.async { refresh(live, replacingCachedMetadata) }
    }
}

enum Sora2BoundedHTTPJSONRPCError: LocalizedError {
    case invalidEndpoint
    case methodNotAllowed
    case requestTooLarge
    case responseTooLarge
    case invalidResponse
    /// The node answered the HTTPS request with this status instead of 200.
    case httpStatus(Int)
    /// The address answered 200 with something that is not JSON (a web
    /// page, for example): there is no JSON-RPC service behind it.
    case notJSONRPC
    /// The node answered with a JSON-RPC error object: it received the
    /// request and refused it.
    case remoteError
    case subscriptionsUnavailable
    /// The node answered that it no longer keeps the state of the block
    /// asked for (JSON-RPC error "State already discarded": a node that
    /// prunes state, like the first bundled node, which keeps about 256
    /// blocks). The block itself may still be known to it. An archive node
    /// can answer the same question.
    case blockStateUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return WalletUX.text(
                "The selected node does not answer over HTTPS at its address, so the app can't prepare or send transactions through it. Balances still load. Choose another node in the node settings and try again."
            )
        case .methodNotAllowed, .requestTooLarge, .subscriptionsUnavailable:
            return WalletUX.text(
                "The app could not send this request to the SORA network. Please try again."
            )
        case .httpStatus, .notJSONRPC, .responseTooLarge, .invalidResponse,
             .blockStateUnavailable:
            // An HTTP refusal is described by what is known here: the node
            // gave no usable answer. Whether the node lacks the route
            // altogether depends on the status and on which node it is;
            // `Sora2SigningNotice` knows that and says so for a custom
            // node.
            return WalletUX.text(
                "The SORA node did not give a usable answer. Please try again in a moment, or choose another node."
            )
        case .remoteError:
            // The node is working: it read the request and said no.
            // Changing the node would not help.
            return WalletUX.text(
                "The SORA network did not accept this request. Please try again."
            )
        }
    }

    /// HTTP statuses that mean "nothing serves JSON-RPC at this address":
    /// not found, method not allowed, upgrade required (a WebSocket-only
    /// listener), not implemented. A busy or failing node answers 429, 502,
    /// 503 or 504 and works again a moment later; those are not here.
    static let missingRouteStatuses: Set<Int> = [404, 405, 426, 501]

    /// The answer shows that the address has no HTTPS JSON-RPC route at
    /// all, as opposed to a node that is in trouble for a moment.
    var indicatesMissingSigningRoute: Bool {
        switch self {
        case .invalidEndpoint, .notJSONRPC:
            return true
        case let .httpStatus(status):
            return Self.missingRouteStatuses.contains(status)
        default:
            return false
        }
    }

    /// The message for a failure of the signing route itself, or nil for
    /// any other error. Signing uses one-shot HTTPS requests at the node's
    /// own address, while balances use the node's WebSocket, so a node
    /// without that route shows balances and fails every send.
    static func signingRouteUserMessage(for error: Error) -> String? {
        guard let error = error as? Sora2BoundedHTTPJSONRPCError else {
            return nil
        }
        switch error {
        case .invalidEndpoint, .httpStatus, .notJSONRPC:
            return error.errorDescription
        default:
            return nil
        }
    }

    /// Recognises the node's "state already discarded" answer from the
    /// fields of a JSON-RPC error object. Nodes report it with code 4003 and
    /// a message naming the block; the wording differs between calls.
    static func isBlockStateUnavailable(message: String) -> Bool {
        let lowered = message.lowercased()
        return lowered.contains("state already discarded") ||
            lowered.contains("unknownblock") ||
            lowered.contains("unknown block")
    }
}

private final class Sora2OneShotURLSessionDelegate: NSObject,
    URLSessionTaskDelegate {
    static let shared = Sora2OneShotURLSessionDelegate()

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        needNewBodyStream completionHandler: @escaping (InputStream?) -> Void
    ) {
        // A replay that needs a second body is never authorized. The durable
        // journal, not URLSession, resolves an uncertain first handoff.
        completionHandler(nil)
    }
}

/// Tells the user why nothing can be sent when the reason is neither the
/// transaction nor the account: the app must be updated for a new signed
/// extension, or the selected node has no HTTPS route for signing. Every
/// signing flow (send, swap, liquidity, farming, referrals) builds its
/// extrinsic in one place, which reports here, so each of them gets the
/// explanation even where the flow itself shows only "try again". Nothing is
/// latched: the notice follows an actual failed attempt, at most once per
/// `minimumInterval`.
enum Sora2SigningNotice {
    enum Kind: Hashable {
        case appUpdateRequired
        case nodeWithoutSigningRoute
    }

    /// Fee estimates repeat while a send or swap screen is open; the
    /// notice must not come back every few seconds.
    static let minimumInterval: TimeInterval = 120

    private static let lock = NSLock()
    private static var lastShown: [Kind: Date] = [:]
    /// Replaced in tests. Called on any thread.
    static var present: (Kind, String) -> Void = Sora2SigningNotice.presentAlert

    static func kind(for error: Error, nodeURL: URL?) -> Kind? {
        var error = error
        if let transport = error as? PreparedExtrinsicTransportError {
            error = transport.underlyingError
        }
        if let serviceError = error as? ExtrinsicServiceError,
           case .unsupportedSignedExtension = serviceError {
            return .appUpdateRequired
        }
        guard let nodeError = error as? Sora2BoundedHTTPJSONRPCError else {
            return nil
        }
        // Only an answer that shows the route is not there. A node that
        // answers 429, 502 or 503 once is busy, and is told apart from a
        // node that can never send: the flow's own "try again" covers it.
        guard nodeError.indicatesMissingSigningRoute else {
            return nil
        }
        if case .invalidEndpoint = nodeError {
            return .nodeWithoutSigningRoute
        }
        // A bundled node has the route; whatever it answered, it is having
        // trouble, not missing it.
        return isBundledNode(nodeURL) ? nil : .nodeWithoutSigningRoute
    }

    static func message(for kind: Kind) -> String {
        switch kind {
        case .appUpdateRequired:
            return ExtrinsicServiceError.runtimeUserMessage(
                for: ExtrinsicServiceError.unsupportedSignedExtension(
                    identifier: ""
                )
            ) ?? ""
        case .nodeWithoutSigningRoute:
            return Sora2BoundedHTTPJSONRPCError.invalidEndpoint
                .errorDescription ?? ""
        }
    }

    /// Shows the notice for `error` if it has one and none of its kind was
    /// shown in the last `minimumInterval` seconds.
    @discardableResult
    static func report(
        _ error: Error,
        nodeURL: URL?,
        now: Date = Date()
    ) -> Kind? {
        guard let kind = kind(for: error, nodeURL: nodeURL) else {
            return nil
        }
        lock.lock()
        if let last = lastShown[kind],
           abs(now.timeIntervalSince(last)) < minimumInterval {
            lock.unlock()
            return nil
        }
        lastShown[kind] = now
        let present = self.present
        lock.unlock()
        present(kind, message(for: kind))
        return kind
    }

    static func resetForTesting() {
        lock.lock()
        lastShown.removeAll()
        lock.unlock()
    }

    private static func isBundledNode(_ url: URL?) -> Bool {
        guard let host = url?.host?.lowercased() else {
            return false
        }
        return SoraNodeConnectionPolicy.bundledMainnetNodes.contains {
            $0.url.host?.lowercased() == host
        }
    }

    private static func presentAlert(_: Kind, _ message: String) {
        DispatchQueue.main.async {
            guard
                NSClassFromString("XCTestCase") == nil,
                let root = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .flatMap(\.windows)
                    .first(where: \.isKeyWindow)?
                    .rootViewController
            else {
                return
            }
            let top = root.topModalViewController
            guard !(top is UIAlertController) else {
                return
            }
            UIAlertController.present(
                message: message,
                title: nil,
                closeAction: R.string.localizable.commonOk(
                    preferredLanguages: .currentLocale
                ),
                with: top
            )
        }
    }
}

/// One-shot SORA2 RPC transport for every mutation/status request that does
/// not require a subscription. It deliberately has no reconnect/resend path:
/// `author_submitExtrinsic` is issued at most once, and a lost response remains
/// ambiguous for the durable recovery journal.
final class Sora2BoundedHTTPJSONRPCEngine: JSONRPCEngine,
    @unchecked Sendable {
    static let maximumRequestBytes = 2 * 1024 * 1024
    static let maximumResponseBytes = 8 * 1024 * 1024
    static let maximumJSONDepth = 96
    static let maximumJSONTokens = 1_000_000

    private static let allowedMethods: Set<String> = [
        RPCMethod.getExtrinsicNonce,
        RPCMethod.getHead,
        RPCMethod.getHeader,
        RPCMethod.getBlockHash,
        RPCMethod.getRuntimeVersion,
        RPCMethod.getRuntimeMetadata,
        RPCMethod.getChainBlock,
        RPCMethod.getStorage,
        RPCMethod.queryStorageAt,
        RPCMethod.paymentInfo,
        RPCMethod.feeDetails,
        RPCMethod.freeBalance,
        RPCMethod.needsMigration,
        RPCMethod.submitExtrinsic,
        PolkamarktRuntimeContract.RPC.quoteBuy,
        PolkamarktRuntimeContract.RPC.quoteSell,
        PolkamarktRuntimeContract.RPC.marketState,
        PolkamarktRuntimeContract.RPC.claimable
    ]

    private struct Request<Parameters: Encodable>: Encodable {
        let identifier: UInt16
        let method: String
        let parameters: Parameters?

        private enum CodingKeys: String, CodingKey {
            case jsonrpc
            case id
            case method
            case params
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode("2.0", forKey: .jsonrpc)
            try container.encode(identifier, forKey: .id)
            try container.encode(method, forKey: .method)
            if let parameters {
                try container.encode(parameters, forKey: .params)
            } else {
                try container.encode([String](), forKey: .params)
            }
        }
    }

    private struct Response<Value: Decodable>: Decodable {
        let value: Value

        private enum CodingKeys: String, CodingKey {
            case result
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            value = try container.decode(Value.self, forKey: .result)
        }
    }

    private let sourceEngine: JSONRPCEngine?
    /// Set instead of `sourceEngine` for a node addressed directly (an
    /// archive node asked for old state, a node being checked before it is
    /// saved). It never follows the app's selected connection.
    private let fixedNodeURL: URL?
    private let session: URLSession
    private let lock = NSLock()
    private var nextIdentifier: UInt16 = 1
    private var reservedIdentifiers = Set<UInt16>()
    private var completedBeforePublication = Set<UInt16>()
    private var tasks: [UInt16: Task<Void, Never>] = [:]

    static func wrapping(
        _ engine: JSONRPCEngine,
        session: URLSession? = nil
    ) -> JSONRPCEngine {
        if engine is Sora2BoundedHTTPJSONRPCEngine {
            return engine
        }
        return Sora2BoundedHTTPJSONRPCEngine(
            sourceEngine: engine,
            session: session
        )
    }

    convenience init(sourceEngine: JSONRPCEngine, session: URLSession? = nil) {
        self.init(
            sourceEngine: sourceEngine,
            fixedNodeURL: nil,
            session: session
        )
    }

    /// A one-shot engine for exactly the node at `nodeURL` (`wss://` or
    /// `https://`), independent of the app's selected connection.
    convenience init(nodeURL: URL, session: URLSession? = nil) {
        self.init(sourceEngine: nil, fixedNodeURL: nodeURL, session: session)
    }

    private init(
        sourceEngine: JSONRPCEngine?,
        fixedNodeURL: URL?,
        session: URLSession?
    ) {
        self.sourceEngine = sourceEngine
        self.fixedNodeURL = fixedNodeURL
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 20
            configuration.timeoutIntervalForResource = 45
            configuration.waitsForConnectivity = false
            configuration.httpMaximumConnectionsPerHost = 4
            configuration.httpShouldSetCookies = false
            configuration.httpCookieStorage = nil
            configuration.urlCredentialStorage = nil
            configuration.urlCache = nil
            configuration.requestCachePolicy =
                .reloadIgnoringLocalCacheData
            self.session = URLSession(
                configuration: configuration,
                delegate: Sora2OneShotURLSessionDelegate.shared,
                delegateQueue: nil
            )
        }
    }

    var url: URL? {
        get { sourceEngine?.url ?? fixedNodeURL }
        set { sourceEngine?.url = newValue }
    }

    var pendingEngineRequests: [JSONRPCRequest] {
        // Requests are dispatched immediately and are never queued for a
        // reconnect, so exposing an empty pending queue is intentional.
        []
    }

    @discardableResult
    func callMethod<Parameters: Codable, Value: Decodable>(
        _ method: String,
        params: Parameters?,
        options _: JSONRPCOptions,
        completion: ((Result<Value, Error>) -> Void)?
    ) throws -> UInt16 {
        guard Self.isAllowedMethod(method) else {
            throw Sora2BoundedHTTPJSONRPCError.methodNotAllowed
        }
        if method == RPCMethod.submitExtrinsic {
            guard
                let params,
                let signedExtrinsics = params as? [String],
                signedExtrinsics.count == 1,
                let signedExtrinsic = signedExtrinsics.first,
                Self.isCanonicalSignedExtrinsic(signedExtrinsic)
            else {
                throw Sora2BoundedHTTPJSONRPCError.invalidResponse
            }
        }
        let identifier = try reserveIdentifier()
        let task = Task { [weak self] in
            let result: Result<Value, Error>
            do {
                guard let self else {
                    throw Sora2BoundedHTTPJSONRPCError.invalidEndpoint
                }
                result = .success(
                    try await self.perform(
                        method: method,
                        parameters: params,
                        identifier: identifier
                    )
                )
            } catch is CancellationError {
                result = .failure(JSONRPCEngineError.clientCancelled)
            } catch let error as Sora2BoundedHTTPJSONRPCError {
                result = .failure(error)
            } catch {
                // Do not retain or surface a decoder/server error that could
                // contain an account-bound response fragment.
                result = .failure(
                    Sora2BoundedHTTPJSONRPCError.invalidResponse
                )
            }
            completion?(result)
            self?.finish(identifier: identifier)
        }
        publish(task: task, identifier: identifier)
        return identifier
    }

    func subscribe<Parameters: Codable, Value: Decodable>(
        _ method: String,
        params: Parameters?,
        updateClosure: @escaping (Value) -> Void,
        failureClosure: @escaping (Error, Bool) -> Void
    ) throws -> UInt16 {
        throw Sora2BoundedHTTPJSONRPCError.subscriptionsUnavailable
    }

    func cancelForIdentifier(_ identifier: UInt16) {
        lock.lock()
        let task = tasks.removeValue(forKey: identifier)
        reservedIdentifiers.remove(identifier)
        completedBeforePublication.remove(identifier)
        lock.unlock()
        task?.cancel()
    }

    func generateRequestId() -> UInt16 {
        lock.lock()
        defer { lock.unlock() }
        return nextAvailableIdentifierLocked()
    }

    func addSubscription(_ subscription: JSONRPCSubscribing) {
        subscription.handle(
            error: Sora2BoundedHTTPJSONRPCError.subscriptionsUnavailable,
            unsubscribed: true
        )
    }

    func reconnect(url: URL) {
        self.url = url
    }

    func connectIfNeeded() {}

    func disconnectIfNeeded() {
        lock.lock()
        let active = Array(tasks.values)
        tasks.removeAll(keepingCapacity: false)
        reservedIdentifiers.removeAll(keepingCapacity: false)
        completedBeforePublication.removeAll(keepingCapacity: false)
        lock.unlock()
        active.forEach { $0.cancel() }
    }

    func unsubsribe(_ identifier: UInt16) throws {
        throw Sora2BoundedHTTPJSONRPCError.subscriptionsUnavailable
    }

    static func httpEndpoint(for nodeURL: URL?) throws -> URL {
        guard
            let nodeURL,
            !SoraNodeConnectionPolicy.isCompromisedEndpoint(nodeURL),
            var components = URLComponents(
                url: nodeURL,
                resolvingAgainstBaseURL: false
            ),
            components.scheme?.lowercased() == "wss" ||
                components.scheme?.lowercased() == "https",
            components.host?.isEmpty == false,
            components.user == nil,
            components.password == nil,
            components.fragment == nil
        else {
            throw Sora2BoundedHTTPJSONRPCError.invalidEndpoint
        }
        components.scheme = "https"
        if components.path.isEmpty {
            components.path = "/"
        }
        guard
            let endpoint = components.url,
            endpoint.scheme == "https",
            endpoint.host != nil
        else {
            throw Sora2BoundedHTTPJSONRPCError.invalidEndpoint
        }
        return endpoint
    }

    static func acceptsJSONContentType(_ value: String?) -> Bool {
        guard let value else { return false }
        let parts = value.split(
            separator: ";",
            omittingEmptySubsequences: false
        ).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
        }
        guard parts.first == "application/json" else { return false }
        return parts.count == 1 ||
            (parts.count == 2 && parts[1] == "charset=utf-8")
    }

    static func isAllowedMethod(_ method: String) -> Bool {
        allowedMethods.contains(method)
    }

    static func isCanonicalSignedExtrinsic(_ value: String) -> Bool {
        guard
            value.hasPrefix("0x"),
            value.utf8.count > 2,
            value.utf8.count <= maximumRequestBytes - 256,
            value.utf8.count.isMultiple(of: 2)
        else {
            return false
        }
        return value.dropFirst(2).unicodeScalars.allSatisfy {
            (48 ... 57).contains($0.value) ||
                (97 ... 102).contains($0.value)
        }
    }

    static func validateExpectedResponseLength(_ value: Int64) throws {
        guard
            value < 0 || value <= Int64(maximumResponseBytes)
        else {
            throw Sora2BoundedHTTPJSONRPCError.responseTooLarge
        }
    }

    private func perform<Parameters: Encodable, Value: Decodable>(
        method: String,
        parameters: Parameters?,
        identifier: UInt16
    ) async throws -> Value {
        try Task.checkCancellation()
        let endpoint = try Self.httpEndpoint(for: url)
        let body = try JSONEncoder().encode(
            Request(
                identifier: identifier,
                method: method,
                parameters: parameters
            )
        )
        guard body.count <= Self.maximumRequestBytes else {
            throw Sora2BoundedHTTPJSONRPCError.requestTooLarge
        }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = body
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        request.setValue(
            "no-store, no-cache, max-age=0",
            forHTTPHeaderField: "Cache-Control"
        )
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")

        let (bytes, response) = try await session.bytes(for: request)
        guard
            let http = response as? HTTPURLResponse,
            http.url == endpoint,
            http.statusCode == 200,
            Self.acceptsJSONContentType(
                http.value(forHTTPHeaderField: "Content-Type")
            ),
            http.value(forHTTPHeaderField: "Content-Encoding")
                .map({ $0.caseInsensitiveCompare("identity") == .orderedSame })
                ?? true
        else {
            if let http = response as? HTTPURLResponse {
                if http.statusCode != 200 {
                    throw Sora2BoundedHTTPJSONRPCError.httpStatus(
                        http.statusCode
                    )
                }
                if http.url == endpoint,
                   !Self.acceptsJSONContentType(
                       http.value(forHTTPHeaderField: "Content-Type")
                   ) {
                    throw Sora2BoundedHTTPJSONRPCError.notJSONRPC
                }
            }
            throw Sora2BoundedHTTPJSONRPCError.invalidResponse
        }
        try Self.validateExpectedResponseLength(
            http.expectedContentLength
        )
        var data = Data()
        if http.expectedContentLength > 0 {
            data.reserveCapacity(Int(http.expectedContentLength))
        }
        for try await byte in bytes {
            guard data.count < Self.maximumResponseBytes else {
                throw Sora2BoundedHTTPJSONRPCError.responseTooLarge
            }
            data.append(byte)
        }
        try PIStrictJSONAdmission.validate(
            data,
            maximumBytes: Self.maximumResponseBytes,
            maximumDepth: Self.maximumJSONDepth,
            maximumTokens: Self.maximumJSONTokens
        )
        try Self.validateEnvelope(data, identifier: identifier)
        do {
            return try JSONDecoder().decode(
                Response<Value>.self,
                from: data
            ).value
        } catch {
            throw Sora2BoundedHTTPJSONRPCError.invalidResponse
        }
    }

    static func validateEnvelope(
        _ data: Data,
        identifier: UInt16
    ) throws {
        guard
            let object = try JSONSerialization.jsonObject(with: data)
                as? [String: Any],
            object["jsonrpc"] as? String == "2.0",
            let responseIdentifier = object["id"] as? NSNumber,
            CFGetTypeID(responseIdentifier) != CFBooleanGetTypeID(),
            responseIdentifier.stringValue == String(identifier)
        else {
            throw Sora2BoundedHTTPJSONRPCError.invalidResponse
        }
        let keys = Set(object.keys)
        if object.keys.contains("result") {
            guard keys == ["jsonrpc", "id", "result"] else {
                throw Sora2BoundedHTTPJSONRPCError.invalidResponse
            }
            return
        }
        guard
            keys == ["jsonrpc", "id", "error"],
            let remote = object["error"] as? [String: Any],
            Set(remote.keys).isSubset(of: ["code", "message", "data"]),
            let code = remote["code"] as? NSNumber,
            CFGetTypeID(code) != CFBooleanGetTypeID(),
            code.stringValue.range(
                of: #"^-?(?:0|[1-9][0-9]{0,9})$"#,
                options: .regularExpression
            ) != nil,
            let message = remote["message"] as? String,
            !message.isEmpty,
            message.utf8.count <= 4_096
        else {
            throw Sora2BoundedHTTPJSONRPCError.invalidResponse
        }
        // Only the class of the refusal is kept; the node's text (which
        // names blocks or accounts) is never stored or shown.
        if Sora2BoundedHTTPJSONRPCError.isBlockStateUnavailable(
            message: message
        ) {
            throw Sora2BoundedHTTPJSONRPCError.blockStateUnavailable
        }
        throw Sora2BoundedHTTPJSONRPCError.remoteError
    }

    private func reserveIdentifier() throws -> UInt16 {
        lock.lock()
        defer { lock.unlock() }
        guard reservedIdentifiers.count < Int(UInt16.max) else {
            throw Sora2BoundedHTTPJSONRPCError.invalidResponse
        }
        let identifier = nextAvailableIdentifierLocked()
        reservedIdentifiers.insert(identifier)
        nextIdentifier = identifier == UInt16.max ? 1 : identifier + 1
        return identifier
    }

    private func nextAvailableIdentifierLocked() -> UInt16 {
        var candidate = nextIdentifier == 0 ? 1 : nextIdentifier
        while reservedIdentifiers.contains(candidate) {
            candidate = candidate == UInt16.max ? 1 : candidate + 1
        }
        return candidate
    }

    private func publish(task: Task<Void, Never>, identifier: UInt16) {
        lock.lock()
        if completedBeforePublication.remove(identifier) != nil {
            reservedIdentifiers.remove(identifier)
            lock.unlock()
            return
        }
        guard reservedIdentifiers.contains(identifier) else {
            lock.unlock()
            task.cancel()
            return
        }
        tasks[identifier] = task
        lock.unlock()
    }

    private func finish(identifier: UInt16) {
        lock.lock()
        guard reservedIdentifiers.contains(identifier) else {
            lock.unlock()
            return
        }
        if tasks.removeValue(forKey: identifier) != nil {
            reservedIdentifiers.remove(identifier)
        } else {
            completedBeforePublication.insert(identifier)
        }
        lock.unlock()
    }
}

/// Distinguishes failures known to occur before transport was invoked from
/// failures after signed bytes may have left the device. Callers must never
/// reconcile or retry a definitive pre-transport failure as ambiguous.
struct Sora2SubmissionUnknownContext: Error {
    let transactionHash: String
    let underlyingError: Error

    init(transactionHash: String, underlyingError: Error) {
        self.transactionHash =
            Sora2PendingSubmissionStore.normalizedHash(transactionHash) ??
            transactionHash
        self.underlyingError = underlyingError
    }

    var canonicalTransactionHash: String? {
        guard
            Sora2PendingSubmissionStore.normalizedHash(transactionHash) ==
                transactionHash
        else {
            return nil
        }
        return transactionHash
    }
}

enum PreparedExtrinsicTransportError: Error {
    case failedBeforeTransport(Error)
    case submissionUnknown(Error)

    static func submissionUnknown(
        localHash: String,
        error: Error
    ) -> PreparedExtrinsicTransportError {
        .submissionUnknown(
            Sora2SubmissionUnknownContext(
                transactionHash: localHash,
                underlyingError: error
            )
        )
    }

    var underlyingError: Error {
        switch self {
        case let .failedBeforeTransport(error):
            return error
        case let .submissionUnknown(error):
            return (error as? Sora2SubmissionUnknownContext)?
                .underlyingError ?? error
        }
    }

    /// The canonical hash of the exact signed bytes which may have entered
    /// transport. This is deliberately absent for definitive pre-transport
    /// failures so callers cannot accidentally render those failures as a
    /// pending transaction.
    var submissionUnknownLocalHash: String? {
        guard
            case let .submissionUnknown(error) = self,
            let context = error as? Sora2SubmissionUnknownContext
        else {
            return nil
        }
        return context.canonicalTransactionHash
    }
}

/// Converts only a transport-ambiguous failure into the hash of a pending
/// SORA2 transaction. All unrelated, cancelled-before-handoff, and malformed
/// results remain failures. Keeping this policy shared by the node factory,
/// facade, and confirmation UI prevents any layer from inventing a hash or
/// encouraging a retry after signed bytes may have left the device.
enum Sora2LegacySubmissionProjection {
    static func transactionHash(
        from result: Result<String, Error>?
    ) throws -> String {
        switch result {
        case let .success(hash):
            guard let normalized =
                Sora2PendingSubmissionStore.normalizedHash(hash)
            else {
                throw ExtrinsicServiceError.invalidLocalHash
            }
            return normalized
        case let .failure(error):
            guard
                let transportError =
                    error as? PreparedExtrinsicTransportError,
                let localHash =
                    transportError.submissionUnknownLocalHash
            else {
                throw error
            }
            return localHash
        case .none:
            throw BaseOperationError.parentOperationCancelled
        }
    }

    static func transactionHash(
        from result: Result<Data, Error>?
    ) throws -> Data {
        switch result {
        case let .success(hash):
            guard
                Sora2PendingSubmissionStore.normalizedHash(
                    hash.toHex(includePrefix: true)
                ) != nil
            else {
                throw ExtrinsicServiceError.invalidLocalHash
            }
            return hash
        case let .failure(error):
            guard
                let transportError =
                    error as? PreparedExtrinsicTransportError,
                let localHash =
                    transportError.submissionUnknownLocalHash
            else {
                throw error
            }
            return try Data(hexStringSSF: localHash)
        case .none:
            throw BaseOperationError.parentOperationCancelled
        }
    }
}

enum Sora2TransportCompletionPolicy {
    /// Once the RPC transport has returned success, persistence trouble in the
    /// local reconciliation journal cannot make those already-submitted bytes
    /// safe to retry. Retain the success and leave the prior durable
    /// `submitting` entry as the conservative recovery marker.
    static func preservingConfirmedSuccess<Value>(
        _ result: Result<Value, Error>,
        journalUpdate: () throws -> Void
    ) -> Result<Value, Error> {
        guard case .success = result else {
            return result
        }
        try? journalUpdate()
        return result
    }
}

/// Owns the sole mutable transport copy of signed bytes after a prepared
/// submission has been consumed. Configuration converts and immediately
/// zeroizes that storage; completion also discards it for cancellation paths.
final class MutableSignedTransportPayload: @unchecked Sendable {
    private let lock = NSLock()
    private var signedData: Data?

    init(data: Data) {
        // Force an owned copy so wiping this box never relies on Data's
        // copy-on-write uniqueness or leaves PreparedExtrinsicSubmission's
        // captured storage intact.
        signedData = data.withUnsafeBytes { Data($0) }
    }

    /// Returns a temporary encoding for `payment_queryFeeDetails` without consuming the one-shot
    /// transport capability. The exact same owned bytes remain available for the sole submission.
    func hexForFeeQualification() throws -> String {
        lock.lock()
        defer { lock.unlock() }
        guard let signedData else {
            throw ExtrinsicServiceError.preparedSubmissionAlreadyConsumed
        }
        return signedData.toHex(includePrefix: true)
    }

    func consumeHexForTransport() throws -> String {
        lock.lock()
        defer { lock.unlock() }
        guard signedData != nil else {
            throw ExtrinsicServiceError.preparedSubmissionAlreadyConsumed
        }
        let signedHex = signedData!.toHex(includePrefix: true)
        wipeLocked()
        return signedHex
    }

    func discard() {
        lock.lock()
        wipeLocked()
        lock.unlock()
    }

    private func wipeLocked() {
        guard signedData != nil else {
            return
        }
        let byteRange =
            signedData!.startIndex ..< signedData!.endIndex
        signedData!.resetBytes(in: byteRange)
        signedData = nil
    }

    deinit {
        discard()
    }
}

private enum PreparedExtrinsicRPCOperationError: Error {
    case timeout
}

enum Sora2SignedFeeRevalidation {
    @discardableResult
    static func requireExact(
        expectedRawFee: String,
        actualRawFee: String
    ) throws -> BigUInt {
        guard let expected = BigUInt(expectedRawFee),
              expected > 0,
              let actual = BigUInt(actualRawFee),
              actual > 0,
              actual == expected else {
            throw WalletNetworkOperationFactoryError.invalidFee
        }
        return actual
    }
}

/// Mirrors the bounded JSON-RPC operation while exposing the exact point at
/// which the engine is invoked. Merely configuring parameters is still a
/// definitive pre-transport state.
private final class PreparedExtrinsicRPCOperation: BaseOperation<String> {
    let engine: JSONRPCEngine
    let method: String
    var parameters: [String]?
    let timeout: Int
    let preTransportValidation: () throws -> Void
    let transportDidHandoff: () -> Void
    private var requestId: UInt16?
    private let phaseLock = NSLock()
    private var transportStarted = false

    init(
        engine: JSONRPCEngine,
        method: String,
        parameters: [String]? = nil,
        timeout: Int,
        preTransportValidation: @escaping () throws -> Void,
        transportDidHandoff: @escaping () -> Void
    ) {
        self.engine = engine
        self.method = method
        self.parameters = parameters
        self.timeout = timeout
        self.preTransportValidation = preTransportValidation
        self.transportDidHandoff = transportDidHandoff
        super.init()
    }

    var mayHaveEnteredTransport: Bool {
        phaseLock.lock()
        defer { phaseLock.unlock() }
        return transportStarted
    }

    override func main() {
        super.main()

        guard !isCancelled, result == nil else {
            return
        }

        let semaphore = DispatchSemaphore(value: 0)
        var callResult: Result<String, Error>?
        do {
            try preTransportValidation()
            guard !isCancelled else {
                throw BaseOperationError.parentOperationCancelled
            }
            // Serialize the final cancellation check, engine handoff, and
            // request-id publication. A dismissal cannot slip between them
            // and leave a newly issued request outside cancel()'s reach.
            phaseLock.lock()
            guard !isCancelled else {
                phaseLock.unlock()
                throw BaseOperationError.parentOperationCancelled
            }
            transportStarted = true
            do {
                let issuedRequestId = try engine.callMethod(
                    method,
                    params: parameters
                ) { (response: Result<String, Error>) in
                    callResult = response
                    semaphore.signal()
                }
                requestId = issuedRequestId
                phaseLock.unlock()
            } catch {
                phaseLock.unlock()
                transportDidHandoff()
                throw error
            }
            // The engine now owns the request. Wallet lifecycle mutations no
            // longer need to wait for its response or bounded timeout.
            transportDidHandoff()

            guard
                semaphore.wait(
                    timeout: .now() + .seconds(timeout)
                ) != .timedOut
            else {
                if let requestId {
                    engine.cancelForIdentifier(requestId)
                }
                result = .failure(
                    PreparedExtrinsicRPCOperationError.timeout
                )
                return
            }

            if let callResult {
                result = callResult
            }
        } catch {
            result = .failure(error)
        }
    }

    override func cancel() {
        phaseLock.lock()
        super.cancel()
        let issuedRequestId = requestId
        phaseLock.unlock()
        if let requestId = issuedRequestId {
            engine.cancelForIdentifier(requestId)
        }
    }
}

/// Signed bytes are a one-shot capability. Once transport consumes them they
/// cannot be submitted again by a retrying caller.
final class PreparedExtrinsicSubmission: @unchecked Sendable {
    private let lock = NSLock()
    private var signedData: Data?
    let hash: String
    let call: JSON?
    let recoveryContext: Sora2SubmissionRecoveryContext?

    init(
        data: Data,
        hash: String,
        call: JSON? = nil,
        recoveryContext: Sora2SubmissionRecoveryContext? = nil
    ) {
        signedData = data.withUnsafeBytes { Data($0) }
        self.hash = hash
        self.call = call
        self.recoveryContext = recoveryContext
    }

    func consumeForTransport() throws -> MutableSignedTransportPayload {
        lock.lock()
        defer { lock.unlock() }
        guard signedData != nil else {
            throw ExtrinsicServiceError.preparedSubmissionAlreadyConsumed
        }
        guard
            Sora2PendingSubmissionStore.normalizedHash(
                try signedData!.blake2b32().toHex(includePrefix: true)
            ) ==
                Sora2PendingSubmissionStore.normalizedHash(hash)
        else {
            wipeLocked()
            throw ExtrinsicServiceError.invalidLocalHash
        }
        let payload = MutableSignedTransportPayload(
            data: signedData!
        )
        wipeLocked()
        return payload
    }

    func discard() {
        lock.lock()
        wipeLocked()
        lock.unlock()
    }

    private func wipeLocked() {
        guard signedData != nil else {
            return
        }
        let byteRange =
            signedData!.startIndex ..< signedData!.endIndex
        signedData!.resetBytes(in: byteRange)
        signedData = nil
    }

    deinit {
        discard()
    }
}

private final class EmptyCancellableCall: CancellableCall {
    func cancel() {}
}

/// Bridges callback-based cancellable work into Swift tasks without a race
/// between task cancellation and publication of the underlying call.
final class CancellableCallRelay: @unchecked Sendable {
    private let lock = NSLock()
    private var call: CancellableCall?
    private var isCancelled = false

    func set(_ call: CancellableCall) {
        lock.lock()
        if isCancelled {
            lock.unlock()
            call.cancel()
            return
        }
        self.call = call
        lock.unlock()
    }

    func cancel() {
        lock.lock()
        isCancelled = true
        let call = call
        self.call = nil
        lock.unlock()
        call?.cancel()
    }
}

enum Sora2PendingSubmissionState: String, Codable {
    /// A feature journal has durably recorded the exact signed hash, but the
    /// final RPC pre-transport barrier has not run. This value is deliberately
    /// non-prunable and unknown to older builds, so rollback fails closed
    /// instead of erasing the only proof that transport never started.
    case stagedBeforeTransport
    case submitting
    case submitted
    /// Transport returned success, but the owning feature journal has not yet
    /// durably acknowledged that result. Keep this witness non-prunable until
    /// the feature journal advances from its signed-before-transport phase.
    case submittedRetained
    case submissionUnknown
}

enum Sora2PendingSubmissionPurpose: String, Codable {
    case generic
    case legacyMigration
    case polkamarkt
}

/// Versioned, non-secret identity for status-only recovery of one exact mortal
/// SORA2 extrinsic. A witness without this complete identity remains ambiguous:
/// it can still be reconciled by an owning feature journal, but generic restart
/// recovery must never guess its chain, runtime, wallet, or era.
struct Sora2SubmissionRecoveryContext: Codable, Equatable {
    static let currentSchemaVersion = 1
    static let reviewedEraPeriod = 64

    let schemaVersion: Int
    let walletId: String
    let accountId: String
    let publicKey: String
    let transactionHash: String
    let genesisHash: String
    let specVersion: UInt32
    let transactionVersion: UInt32
    let metadataSHA256: String
    let eraBirthBlock: Int
    let eraDeathBlockExclusive: Int
    let eraPeriod: Int
    let eraPhase: Int
    let eraBirthBlockHash: String

    static func make(
        walletId: String,
        accountId: Data,
        publicKey: Data,
        transactionHash: String,
        genesisHash: String,
        specVersion: UInt32,
        transactionVersion: UInt32,
        metadataSHA256: String,
        era: Era,
        eraBirthBlock: Int,
        eraBirthBlockHash: String
    ) throws -> Sora2SubmissionRecoveryContext {
        let deathResult = eraBirthBlock.addingReportingOverflow(
            reviewedEraPeriod
        )
        guard
            case let .mortal(period, phase) = era,
            eraBirthBlock >= 0,
            period == UInt64(reviewedEraPeriod),
            phase == UInt64(eraBirthBlock % reviewedEraPeriod),
            !deathResult.overflow,
            let canonicalTransactionHash =
                Sora2PendingSubmissionStore.normalizedHash(transactionHash),
            let canonicalGenesisHash =
                Sora2PendingSubmissionStore.normalizedHash(genesisHash),
            let reviewedGenesisHash =
                Sora2PendingSubmissionStore.normalizedHash(
                    PIIndexerClient.soraMainnetGenesis
                ),
            canonicalGenesisHash == reviewedGenesisHash,
            let canonicalEraHash =
                Sora2PendingSubmissionStore.normalizedHash(eraBirthBlockHash)
        else {
            throw ExtrinsicServiceError.invalidPendingSubmissionTransition
        }
        let context = Sora2SubmissionRecoveryContext(
            schemaVersion: currentSchemaVersion,
            walletId: walletId,
            accountId: accountId.toHex(includePrefix: false).lowercased(),
            publicKey: publicKey.toHex(includePrefix: false).lowercased(),
            transactionHash: canonicalTransactionHash,
            genesisHash: canonicalGenesisHash,
            specVersion: specVersion,
            transactionVersion: transactionVersion,
            metadataSHA256: metadataSHA256,
            eraBirthBlock: eraBirthBlock,
            eraDeathBlockExclusive: deathResult.partialValue,
            eraPeriod: reviewedEraPeriod,
            eraPhase: Int(phase),
            eraBirthBlockHash: canonicalEraHash
        )
        guard context.isValid(
            account: walletId,
            hash: canonicalTransactionHash
        ) else {
            throw ExtrinsicServiceError.invalidPendingSubmissionTransition
        }
        return context
    }

    func isValid(account: String, hash: String) -> Bool {
        let (expectedDeath, overflow) = eraBirthBlock
            .addingReportingOverflow(eraPeriod)
        return
            schemaVersion == Self.currentSchemaVersion &&
            !walletId.isEmpty &&
            walletId.utf8.count <= 512 &&
            walletId == account &&
            accountId.count == 64 &&
            accountId == accountId.lowercased() &&
            accountId.unicodeScalars.allSatisfy({
                (48 ... 57).contains($0.value) ||
                    (97 ... 102).contains($0.value)
            }) &&
            accountId.contains(where: { $0 != "0" }) &&
            [64, 66, 130].contains(publicKey.count) &&
            publicKey == publicKey.lowercased() &&
            publicKey.unicodeScalars.allSatisfy({
                (48 ... 57).contains($0.value) ||
                    (97 ... 102).contains($0.value)
            }) &&
            publicKey.contains(where: { $0 != "0" }) &&
            Sora2PendingSubmissionStore.normalizedHash(transactionHash) ==
                transactionHash &&
            transactionHash == hash &&
            Sora2PendingSubmissionStore.normalizedHash(genesisHash) ==
                genesisHash &&
            Sora2PendingSubmissionStore.normalizedHash(
                PIIndexerClient.soraMainnetGenesis
            ) == genesisHash &&
            // Any reviewed-floor runtime: contexts written at runtime 130
            // stay valid, and new ones record whatever runtime signed them.
            specVersion >= Sora2RuntimeIdentity.minimumSpecVersion &&
            transactionVersion > 0 &&
            metadataSHA256.count == 64 &&
            metadataSHA256.unicodeScalars.allSatisfy({
                (48 ... 57).contains($0.value) ||
                    (97 ... 102).contains($0.value)
            }) &&
            eraBirthBlock >= 0 &&
            eraPeriod == Self.reviewedEraPeriod &&
            eraPhase == eraBirthBlock % eraPeriod &&
            !overflow &&
            eraDeathBlockExclusive == expectedDeath &&
            Sora2PendingSubmissionStore.normalizedHash(
                eraBirthBlockHash
            ) == eraBirthBlockHash
    }
}

struct Sora2PendingTerminalResolution: Codable, Equatable {
    enum Kind: String, Codable {
        case finalizedSuccess
        case finalizedFailure
        case expiredNotIncluded
    }

    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let kind: Kind
    let blockNumber: Int?
    let blockHash: String?
    let finalizedHeight: Int

    func isValid(for context: Sora2SubmissionRecoveryContext) -> Bool {
        guard
            schemaVersion == Self.currentSchemaVersion,
            finalizedHeight >= 0
        else {
            return false
        }
        switch kind {
        case .finalizedSuccess, .finalizedFailure:
            guard
                let blockNumber,
                context.eraBirthBlock <= blockNumber,
                blockNumber < context.eraDeathBlockExclusive,
                finalizedHeight >= blockNumber,
                let blockHash,
                Sora2PendingSubmissionStore.normalizedHash(blockHash) ==
                    blockHash
            else {
                return false
            }
            return true
        case .expiredNotIncluded:
            return blockNumber == nil &&
                blockHash == nil &&
                finalizedHeight >= context.eraDeathBlockExclusive
        }
    }
}

/// Where a submitted transaction sits on the finalized canonical chain,
/// recorded when the block was found but its execution result could not be
/// read yet (the connected node had already discarded that block's state and
/// no archive node or indexer answered). The transaction is final and can no
/// longer enter the chain a second time, so the entry stops protecting
/// anything; only its result is still missing, and later passes read just
/// that, without scanning blocks again.
struct Sora2PendingFinalizedInclusion: Codable, Equatable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let blockNumber: Int
    let blockHash: String
    let extrinsicIndex: UInt32
    let finalizedHeight: Int
    /// When the inclusion was written down. The time the result is still
    /// looked for counts from here, not from signing: an entry first
    /// examined long after it was sent gets the same number of tries as
    /// any other. Optional and additive.
    var recordedAt: Date?

    init(
        schemaVersion: Int,
        blockNumber: Int,
        blockHash: String,
        extrinsicIndex: UInt32,
        finalizedHeight: Int,
        recordedAt: Date? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.blockNumber = blockNumber
        self.blockHash = blockHash
        self.extrinsicIndex = extrinsicIndex
        self.finalizedHeight = finalizedHeight
        self.recordedAt = recordedAt
    }

    func isValid(for context: Sora2SubmissionRecoveryContext) -> Bool {
        schemaVersion == Self.currentSchemaVersion &&
            context.eraBirthBlock <= blockNumber &&
            blockNumber < context.eraDeathBlockExclusive &&
            finalizedHeight >= blockNumber &&
            Sora2PendingSubmissionStore.normalizedHash(blockHash) == blockHash
    }
}

enum Sora2AuthoritativeTerminalProof {
    case finalizedInclusion(
        blockNumber: Int,
        blockHash: String,
        succeeded: Bool,
        finalizedHeight: Int
    )
    case mortalEraAbsence(
        scannedBirthBlock: Int,
        scannedDeathBlockExclusive: Int,
        finalizedHeight: Int
    )
}

struct Sora2PendingSubmission: Codable, Equatable {
    let id: UUID
    let account: String
    let extrinsicHash: String
    let createdAt: Date
    var updatedAt: Date
    var state: Sora2PendingSubmissionState
    var recoveryContext: Sora2SubmissionRecoveryContext?
    var terminalResolution: Sora2PendingTerminalResolution?
    /// Optional for dual-read compatibility with journals written before the
    /// purpose discriminator existed. New entries always persist a value.
    let purpose: Sora2PendingSubmissionPurpose?
    /// Optional and additive: builds that do not know it ignore it.
    var finalizedInclusion: Sora2PendingFinalizedInclusion?

    /// A signed transaction is mortal: it can enter a block only during its
    /// era of 64 blocks (about six and a half minutes). One hour of wall
    /// clock is a generous bound for "may still be entering the network"
    /// that needs no network read, so it also holds offline and for an entry
    /// that can never be reconciled.
    static let submissionWindow: TimeInterval = 60 * 60
    /// How long an entry without a result is still shown as pending, and
    /// how long the result of a finalized transaction is still looked for.
    /// After that the entry no longer claims anything in Activity; the
    /// indexer's own row (which carries the real result) is the record.
    static let resultRetryWindow: TimeInterval = 7 * 24 * 60 * 60

    /// Legacy submitted rows predate generic recovery and retain their prior
    /// pruning behavior. Every newly qualified row remains a durable witness
    /// until an authoritative terminal resolution accompanies the submitted
    /// transport state.
    var isPrunable: Bool {
        state == .submitted &&
            (recoveryContext == nil || terminalResolution != nil)
    }

    /// The transaction may still be entering the network: it has no
    /// terminal resolution, it was not found in a finalized block, and it
    /// was signed less than `submissionWindow` ago. A clock that was set
    /// back (an entry "from the future") does not extend the window.
    func mayStillEnterChain(now: Date) -> Bool {
        guard !isPrunable, finalizedInclusion == nil else {
            return false
        }
        return abs(now.timeIntervalSince(createdAt)) < Self.submissionWindow
    }

    /// Whether Activity may still show this entry as pending.
    func isAwaitingResult(now: Date) -> Bool {
        guard terminalResolution == nil else {
            return false
        }
        return abs(now.timeIntervalSince(createdAt)) < Self.resultRetryWindow
    }

    /// Whether a failed read for this entry is worth another pass within
    /// minutes: it is in a finalized block and its result is still looked
    /// for, or it was signed within `resultRetryWindow`. An older entry
    /// that still cannot be read waits for the next start or return to the
    /// foreground.
    func isWorthAskingAboutSoon(now: Date) -> Bool {
        guard terminalResolution == nil else {
            return false
        }
        if finalizedInclusion != nil {
            return resultIsStillLookedFor(now: now)
        }
        return abs(now.timeIntervalSince(createdAt)) < Self.resultRetryWindow
    }

    /// No feature journal owns this entry.
    var isGeneric: Bool {
        purpose == nil || purpose == .generic
    }

    /// Whether a pass still asks for the result of this entry, which was
    /// found in a finalized block. An entry a feature owns (a legacy
    /// migration, a Polkamarkt order) is asked about until it has its
    /// result, because that feature waits for it. A generic entry is asked
    /// about for `resultRetryWindow` from the moment its inclusion was
    /// written down; one failed read never ends the asking.
    func resultIsStillLookedFor(now: Date) -> Bool {
        guard terminalResolution == nil else {
            return false
        }
        guard isGeneric, let inclusion = finalizedInclusion else {
            return true
        }
        // Nothing changes an entry between the recording of its inclusion
        // and its result, so for an entry written before `recordedAt`
        // existed `updatedAt` is that moment.
        let since = inclusion.recordedAt ?? updatedAt
        return abs(now.timeIntervalSince(since)) < Self.resultRetryWindow
    }

    /// A generic entry that no feature journal owns, whose transaction can
    /// no longer enter the chain. When the journal is full it may give its
    /// place to a new transaction even without a resolution.
    func isStale(now: Date) -> Bool {
        guard
            isGeneric,
            [
                Sora2PendingSubmissionState.submitting,
                .submitted,
                .submissionUnknown,
            ].contains(state)
        else {
            return false
        }
        return !mayStillEnterChain(now: now)
    }

    init(
        id: UUID,
        account: String,
        extrinsicHash: String,
        createdAt: Date,
        updatedAt: Date,
        state: Sora2PendingSubmissionState,
        recoveryContext: Sora2SubmissionRecoveryContext? = nil,
        terminalResolution: Sora2PendingTerminalResolution? = nil,
        purpose: Sora2PendingSubmissionPurpose = .generic,
        finalizedInclusion: Sora2PendingFinalizedInclusion? = nil
    ) {
        self.id = id
        self.account = account
        self.extrinsicHash = extrinsicHash
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.state = state
        self.recoveryContext = recoveryContext
        self.terminalResolution = terminalResolution
        self.purpose = purpose
        self.finalizedInclusion = finalizedInclusion
    }
}

/// A privacy-preserving signed-submission journal. Alongside the local hash and
/// state it stores only the non-secret wallet/account, reviewed chain/runtime,
/// and mortal-era identity required for status recovery. It never stores signed
/// bytes or exports these device-local identifiers. The journal is durable
/// before transport so an interrupted submission is surfaced as ambiguous
/// instead of silently rebuilt and retried.
final class Sora2PendingSubmissionStore {
    private static let lock = NSLock()
    private static let maximumEntries = 500
    private static let maximumBytes = 1_024 * 1_024

    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        fileManager: FileManager = .default,
        baseURL: URL? = nil
    ) throws {
        self.fileManager = fileManager
        let root: URL
        if let baseURL {
            root = baseURL
        } else {
            root = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
        }
        let directory = root
            .appendingPathComponent("SORA", isDirectory: true)
            .appendingPathComponent(
                "PendingTransactions",
                isDirectory: true
            )
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        fileURL = directory.appendingPathComponent(
            "sora2-signed-v1.json"
        )
        encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func all() throws -> [Sora2PendingSubmission] {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        try validateNamespaceUnlocked()
        return try loadUnlocked()
    }

    /// Whether the journal file was last written longer ago than the
    /// submission window (or does not exist). Every entry whose transaction
    /// may still be entering the network was written within that window, so
    /// an older file holds none, even when its content cannot be read. An
    /// unreadable modification date counts as recent.
    static func journalPredatesSubmissionWindow(
        now: Date,
        fileManager: FileManager = .default,
        baseURL: URL? = nil
    ) -> Bool {
        let root: URL
        if let baseURL {
            root = baseURL
        } else if let support = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first {
            root = support
        } else {
            return false
        }
        let file = root
            .appendingPathComponent("SORA", isDirectory: true)
            .appendingPathComponent("PendingTransactions", isDirectory: true)
            .appendingPathComponent("sora2-signed-v1.json")
        guard fileManager.fileExists(atPath: file.path) else {
            return true
        }
        guard
            let modified = (try? fileManager.attributesOfItem(
                atPath: file.path
            ))?[.modificationDate] as? Date
        else {
            return false
        }
        return abs(now.timeIntervalSince(modified)) >=
            Sora2PendingSubmission.submissionWindow
    }

    func stage(
        account: String,
        hash: String,
        retainingTransportWitness: Bool = false,
        recoveryContext: Sora2SubmissionRecoveryContext? = nil,
        purpose: Sora2PendingSubmissionPurpose = .generic
    ) throws -> Sora2PendingSubmission {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        guard
            !account.isEmpty,
            account.utf8.count <= 512,
            let hash = Self.normalizedHash(hash)
        else {
            throw ExtrinsicServiceError.invalidLocalHash
        }
        guard recoveryContext?.isValid(
            account: account,
            hash: hash
        ) != false else {
            throw ExtrinsicServiceError.invalidPendingSubmissionTransition
        }
        try validateNamespaceUnlocked()
        var values = try loadUnlocked()
        guard !values.contains(where: {
            $0.extrinsicHash == hash
        }) else {
            throw ExtrinsicServiceError.duplicatePreparedSubmission
        }
        let now = Date()
        if values.count >= Self.maximumEntries {
            guard let pruneIndex = Self.evictionIndex(in: values, now: now)
            else {
                throw ExtrinsicServiceError.pendingSubmissionCapacityExceeded
            }
            values.remove(at: pruneIndex)
        }
        let pending = Sora2PendingSubmission(
            id: UUID(),
            account: account,
            extrinsicHash: hash,
            createdAt: now,
            updatedAt: now,
            state: retainingTransportWitness
                ? .stagedBeforeTransport
                : .submitting,
            recoveryContext: recoveryContext,
            purpose: purpose
        )
        values.append(pending)
        try writeUnlocked(values)
        return pending
    }

    func update(
        _ pending: Sora2PendingSubmission,
        state: Sora2PendingSubmissionState
    ) throws {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        try validateNamespaceUnlocked()
        var values = try loadUnlocked()
        guard
            let index = values.firstIndex(where: {
                $0.id == pending.id
            }),
            values[index].account == pending.account,
            values[index].extrinsicHash == pending.extrinsicHash,
            Self.canTransition(
                from: values[index].state,
                to: state
            )
        else {
            throw ExtrinsicServiceError.invalidPendingSubmissionTransition
        }
        values[index].state = state
        values[index].updatedAt = Self.monotonicNow(
            after: values[index].updatedAt
        )
        try writeUnlocked(values)
    }

    /// The entry that gives its place to a new transaction when the journal
    /// is full: the oldest resolved one; otherwise the oldest one already
    /// found in a finalized block; otherwise the oldest stale one (see
    /// `Sora2PendingSubmission.isStale`). An entry whose transaction may
    /// still be entering the network, and entries owned by a feature
    /// journal, are never evicted. Stale entries therefore cannot make the
    /// journal refuse a new transaction.
    static func evictionIndex(
        in values: [Sora2PendingSubmission],
        now: Date
    ) -> Int? {
        let oldestFirst: (Int, Int) -> Bool = {
            values[$0].updatedAt < values[$1].updatedAt
        }
        if let index = values.indices
            .filter({ values[$0].isPrunable })
            .min(by: oldestFirst) {
            return index
        }
        if let index = values.indices
            .filter({
                values[$0].finalizedInclusion != nil &&
                    values[$0].isStale(now: now)
            })
            .min(by: oldestFirst) {
            return index
        }
        return values.indices
            .filter({ values[$0].isStale(now: now) })
            .min(by: { values[$0].createdAt < values[$1].createdAt })
    }

    /// A request proven not to have reached transport needs no reconciliation.
    /// Remove its reservation instead of turning either the legacy
    /// `submitting` state or the phase-coupled staged witness into ambiguity.
    func removeBeforeSubmission(
        _ pending: Sora2PendingSubmission
    ) throws {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        try validateNamespaceUnlocked()
        var values = try loadUnlocked()
        guard
            let index = values.firstIndex(where: {
                $0.id == pending.id
            }),
            values[index].account == pending.account,
            values[index].extrinsicHash == pending.extrinsicHash,
            [
                Sora2PendingSubmissionState.stagedBeforeTransport,
                .submitting,
            ].contains(values[index].state)
        else {
            throw ExtrinsicServiceError.invalidPendingSubmissionTransition
        }
        values.remove(at: index)
        try writeUnlocked(values)
    }

    /// Makes a confirmed-success witness prunable only after the owning
    /// feature journal has durably advanced. A crash before this call leaves
    /// `submittedRetained`, so absence can never be mistaken for proof that a
    /// possibly transported transaction was still pre-transport.
    func acknowledgeRetainedSubmission(
        account: String,
        hash: String
    ) throws {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        guard
            !account.isEmpty,
            account.utf8.count <= 512,
            let hash = Self.normalizedHash(hash)
        else {
            throw ExtrinsicServiceError.invalidLocalHash
        }
        try validateNamespaceUnlocked()
        var values = try loadUnlocked()
        guard let index = values.firstIndex(where: {
            $0.account == account && $0.extrinsicHash == hash
        }) else {
            throw ExtrinsicServiceError.invalidPendingSubmissionTransition
        }
        switch values[index].state {
        case .submitted:
            return
        case .submitting, .submittedRetained:
            break
        case .stagedBeforeTransport, .submissionUnknown:
            throw ExtrinsicServiceError.invalidPendingSubmissionTransition
        }
        values[index].state = .submitted
        values[index].updatedAt = Self.monotonicNow(
            after: values[index].updatedAt
        )
        try writeUnlocked(values)
    }

    /// Makes companion witnesses prunable only after an owning feature has
    /// durably recorded canonical finalized inclusion and execution. This is
    /// the sole path that may relax `submissionUnknown`; transport success or
    /// indexer history alone is intentionally insufficient.
    func acknowledgeAuthoritativelyFinalizedSubmissions(
        account: String,
        hashes: Set<String>
    ) throws {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        guard
            !account.isEmpty,
            account.utf8.count <= 512,
            hashes.count <= Self.maximumEntries
        else {
            throw ExtrinsicServiceError.invalidLocalHash
        }
        let normalizedHashes = Set(hashes.compactMap(Self.normalizedHash))
        guard normalizedHashes.count == hashes.count else {
            throw ExtrinsicServiceError.invalidLocalHash
        }
        guard !normalizedHashes.isEmpty else {
            return
        }
        try validateNamespaceUnlocked()
        var values = try loadUnlocked()
        let matchedIndices = values.indices.filter {
            normalizedHashes.contains(values[$0].extrinsicHash)
        }
        guard matchedIndices.allSatisfy({ values[$0].account == account })
        else {
            throw ExtrinsicServiceError.invalidPendingSubmissionTransition
        }
        guard matchedIndices.allSatisfy({
            switch values[$0].state {
            case .submitting, .submitted, .submittedRetained,
                 .submissionUnknown:
                return true
            case .stagedBeforeTransport:
                return false
            }
        }) else {
            throw ExtrinsicServiceError.invalidPendingSubmissionTransition
        }
        var changed = false
        for index in matchedIndices where values[index].state != .submitted {
            values[index].state = .submitted
            values[index].updatedAt = Self.monotonicNow(
                after: values[index].updatedAt
            )
            changed = true
        }
        if changed {
            try writeUnlocked(values)
        }
    }

    /// Records that the exact hash was found in a finalized canonical block
    /// of its mortal era while the execution result could not be read. The
    /// entry stays without a terminal resolution; `resolveAuthoritatively`
    /// completes it once the result is read for that same block.
    func recordFinalizedInclusion(
        _ pending: Sora2PendingSubmission,
        blockNumber: Int,
        blockHash rawBlockHash: String,
        extrinsicIndex: UInt32,
        finalizedHeight: Int,
        recordedAt: Date = Date()
    ) throws {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        try validateNamespaceUnlocked()
        var values = try loadUnlocked()
        guard
            let index = values.firstIndex(where: { $0.id == pending.id }),
            values[index].account == pending.account,
            values[index].extrinsicHash == pending.extrinsicHash,
            values[index].recoveryContext == pending.recoveryContext,
            values[index].terminalResolution == nil,
            values[index].state != .stagedBeforeTransport,
            let context = values[index].recoveryContext,
            context.isValid(
                account: values[index].account,
                hash: values[index].extrinsicHash
            ),
            let blockHash = Self.normalizedHash(rawBlockHash)
        else {
            throw ExtrinsicServiceError.invalidPendingSubmissionTransition
        }
        let inclusion = Sora2PendingFinalizedInclusion(
            schemaVersion: Sora2PendingFinalizedInclusion.currentSchemaVersion,
            blockNumber: blockNumber,
            blockHash: blockHash,
            extrinsicIndex: extrinsicIndex,
            finalizedHeight: finalizedHeight,
            // Whole seconds, as the journal's date encoding keeps them.
            recordedAt: Date(
                timeIntervalSince1970:
                    recordedAt.timeIntervalSince1970.rounded(.down)
            )
        )
        guard inclusion.isValid(for: context) else {
            throw ExtrinsicServiceError.invalidPendingSubmissionTransition
        }
        if let existing = values[index].finalizedInclusion {
            guard
                existing.blockNumber == inclusion.blockNumber,
                existing.blockHash == inclusion.blockHash,
                existing.extrinsicIndex == inclusion.extrinsicIndex
            else {
                throw ExtrinsicServiceError.invalidPendingSubmissionTransition
            }
            return
        }
        values[index].finalizedInclusion = inclusion
        // Being in a finalized block settles whether transport happened.
        values[index].state = .submitted
        values[index].updatedAt = Self.monotonicNow(
            after: values[index].updatedAt
        )
        try writeUnlocked(values)
    }

    /// Resolves one exact restart witness only from a typed authoritative
    /// proof. Inclusion requires a finalized canonical block and one decoded
    /// System execution outcome. Absence requires a complete canonical scan of
    /// the versioned mortal era after its exclusive death block finalized.
    func resolveAuthoritatively(
        _ pending: Sora2PendingSubmission,
        proof: Sora2AuthoritativeTerminalProof
    ) throws {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        try validateNamespaceUnlocked()
        var values = try loadUnlocked()
        guard
            let index = values.firstIndex(where: { $0.id == pending.id }),
            values[index].account == pending.account,
            values[index].extrinsicHash == pending.extrinsicHash,
            values[index].recoveryContext == pending.recoveryContext,
            values[index].terminalResolution == nil,
            let context = values[index].recoveryContext,
            context.isValid(
                account: values[index].account,
                hash: values[index].extrinsicHash
            )
        else {
            throw ExtrinsicServiceError.invalidPendingSubmissionTransition
        }
        switch values[index].state {
        case .submitting, .submitted, .submittedRetained,
             .submissionUnknown:
            break
        case .stagedBeforeTransport:
            throw ExtrinsicServiceError.invalidPendingSubmissionTransition
        }

        let resolution: Sora2PendingTerminalResolution
        switch proof {
        case let .finalizedInclusion(
            blockNumber,
            rawBlockHash,
            succeeded,
            finalizedHeight
        ):
            guard
                context.eraBirthBlock <= blockNumber,
                blockNumber < context.eraDeathBlockExclusive,
                finalizedHeight >= blockNumber,
                let blockHash = Self.normalizedHash(rawBlockHash),
                values[index].finalizedInclusion.map({
                    $0.blockNumber == blockNumber &&
                        $0.blockHash == blockHash
                }) ?? true
            else {
                throw ExtrinsicServiceError
                    .invalidPendingSubmissionTransition
            }
            resolution = Sora2PendingTerminalResolution(
                schemaVersion:
                    Sora2PendingTerminalResolution.currentSchemaVersion,
                kind: succeeded ? .finalizedSuccess : .finalizedFailure,
                blockNumber: blockNumber,
                blockHash: blockHash,
                finalizedHeight: finalizedHeight
            )
        case let .mortalEraAbsence(
            scannedBirthBlock,
            scannedDeathBlockExclusive,
            finalizedHeight
        ):
            guard
                scannedBirthBlock == context.eraBirthBlock,
                scannedDeathBlockExclusive ==
                    context.eraDeathBlockExclusive,
                finalizedHeight >= context.eraDeathBlockExclusive,
                values[index].finalizedInclusion == nil
            else {
                throw ExtrinsicServiceError
                    .invalidPendingSubmissionTransition
            }
            resolution = Sora2PendingTerminalResolution(
                schemaVersion:
                    Sora2PendingTerminalResolution.currentSchemaVersion,
                kind: .expiredNotIncluded,
                blockNumber: nil,
                blockHash: nil,
                finalizedHeight: finalizedHeight
            )
        }
        guard resolution.isValid(for: context) else {
            throw ExtrinsicServiceError.invalidPendingSubmissionTransition
        }
        values[index].state = .submitted
        values[index].terminalResolution = resolution
        values[index].updatedAt = Self.monotonicNow(
            after: values[index].updatedAt
        )
        try writeUnlocked(values)
    }

    private static func canTransition(
        from current: Sora2PendingSubmissionState,
        to next: Sora2PendingSubmissionState
    ) -> Bool {
        switch (current, next) {
        case (.stagedBeforeTransport, .submitting),
             (.submitting, .submitted),
             (.submitting, .submittedRetained),
             (.submitting, .submissionUnknown),
             (.submittedRetained, .submitted):
            return true
        default:
            return false
        }
    }

    private static func monotonicNow(after current: Date) -> Date {
        max(Date(), current)
    }

    private func loadUnlocked() throws -> [Sora2PendingSubmission] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }
        // Atomic publication replaces the inode. Always resolve a fresh URL
        // and reject links/non-regular files before reading journal bytes.
        let currentFileURL = URL(fileURLWithPath: fileURL.path)
        let attributes = try currentFileURL.resourceValues(
            forKeys: [
                .fileSizeKey,
                .isRegularFileKey,
                .isSymbolicLinkKey,
            ]
        )
        guard
            attributes.isRegularFile == true,
            attributes.isSymbolicLink != true,
            let fileSize = attributes.fileSize,
            fileSize >= 0,
            fileSize <= Self.maximumBytes
        else {
            throw ExtrinsicServiceError.invalidLocalHash
        }
        let data = try Data(contentsOf: currentFileURL)
        guard
            data.count == fileSize,
            data.count <= Self.maximumBytes
        else {
            throw ExtrinsicServiceError.invalidLocalHash
        }
        let values = try decoder.decode(
            [Sora2PendingSubmission].self,
            from: data
        )
        guard
            values.count <= Self.maximumEntries,
            Set(values.map(\.id)).count == values.count,
            Set(values.map(\.extrinsicHash)).count == values.count,
            values.allSatisfy({ entry in
                !entry.account.isEmpty &&
                    entry.account.utf8.count <= 512 &&
                    Self.normalizedHash(entry.extrinsicHash) ==
                        entry.extrinsicHash &&
                    entry.createdAt.timeIntervalSince1970.isFinite &&
                    entry.updatedAt.timeIntervalSince1970.isFinite &&
                    entry.updatedAt >= entry.createdAt &&
                    (entry.recoveryContext?.isValid(
                        account: entry.account,
                        hash: entry.extrinsicHash
                    ) != false) &&
                    (entry.terminalResolution.map { resolution in
                        guard
                            entry.state == .submitted,
                            let context = entry.recoveryContext
                        else {
                            return false
                        }
                        return resolution.isValid(for: context)
                    } ?? true)
            })
        else {
            throw ExtrinsicServiceError.invalidLocalHash
        }
        // The inclusion witness is an optimisation, not evidence anything
        // else relies on. One that does not fit its entry is dropped and
        // found again by the next scan; it never makes the journal
        // unreadable.
        return values.map { entry in
            guard let inclusion = entry.finalizedInclusion else {
                return entry
            }
            if entry.state == .submitted,
               let context = entry.recoveryContext,
               inclusion.isValid(for: context),
               entry.terminalResolution.map({
                   $0.blockNumber == nil ||
                       ($0.blockNumber == inclusion.blockNumber &&
                           $0.blockHash == inclusion.blockHash)
               }) ?? true {
                return entry
            }
            var sanitized = entry
            sanitized.finalizedInclusion = nil
            return sanitized
        }
    }

    private func writeUnlocked(
        _ values: [Sora2PendingSubmission]
    ) throws {
        let data = try encoder.encode(values)
        guard data.count <= Self.maximumBytes else {
            throw ExtrinsicServiceError.invalidLocalHash
        }
        try DurableFileWriter.write(
            data,
            to: fileURL,
            fileManager: fileManager,
            protection: .completeUntilFirstUserAuthentication
        )
    }

    private func validateNamespaceUnlocked() throws {
        do {
            try PendingTransactionJournalNamespace.validate(
                directoryURL: fileURL.deletingLastPathComponent(),
                fileManager: fileManager
            )
        } catch {
            throw ExtrinsicServiceError.invalidLocalHash
        }
    }

    static func normalizedHash(_ value: String) -> String? {
        let payload: Substring
        if value.hasPrefix("0x") || value.hasPrefix("0X") {
            payload = value.dropFirst(2)
        } else {
            payload = value[...]
        }
        guard
            payload.count == 64,
            payload.unicodeScalars.allSatisfy({
                (48 ... 57).contains($0.value) ||
                    (65 ... 70).contains($0.value) ||
                    (97 ... 102).contains($0.value)
            }),
            payload.contains(where: { $0 != "0" })
        else {
            return nil
        }
        return payload.lowercased()
    }
}

enum Sora2PendingRecoveryError: Error {
    case unavailable
}

/// The execution result the indexer recorded for one transaction.
struct Sora2IndexedExecution: Equatable {
    let blockNumber: Int
    let blockHash: String
    let succeeded: Bool
}

/// Looks one exact transaction of one account up in the indexer.
typealias Sora2IndexedExecutionLookup = (
    _ account: String,
    _ transactionHash: String
) async throws -> Sora2IndexedExecution?

/// What one reconciliation pass did. Counts only; never hashes or addresses.
struct Sora2PendingReconciliationReport: Equatable {
    /// Entries that received a terminal resolution in this pass.
    var resolved = 0
    /// Entries found in a finalized block whose result could not be read
    /// yet. They are settled on chain and are asked again cheaply.
    var awaitingResult = 0
    /// Entries whose mortal era has not ended on the finalized chain and
    /// that are not in a finalized block yet.
    var withinEra = 0
    /// Entries that could not be examined now: no wallet to bind them to,
    /// a read failed, or the connected node follows another finalized
    /// history than the one the transaction was signed on.
    var deferred = 0
    /// Of `deferred`, the entries a read failed for in this pass that are
    /// worth asking about again within minutes
    /// (`Sora2PendingSubmission.isWorthAskingAboutSoon`). The same read
    /// can succeed a moment later.
    var failedReads = 0
    /// Entries left for the next pass by the per-pass limit.
    var notExamined = 0

    /// A later pass can still change something soon: an entry is inside
    /// its era, was not reached, is in a finalized block without a result
    /// that could be read, or met a read that failed. The follow-up
    /// schedule is what bounds the asking.
    var needsFollowUp: Bool {
        withinEra > 0 || notExamined > 0 || awaitingResult > 0 ||
            failedReads > 0
    }

    /// Something was left without a terminal resolution.
    var hasUnresolved: Bool {
        awaitingResult > 0 || withinEra > 0 || deferred > 0 ||
            notExamined > 0
    }
}

/// What one pass leaves for the recovery runtime, worked out where the pass
/// ran, so the main actor reads no file to decide whether to schedule
/// another one.
struct Sora2PendingPassOutcome: Equatable {
    /// Nil when the pass failed as a whole (offline, node not answering).
    var report: Sora2PendingReconciliationReport?
    /// Another pass soon can still change something
    /// (`Sora2PendingFollowUpSchedule.needsFollowUp`).
    var needsFollowUp: Bool
}

/// Remembers, for the life of the process, how often each entry was looked
/// at without success, so that a pass prefers entries it has not tried yet.
/// An entry that keeps failing moves behind the others instead of holding
/// them back.
final class Sora2PendingReconciliationRotation {
    static let shared = Sora2PendingReconciliationRotation()

    private let lock = NSLock()
    private var attempts: [UUID: Int] = [:]

    func attempts(for identifier: UUID) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return attempts[identifier] ?? 0
    }

    func recordAttempt(for identifier: UUID) {
        lock.lock()
        attempts[identifier, default: 0] += 1
        lock.unlock()
    }

    func forget(_ identifier: UUID) {
        lock.lock()
        attempts[identifier] = nil
        lock.unlock()
    }

    func retainOnly(_ identifiers: Set<UUID>) {
        lock.lock()
        attempts = attempts.filter { identifiers.contains($0.key) }
        lock.unlock()
    }
}

/// Status-only recovery for ordinary SORA2 submissions. It scans canonical
/// finalized blocks from the exact signed mortal era and decodes only System
/// execution events. It has no signer, builder, signed bytes, or submission
/// API, so restart and foreground recovery cannot resubmit an ambiguous hash.
///
/// Blocks are read from the connected node, which keeps every block. The
/// execution result lives in the state of the inclusion block, and a pruning
/// node (the first bundled node keeps about 256 blocks, 25 minutes) answers
/// "State already discarded" for anything older. The result is then read
/// from an archive node that proves the same genesis and the same block hash
/// at that height, and failing that from the indexer's record of that exact
/// transaction in that exact block.
final class Sora2PendingSubmissionReconciler {
    static let maximumWitnessesPerPass = 16
    static let maximumResultReadsPerPass = 32
    private typealias CanonicalBlock = (
        blockHash: String,
        extrinsicIndices: [String: UInt32]
    )

    private struct RuntimeKey: Hashable {
        let node: String
        let specVersion: UInt32
        let transactionVersion: UInt32
    }

    /// One node the execution result may be read from.
    private struct Source {
        let engine: JSONRPCEngine
        let rpc: PolkamarktRPCClient

        var node: String {
            Sora2LiveRuntimeIdentityCache.nodeIdentity(for: engine.url) ?? ""
        }
    }

    private struct Inclusion {
        let blockNumber: Int
        let blockHash: String
        let extrinsicIndex: UInt32
    }

    private enum EntryOutcome {
        case resolved
        case awaitingResult
        case withinEra
        /// The connected node has another block at the height the
        /// transaction was signed against.
        case otherHistory
    }

    private let store: Sora2PendingSubmissionStore
    private let rpc: PolkamarktRPCClient
    private let runtimeService: RuntimeCodingServiceProtocol
    private let engine: JSONRPCEngine
    private let liveRuntimeIdentityCache: Sora2LiveRuntimeIdentityCache
    private let loadWalletNetworkSnapshot: () throws -> WalletNetworkSnapshot?
    private let makeArchiveEngines: () -> [JSONRPCEngine]
    private let indexedExecution: Sora2IndexedExecutionLookup?
    private let rotation: Sora2PendingReconciliationRotation
    private let now: () -> Date
    private var canonicalBlockCache: [Int: CanonicalBlock] = [:]
    private var decodingFactories: [RuntimeKey: RuntimeCoderFactoryProtocol] = [:]
    private var recoveryHashes = Set<String>()
    private var archiveSources: [Source]?
    private var verifiedArchiveNodes = Set<String>()

    init(
        store: Sora2PendingSubmissionStore,
        engine: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        liveRuntimeIdentityCache: Sora2LiveRuntimeIdentityCache = .shared,
        walletNetworkSnapshot: @escaping () throws -> WalletNetworkSnapshot? = {
            try WalletNetworkStore().load()
        },
        archiveEngines: @escaping () -> [JSONRPCEngine] = {
            Sora2PendingSubmissionReconciler.bundledArchiveEngines()
        },
        indexedExecution: Sora2IndexedExecutionLookup? =
            Sora2PendingSubmissionReconciler.indexedExecutionFromPI,
        rotation: Sora2PendingReconciliationRotation = .shared,
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.engine = Sora2BoundedHTTPJSONRPCEngine.wrapping(engine)
        rpc = PolkamarktRPCClient(engine: self.engine)
        self.runtimeService = runtimeService
        self.liveRuntimeIdentityCache = liveRuntimeIdentityCache
        loadWalletNetworkSnapshot = walletNetworkSnapshot
        makeArchiveEngines = archiveEngines
        self.indexedExecution = indexedExecution
        self.rotation = rotation
        self.now = now
    }

    /// The bundled SORA2 mainnet nodes, each addressed directly. A node is
    /// used for old state only after it proves the reviewed genesis and the
    /// inclusion block's hash; whether it is an archive shows in its answer.
    static func bundledArchiveEngines() -> [JSONRPCEngine] {
        SoraNodeConnectionPolicy.bundledMainnetNodes.map {
            Sora2BoundedHTTPJSONRPCEngine(nodeURL: $0.url)
        }
    }

    /// The indexer's record of one transaction. Used only for the success
    /// flag of a transaction this app already found in a finalized canonical
    /// block; the caller checks that the indexer names that same block.
    static func indexedExecutionFromPI(
        account: String,
        transactionHash: String
    ) async throws -> Sora2IndexedExecution? {
        guard
            let normalized = Sora2PendingSubmissionStore.normalizedHash(
                transactionHash
            )
        else {
            return nil
        }
        let read = try await PIIndexerClient()
            .qualifiedHistoryByTransactionHashes(
                address: account,
                transactionHashes: ["0x\(normalized)"]
            )
        guard read.qualification?.source == .live else {
            return nil
        }
        let rows = read.value.filter {
            Sora2PendingSubmissionStore.normalizedHash($0.id) == normalized
        }
        guard
            rows.count == 1,
            let row = rows.first,
            let blockNumber = row.blockHeight,
            blockNumber >= 0,
            let rawBlockHash = row.blockHash,
            let blockHash = Sora2PendingSubmissionStore.normalizedHash(
                rawBlockHash
            ),
            let succeeded = PIHistoryCheckpointValidator.executionSucceeded(
                row.execution
            )
        else {
            return nil
        }
        return Sora2IndexedExecution(
            blockNumber: blockNumber,
            blockHash: blockHash,
            succeeded: succeeded
        )
    }

    /// One pass that reports an entry it had to leave unresolved as an
    /// error, for callers that wait for a specific transaction.
    func reconcileStatusOnly() async throws {
        let report = try await reconcile()
        if report.deferred > 0 {
            throw Sora2PendingRecoveryError.unavailable
        }
    }

    /// One pass for the recovery runtime. It never throws: a pass that
    /// failed as a whole has no report. Whether another pass is worth
    /// scheduling is decided here, off the main actor, because it can need
    /// the journal file.
    func scheduledPass() async -> Sora2PendingPassOutcome {
        let report = try? await reconcile()
        if let report, report.needsFollowUp {
            return Sora2PendingPassOutcome(report: report, needsFollowUp: true)
        }
        let journal = (try? store.all()) ?? []
        return Sora2PendingPassOutcome(
            report: report,
            needsFollowUp: Sora2PendingFollowUpSchedule.needsFollowUp(
                report: report,
                journal: journal,
                now: now()
            )
        )
    }

    /// One status-only pass over the journal.
    @discardableResult
    func reconcile() async throws -> Sora2PendingReconciliationReport {
        try Task.checkCancellation()
        canonicalBlockCache.removeAll(keepingCapacity: true)
        decodingFactories.removeAll(keepingCapacity: true)
        recoveryHashes.removeAll(keepingCapacity: true)
        archiveSources = nil
        verifiedArchiveNodes.removeAll(keepingCapacity: true)
        var report = Sora2PendingReconciliationReport()
        let currentTime = now()
        let values = try store.all()
        rotation.retainOnly(Set(values.map(\.id)))
        let qualified = values.filter {
            !$0.isPrunable &&
                $0.state != .stagedBeforeTransport &&
                $0.recoveryContext != nil &&
                // A finalized generic transaction whose result nobody
                // could give for a week of asking is no longer asked
                // about. An entry a feature waits for always is.
                ($0.finalizedInclusion == nil ||
                    $0.resultIsStillLookedFor(now: currentTime))
        }
        guard !qualified.isEmpty else {
            return report
        }
        guard let snapshot = try loadWalletNetworkSnapshot() else {
            throw Sora2PendingRecoveryError.unavailable
        }
        // An entry whose wallet binding fails (its account was removed, or
        // its row no longer matches) is left as it is. It does not keep the
        // other accounts' entries from being resolved, and it costs no
        // request.
        let bound = qualified.filter { pending in
            do {
                try validateWalletBinding(pending, snapshot: snapshot)
                return true
            } catch {
                report.deferred += 1
                return false
            }
        }
        guard !bound.isEmpty else {
            return report
        }

        let finalized = try await rpc.finalizedBlockNumber()
        guard let finalizedHeight = Int(exactly: finalized) else {
            throw Sora2PendingRecoveryError.unavailable
        }
        // Entries the process has tried least come first, the newest of them
        // first: a transaction just sent is what the user is waiting for,
        // and an entry that keeps failing cannot hold the others back.
        func order(
            _ lhs: Sora2PendingSubmission,
            _ rhs: Sora2PendingSubmission
        ) -> Bool {
            let lhsAttempts = rotation.attempts(for: lhs.id)
            let rhsAttempts = rotation.attempts(for: rhs.id)
            if lhsAttempts != rhsAttempts {
                return lhsAttempts < rhsAttempts
            }
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
        let toScan = bound
            .filter { $0.finalizedInclusion == nil }
            .sorted(by: order)
        let toRead = bound
            .filter { $0.finalizedInclusion != nil }
            .sorted(by: order)
        let scanned = Array(toScan.prefix(Self.maximumWitnessesPerPass))
        let read = Array(toRead.prefix(Self.maximumResultReadsPerPass))
        report.notExamined =
            (toScan.count - scanned.count) + (toRead.count - read.count)
        recoveryHashes = Set(scanned.map(\.extrinsicHash))
        guard
            recoveryHashes.count == scanned.count,
            let canonicalGenesis = try await canonicalBlock(
                at: 0,
                finalized: finalized
            ),
            PolkamarktRuntimeContract.matchesReviewedGenesisHash(
                "0x\(canonicalGenesis.blockHash)"
            )
        else {
            // Not SORA2 mainnet (or not answering): nothing read from this
            // node says anything about these transactions.
            throw Sora2PendingRecoveryError.unavailable
        }
        // Block zero of this engine is the reviewed SORA2 genesis (a
        // context is valid only for it), so every read below is bound to
        // mainnet. The runtime may have been upgraded since signing: events
        // are decoded with the runtime that produced the inclusion block.
        for pending in scanned + read {
            try Task.checkCancellation()
            guard let context = pending.recoveryContext else {
                continue
            }
            do {
                let outcome: EntryOutcome
                if let known = pending.finalizedInclusion {
                    outcome = try await resolveResult(
                        pending,
                        inclusion: Inclusion(
                            blockNumber: known.blockNumber,
                            blockHash: known.blockHash,
                            extrinsicIndex: known.extrinsicIndex
                        ),
                        recorded: true,
                        finalizedHeight: finalizedHeight
                    )
                } else {
                    outcome = try await reconcile(
                        pending,
                        context: context,
                        finalizedHeight: finalizedHeight,
                        finalized: finalized
                    )
                }
                switch outcome {
                case .resolved:
                    report.resolved += 1
                    rotation.forget(pending.id)
                case .awaitingResult:
                    report.awaitingResult += 1
                    rotation.recordAttempt(for: pending.id)
                case .withinEra:
                    report.withinEra += 1
                case .otherHistory:
                    // Nothing this node says is about this transaction.
                    // The entry stays as it is; asking this node again
                    // soon would change nothing.
                    report.deferred += 1
                    rotation.recordAttempt(for: pending.id)
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                // One entry that cannot be examined now stays as it is; it
                // does not hold back the others, and it goes to the back of
                // the next pass.
                report.deferred += 1
                if pending.isWorthAskingAboutSoon(now: currentTime) {
                    report.failedReads += 1
                }
                rotation.recordAttempt(for: pending.id)
            }
        }
        return report
    }

    /// Returns a decoder for the runtime that produced `blockHash`, read
    /// from the connected node.
    func decodingFactory(
        atBlock normalizedBlockHash: String
    ) async throws -> RuntimeCoderFactoryProtocol {
        try await decodingFactory(
            atBlock: normalizedBlockHash,
            source: Source(engine: engine, rpc: rpc)
        )
    }

    /// Returns a decoder for the runtime that produced `blockHash`. The
    /// current runtime snapshot is reused only when it is exactly that
    /// runtime and its metadata matches the proof stored for that version
    /// and that node; otherwise the block's own metadata is fetched from
    /// the node, bound to its declared `System.Version`, and combined with
    /// the bundled SORA2 type registry.
    private func decodingFactory(
        atBlock normalizedBlockHash: String,
        source: Source
    ) async throws -> RuntimeCoderFactoryProtocol {
        let blockHash = "0x\(normalizedBlockHash)"
        let version = try await source.rpc.runtimeVersion(at: blockHash)
        let node = source.node
        let key = RuntimeKey(
            node: node,
            specVersion: version.specVersion,
            transactionVersion: version.transactionVersion
        )
        if let cached = decodingFactories[key] {
            return cached
        }
        if
            let provider = runtimeService as? RuntimeProviderProtocol,
            let snapshot = provider.snapshot,
            snapshot.specVersion == version.specVersion,
            snapshot.txVersion == version.transactionVersion,
            let proven = liveRuntimeIdentityCache.metadataSHA256(
                node: node,
                specVersion: version.specVersion,
                transactionVersion: version.transactionVersion
            )
        {
            let current = RuntimeCoderFactory(
                catalog: snapshot.typeRegistryCatalog,
                specVersion: snapshot.specVersion,
                txVersion: snapshot.txVersion,
                metadata: snapshot.metadata
            )
            if try PolkamarktRuntimeContract.signingMetadataSHA256(
                for: current
            ) == proven {
                decodingFactories[key] = current
                return current
            }
        }
        let metadataHex = try await source.rpc.metadataHex(at: blockHash)
        let live = try Sora2LiveRuntimeValidator.liveRuntime(
            version: version,
            metadataHex: metadataHex
        )
        let snapshot = try RuntimeSnapshotFactory.makeOwnTypesSnapshot(
            chainId: PIIndexerClient.soraMainnetGenesis,
            runtimeMetadataItem: RuntimeMetadataItem(
                chain: PIIndexerClient.soraMainnetGenesis,
                version: live.specVersion,
                txVersion: live.transactionVersion,
                metadata: try Data(hexStringSSF: metadataHex),
                resolver: nil
            ),
            ownTypes: try ReviewedSoraRuntimeSnapshotAdmission
                .loadReviewedChainTypes(),
            dataHasher: .twox256
        )
        let factory = RuntimeCoderFactory(
            catalog: snapshot.typeRegistryCatalog,
            specVersion: snapshot.specVersion,
            txVersion: snapshot.txVersion,
            metadata: snapshot.metadata
        )
        decodingFactories[key] = factory
        return factory
    }

    private func validateWalletBinding(
        _ pending: Sora2PendingSubmission,
        snapshot: WalletNetworkSnapshot
    ) throws {
        guard
            let context = pending.recoveryContext,
            context.isValid(
                account: pending.account,
                hash: pending.extrinsicHash
            ),
            snapshot.schemaVersion ==
                WalletNetworkSnapshot.currentSchemaVersion,
            snapshot.wallets.contains(where: {
                $0.id == context.walletId &&
                    $0.existingSoraAddress == pending.account
            }),
            let networkAccount = snapshot.accounts.first(where: {
                $0.walletId == context.walletId &&
                    $0.networkId == .sora2
            }),
            networkAccount.address == pending.account,
            networkAccount.publicKey.toHex(includePrefix: false)
                .lowercased() == context.publicKey
        else {
            throw Sora2PendingRecoveryError.unavailable
        }
        let addressFactory = SS58AddressFactory()
        let addressType = try addressFactory.extractAddressType(
            from: pending.account
        )
        let accountId = try addressFactory.accountId(
            fromAddress: pending.account,
            type: addressType
        )
        let rebuiltAddress = try addressFactory.address(
            fromAccountId: networkAccount.publicKey,
            type: addressType
        )
        guard
            addressType == 69,
            accountId.toHex(includePrefix: false).lowercased() ==
                context.accountId,
            rebuiltAddress == pending.account
        else {
            throw Sora2PendingRecoveryError.unavailable
        }
    }

    private func reconcile(
        _ pending: Sora2PendingSubmission,
        context: Sora2SubmissionRecoveryContext,
        finalizedHeight: Int,
        finalized: BigUInt
    ) async throws -> EntryOutcome {
        guard finalizedHeight >= context.eraBirthBlock else {
            // The chain this node follows has not reached the block the
            // transaction was signed against.
            return .withinEra
        }
        let lastEraBlock = context.eraDeathBlockExclusive - 1
        let scanThrough = min(finalizedHeight, lastEraBlock)
        var foundInclusion: Inclusion?

        for blockNumber in context.eraBirthBlock ... scanThrough {
            try Task.checkCancellation()
            guard let canonical = try await canonicalBlock(
                at: blockNumber,
                finalized: finalized
            ) else {
                throw Sora2PendingRecoveryError.unavailable
            }
            // The transaction was signed against the finalized head of
            // the node it was built on. Another block at that height means
            // this node follows another finalized history (a fork with the
            // same genesis), so neither what it holds nor what it lacks is
            // evidence about this transaction. The entry is left as it is:
            // after an hour it blocks nothing, and it resolves when the
            // app is connected to the chain it was signed on again.
            if blockNumber == context.eraBirthBlock,
               canonical.blockHash != context.eraBirthBlockHash {
                return .otherHistory
            }
            if let extrinsicIndex =
                canonical.extrinsicIndices[pending.extrinsicHash] {
                guard foundInclusion == nil else {
                    throw Sora2PendingRecoveryError.unavailable
                }
                foundInclusion = Inclusion(
                    blockNumber: blockNumber,
                    blockHash: canonical.blockHash,
                    extrinsicIndex: extrinsicIndex
                )
            }
        }

        if let inclusion = foundInclusion {
            return try await resolveResult(
                pending,
                inclusion: inclusion,
                recorded: false,
                finalizedHeight: finalizedHeight
            )
        }

        guard finalizedHeight >= context.eraDeathBlockExclusive else {
            // A pre-expiry absence is not terminal. The entry stays as it
            // is for the next pass.
            return .withinEra
        }
        try Task.checkCancellation()
        try store.resolveAuthoritatively(
            pending,
            proof: .mortalEraAbsence(
                scannedBirthBlock: context.eraBirthBlock,
                scannedDeathBlockExclusive:
                    context.eraDeathBlockExclusive,
                finalizedHeight: finalizedHeight
            )
        )
        return .resolved
    }

    /// Reads the execution result of a transaction found in a finalized
    /// canonical block and writes the terminal resolution. When no source
    /// can give the result now, the inclusion itself is recorded.
    private func resolveResult(
        _ pending: Sora2PendingSubmission,
        inclusion: Inclusion,
        recorded: Bool,
        finalizedHeight: Int
    ) async throws -> EntryOutcome {
        if let succeeded = try await executionResult(
            of: pending,
            inclusion: inclusion
        ) {
            try Task.checkCancellation()
            try store.resolveAuthoritatively(
                pending,
                proof: .finalizedInclusion(
                    blockNumber: inclusion.blockNumber,
                    blockHash: inclusion.blockHash,
                    succeeded: succeeded,
                    finalizedHeight: max(
                        finalizedHeight,
                        inclusion.blockNumber
                    )
                )
            )
            return .resolved
        }
        if !recorded {
            try Task.checkCancellation()
            try store.recordFinalizedInclusion(
                pending,
                blockNumber: inclusion.blockNumber,
                blockHash: inclusion.blockHash,
                extrinsicIndex: inclusion.extrinsicIndex,
                finalizedHeight: finalizedHeight,
                recordedAt: now()
            )
        }
        return .awaitingResult
    }

    /// The result of the transaction at `inclusion`, from the first source
    /// that can give it: the connected node, an archive node that proves the
    /// same chain and block, then the indexer. Nil when none can now.
    private func executionResult(
        of pending: Sora2PendingSubmission,
        inclusion: Inclusion
    ) async throws -> Bool? {
        let connected = Source(engine: engine, rpc: rpc)
        do {
            if let succeeded = try await executionResult(
                at: inclusion,
                source: connected
            ) {
                return succeeded
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // Most often "State already discarded". Whatever the reason,
            // another source may still know.
        }
        for archive in archives(excluding: connected.node) {
            try Task.checkCancellation()
            do {
                guard try await provesSameBlock(archive, inclusion: inclusion)
                else {
                    continue
                }
                if let succeeded = try await executionResult(
                    at: inclusion,
                    source: archive
                ) {
                    return succeeded
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                continue
            }
        }
        guard let indexedExecution else {
            return nil
        }
        do {
            guard
                let indexed = try await indexedExecution(
                    pending.account,
                    pending.extrinsicHash
                ),
                indexed.blockNumber == inclusion.blockNumber,
                Sora2PendingSubmissionStore.normalizedHash(
                    indexed.blockHash
                ) == inclusion.blockHash
            else {
                return nil
            }
            return indexed.succeeded
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return nil
        }
    }

    private func archives(excluding connectedNode: String) -> [Source] {
        let sources: [Source]
        if let archiveSources {
            sources = archiveSources
        } else {
            sources = makeArchiveEngines().map {
                let bounded = Sora2BoundedHTTPJSONRPCEngine.wrapping($0)
                return Source(
                    engine: bounded,
                    rpc: PolkamarktRPCClient(engine: bounded)
                )
            }
            archiveSources = sources
        }
        return sources.filter {
            !$0.node.isEmpty && $0.node != connectedNode
        }
    }

    /// An archive is asked about a block only after it returned the reviewed
    /// genesis hash and, at the inclusion height, the very block hash the
    /// connected node reported as canonical and final.
    private func provesSameBlock(
        _ archive: Source,
        inclusion: Inclusion
    ) async throws -> Bool {
        if !verifiedArchiveNodes.contains(archive.node) {
            _ = try await archive.rpc.reviewedGenesisHash()
            verifiedArchiveNodes.insert(archive.node)
        }
        guard
            let hash = try await archive.rpc.blockHash(
                at: inclusion.blockNumber
            )
        else {
            return false
        }
        return hash == inclusion.blockHash
    }

    private func canonicalBlock(
        at blockNumber: Int,
        finalized: BigUInt
    ) async throws -> CanonicalBlock? {
        if let cached = canonicalBlockCache[blockNumber] {
            return cached
        }
        guard let canonical = try await rpc.canonicalExtrinsicHashes(
            at: blockNumber,
            notAfter: finalized
        ) else {
            return nil
        }
        let bounded = CanonicalBlock(
            blockHash: canonical.blockHash,
            extrinsicIndices: canonical.extrinsicIndices.filter {
                recoveryHashes.contains($0.key)
            }
        )
        guard
            bounded.extrinsicIndices.count <=
                Self.maximumWitnessesPerPass
        else {
            throw Sora2PendingRecoveryError.unavailable
        }
        canonicalBlockCache[blockNumber] = bounded
        return bounded
    }

    /// The System execution result of one extrinsic of one block, decoded
    /// from that block's events as `source` holds them. Nil when the block
    /// does not carry exactly one terminal event for the extrinsic.
    private func executionResult(
        at inclusion: Inclusion,
        source: Source
    ) async throws -> Bool? {
        let normalizedBlockHash = inclusion.blockHash
        let extrinsicIndex = inclusion.extrinsicIndex
        guard
            Sora2PendingSubmissionStore.normalizedHash(
                normalizedBlockHash
            ) == normalizedBlockHash
        else {
            throw Sora2PendingRecoveryError.unavailable
        }
        let factory = try await decodingFactory(
            atBlock: normalizedBlockHash,
            source: source
        )
        let blockHashData = try Data(
            hexStringSSF: "0x\(normalizedBlockHash)"
        )
        let storageKey = try StorageKeyFactory().key(from: .events)
        let storage = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: OperationManagerFacade.sharedManager
        )
        let wrapper: CompoundOperationWrapper<
            [StorageResponse<[EventRecord]>]
        > = storage.queryItems(
            engine: source.engine,
            keys: { [storageKey] },
            factory: { factory },
            storagePath: .events,
            at: blockHashData
        )
        let targetOperation = wrapper.targetOperation
        let relay = CancellableCallRelay()
        let records: [EventRecord] = try await withTaskCancellationHandler(
            operation: {
                try Task.checkCancellation()
                return try await withCheckedThrowingContinuation {
                    (continuation: CheckedContinuation<
                        [EventRecord], Error
                    >) in
                    targetOperation.completionBlock = {
                        [weak targetOperation] in
                        guard let targetOperation else {
                            continuation.resume(
                                throwing:
                                    Sora2PendingRecoveryError.unavailable
                            )
                            return
                        }
                        do {
                            guard
                                let value = try targetOperation
                                    .extractNoCancellableResultData()
                                    .first?.value
                            else {
                                throw Sora2PendingRecoveryError.unavailable
                            }
                            continuation.resume(returning: value)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                    relay.set(wrapper)
                    OperationManagerFacade.sharedDefaultQueue.addOperations(
                        wrapper.allOperations,
                        waitUntilFinished: false
                    )
                }
            },
            onCancel: {
                relay.cancel()
            }
        )
        let terminal = records.filter {
            $0.extrinsicIndex == extrinsicIndex &&
                $0.event.section ==
                    EventCodingPath.extrinsicSuccess.moduleName &&
                (
                    $0.event.method ==
                        EventCodingPath.extrinsicSuccess.eventName ||
                        $0.event.method ==
                        EventCodingPath.extrinsicFailed.eventName
                )
        }
        let successes = terminal.filter {
            $0.event.method == EventCodingPath.extrinsicSuccess.eventName
        }
        let failures = terminal.filter {
            $0.event.method == EventCodingPath.extrinsicFailed.eventName
        }
        guard successes.count <= 1, failures.count <= 1 else {
            throw Sora2PendingRecoveryError.unavailable
        }
        if successes.count == 1, failures.isEmpty {
            return true
        }
        if failures.count == 1, successes.isEmpty {
            return false
        }
        return nil
    }
}

/// Posted on the main actor after a reconciliation pass gave at least one
/// sent transaction its final status, so open Activity lists reload.
struct Sora2PendingSubmissionsResolved: EventProtocol {
    func accept(visitor: EventVisitorProtocol) {
        visitor.processPendingSubmissionsResolved(event: self)
    }
}

/// When the passes after a submission run. A transaction is normally in a
/// finalized block within half a minute, so the first passes are close
/// together and read only a few blocks. If it is still not there, nothing
/// can change until its mortal era (64 blocks, about six and a half minutes)
/// is over on the finalized chain, so the later passes wait for that.
enum Sora2PendingFollowUpSchedule {
    static let delays: [TimeInterval] = [12, 20, 30, 45, 60, 300, 300, 420]

    static func delay(afterAttempt attempt: Int) -> TimeInterval? {
        delays.indices.contains(attempt) ? delays[attempt] : nil
    }

    /// Whether another pass soon can still change something.
    ///
    /// - A pass that returned a report: it left entries inside their era,
    ///   unexamined, without a readable result or behind a failed read, or
    ///   the journal holds an entry whose transaction may still be entering
    ///   the network.
    /// - A pass that failed as a whole (offline, node not answering): the
    ///   journal holds an entry a pass would have looked at.
    ///
    /// Either way the asking is bounded by `delays`; start, foreground and
    /// the next submission begin it again.
    static func needsFollowUp(
        report: Sora2PendingReconciliationReport?,
        journal: [Sora2PendingSubmission],
        now: Date
    ) -> Bool {
        let examinable = journal.filter {
            $0.recoveryContext != nil &&
                $0.state != .stagedBeforeTransport &&
                !$0.isPrunable
        }
        if let report {
            return report.needsFollowUp ||
                examinable.contains { $0.mayStillEnterChain(now: now) }
        }
        return examinable.contains { $0.isWorthAskingAboutSoon(now: now) }
    }
}

/// Gates recovery until both lossless wallet storage and the SORA2 chain
/// registry are ready. Foreground calls before either gate are no-ops.
///
/// Passes run at process start, on return to the foreground, on account
/// change, and, after a transaction was handed to the network, by
/// themselves on `Sora2PendingFollowUpSchedule` until nothing recent is
/// left unresolved.
@MainActor
final class Sora2PendingSubmissionRecoveryRuntime {
    static let shared = Sora2PendingSubmissionRecoveryRuntime()

    /// One status-only pass over the journal. It runs off the main actor
    /// and brings back everything the schedule needs.
    typealias Pass = () async -> Sora2PendingPassOutcome

    /// Returns the pass to run against the connected node, or nil when the
    /// SORA2 connection or its runtime is not available.
    private let makePass: () -> Pass?
    private let sleep: (TimeInterval) async throws -> Void
    private let notifyResolved: () -> Void
    private var walletStorageReady = false
    private var chainReady = false
    private var recoveryTask: Task<Void, Never>?
    private var restartRequested = false
    private var followUpTask: Task<Void, Never>?
    private var followUpAttempt = 0

    private convenience init() {
        let store = try? Sora2PendingSubmissionStore()
        self.init(
            makePass: {
                let registry = ChainRegistryFacade.sharedRegistry
                guard
                    let store,
                    let engine = registry.getConnection(
                        for: Chain.sora.genesisHash()
                    ),
                    let runtimeService = registry.getRuntimeProvider(
                        for: Chain.sora.genesisHash()
                    )
                else {
                    return nil
                }
                let reconciler = Sora2PendingSubmissionReconciler(
                    store: store,
                    engine: engine,
                    runtimeService: runtimeService
                )
                return { await reconciler.scheduledPass() }
            },
            sleep: {
                try await Task.sleep(nanoseconds: UInt64($0 * 1_000_000_000))
            },
            notifyResolved: {
                EventCenter.shared.notify(
                    with: Sora2PendingSubmissionsResolved()
                )
            }
        )
    }

    /// The parts that touch the chain registry, the journal file, the clock
    /// and the event center are passed in, so the scheduling can be tested.
    /// The runtime itself reads no file: it runs on the main actor.
    init(
        makePass: @escaping () -> Pass?,
        sleep: @escaping (TimeInterval) async throws -> Void,
        notifyResolved: @escaping () -> Void
    ) {
        self.makePass = makePass
        self.sleep = sleep
        self.notifyResolved = notifyResolved
    }

    func prepareForWalletStorageMigration() {
        walletStorageReady = false
        chainReady = false
        restartRequested = false
        recoveryTask?.cancel()
        followUpTask?.cancel()
        followUpTask = nil
    }

    func markWalletStorageReadyAndResume() {
        walletStorageReady = true
        resumePendingAfterProcessStart()
    }

    func markChainReadyAndResume() {
        chainReady = true
        resumePendingAfterProcessStart()
    }

    func markChainUnavailable() {
        chainReady = false
        recoveryTask?.cancel()
    }

    /// A signed transaction was just handed to the network, or may have
    /// been. Its status is looked up shortly, without waiting for the next
    /// start or return to the foreground.
    func noteSubmission() {
        guard walletStorageReady, chainReady else {
            return
        }
        followUpAttempt = 0
        scheduleFollowUp()
    }

    private func scheduleFollowUp() {
        followUpTask?.cancel()
        followUpTask = nil
        guard
            let delay = Sora2PendingFollowUpSchedule.delay(
                afterAttempt: followUpAttempt
            )
        else {
            // The schedule is used up. Start, foreground and the next
            // submission still run passes.
            return
        }
        followUpAttempt += 1
        let sleep = self.sleep
        followUpTask = Task { [weak self] in
            do {
                try await sleep(delay)
            } catch {
                return
            }
            guard let self, !Task.isCancelled else {
                return
            }
            self.followUpTask = nil
            self.runPass()
        }
    }

    /// A pass asked for from outside: process start, return to the
    /// foreground, account change, or the chain becoming ready.
    func resumePendingAfterProcessStart() {
        guard walletStorageReady, chainReady else {
            return
        }
        // Whatever this pass leaves inside its era is followed up from the
        // start of the schedule again.
        followUpAttempt = 0
        runPass()
    }

    private func runPass() {
        guard walletStorageReady, chainReady else {
            return
        }
        guard recoveryTask == nil else {
            restartRequested = true
            return
        }
        guard let pass = makePass() else {
            chainReady = false
            return
        }
        recoveryTask = Task { [weak self] in
            // Errors remain represented by the journal. Never log hashes,
            // addresses, signed bytes, or raw RPC responses here.
            let outcome = await pass()
            let report = outcome.report
            guard let self else {
                return
            }
            self.recoveryTask = nil
            if let report, report.resolved > 0 {
                self.notifyResolved()
            }
            let shouldRestart = self.restartRequested &&
                self.walletStorageReady && self.chainReady
            self.restartRequested = false
            if shouldRestart {
                self.runPass()
                return
            }
            guard self.walletStorageReady, self.chainReady else {
                return
            }
            if let report, report.notExamined > 0, report.resolved > 0 {
                // More entries than one pass takes, and the pass got
                // somewhere: go on with the next ones now.
                self.runPass()
                return
            }
            if self.followUpTask == nil, outcome.needsFollowUp {
                self.scheduleFollowUp()
            }
        }
    }
}

protocol ExtrinsicServiceProtocol {
    func estimateFee(_ closure: @escaping ExtrinsicBuilderClosure,
                     runningIn queue: DispatchQueue,
                     completion completionClosure: @escaping EstimateFeeClosure)

    /// Signs one exact runtime-validated extrinsic and queries the fee for
    /// those same bytes. The returned call cancels every queued operation,
    /// including the signing lease acquisition.
    @discardableResult
    func prepareAndEstimateFee(
        _ closure: @escaping ExtrinsicBuilderClosure,
        signer: SigningWrapperProtocol,
        preSigningValidation: @escaping () throws -> Void,
        runningIn queue: DispatchQueue,
        completion: @escaping (
            Result<PreparedExtrinsicFeeQualification, Error>
        ) -> Void
    ) -> CancellableCall

    /// Variant for a coordinator that already owns the wallet lifecycle and
    /// must bind the exact signed bytes to a feature-specific metadata
    /// contract before accepting their fee.
    @discardableResult
    func prepareAndEstimateFee(
        _ closure: @escaping ExtrinsicBuilderClosure,
        signer: SigningWrapperProtocol,
        lifecycleLease: WalletLifecycleLease?,
        runtimeValidation:
            ((RuntimeCoderFactoryProtocol) throws -> Void)?,
        finalizedHeadValidation: ((String) throws -> Void)?,
        preSigningValidation: @escaping () throws -> Void,
        runningIn queue: DispatchQueue,
        completion: @escaping (
            Result<PreparedExtrinsicFeeQualification, Error>
        ) -> Void
    ) -> CancellableCall

    func submit(_ closure: @escaping ExtrinsicBuilderClosure,
                signer: SigningWrapperProtocol,
                runningIn queue: DispatchQueue,
                completion completionClosure: @escaping ExtrinsicSubmitClosure)

    func submit(
        _ closure: @escaping ExtrinsicBuilderClosure,
        signer: SigningWrapperProtocol,
        lifecycleLease: WalletLifecycleLease?,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping ExtrinsicSubmitClosure
    )

    /// Builds and signs once without touching the transport. The caller can
    /// persist the returned local hash before submitting these exact bytes.
    func prepare(
        _ closure: @escaping ExtrinsicBuilderClosure,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        completion: @escaping (Result<PreparedExtrinsicSubmission, Error>) -> Void
    )

    func prepare(
        _ closure: @escaping ExtrinsicBuilderClosure,
        signer: SigningWrapperProtocol,
        lifecycleLease: WalletLifecycleLease?,
        runtimeValidation:
            ((RuntimeCoderFactoryProtocol) throws -> Void)?,
        preSigningValidation: (() throws -> Void)?,
        runningIn queue: DispatchQueue,
        completion: @escaping (Result<PreparedExtrinsicSubmission, Error>) -> Void
    )

    /// Submits already signed bytes exactly once. It never rebuilds or signs.
    func submitPrepared(
        _ prepared: PreparedExtrinsicSubmission,
        retainingTransportWitness: Bool,
        expectedRawFee: String,
        preTransportValidation: @escaping () throws -> Void,
        runningIn queue: DispatchQueue,
        completion: @escaping (Result<String, Error>) -> Void
    ) -> CancellableCall
}

final class ExtrinsicService {
    let address: String
    let cryptoType: CryptoType
    let runtimeRegistry: RuntimeCodingServiceProtocol
    let engine: JSONRPCEngine
    let operationManager: OperationManagerProtocol
    let liveRuntimeIdentityCache: Sora2LiveRuntimeIdentityCache
    private let pendingSubmissionStore: Sora2PendingSubmissionStore?
    private let loadWalletNetworkSnapshot: () throws -> WalletNetworkSnapshot?
    private let lifecycleCoordinator: WalletLifecycleCoordinator
    private let recoveryGate: WalletRecoveryCapabilityGate
    private let onSubmission: () -> Void
    private let eventCenter: EventCenterProtocol
    private let refreshRuntime: (Error, RuntimeVersion?) -> Void

    init(address: String,
         cryptoType: CryptoType,
         runtimeRegistry: RuntimeCodingServiceProtocol,
         engine: JSONRPCEngine,
         operationManager: OperationManagerProtocol,
         liveRuntimeIdentityCache: Sora2LiveRuntimeIdentityCache = .shared,
         pendingSubmissionStore: Sora2PendingSubmissionStore? = try? Sora2PendingSubmissionStore(),
         loadWalletNetworkSnapshot: @escaping () throws -> WalletNetworkSnapshot? = { try WalletNetworkStore().load() },
         lifecycleCoordinator: WalletLifecycleCoordinator = .shared,
         recoveryGate: WalletRecoveryCapabilityGate = .shared,
         onSubmission: @escaping () -> Void = { ExtrinsicService.noteSubmissionForReconciliation() },
         eventCenter: EventCenterProtocol = EventCenter.shared,
         refreshRuntime: @escaping (Error, RuntimeVersion?) -> Void = { Sora2LiveRuntimeValidator.requestRuntimeRefresh(after: $0, live: $1) }) {
        self.address = address
        self.cryptoType = cryptoType
        self.runtimeRegistry = runtimeRegistry
        self.engine = Sora2BoundedHTTPJSONRPCEngine.wrapping(engine)
        self.operationManager = operationManager
        self.liveRuntimeIdentityCache = liveRuntimeIdentityCache
        self.pendingSubmissionStore = pendingSubmissionStore
        self.loadWalletNetworkSnapshot = loadWalletNetworkSnapshot
        self.lifecycleCoordinator = lifecycleCoordinator
        self.recoveryGate = recoveryGate
        self.onSubmission = onSubmission
        self.eventCenter = eventCenter
        self.refreshRuntime = refreshRuntime
    }

    private func createNonceOperation() -> BaseOperation<UInt32> {
        JSONRPCListOperation<UInt32>(engine: engine,
                                     method: RPCMethod.getExtrinsicNonce,
                                     parameters: [address])
    }

    private func createBlockHeadOperation() -> BaseOperation<String> {
        JSONRPCListOperation<String>(engine: engine,
                                     method: RPCMethod.getHead,
                                     parameters: nil)
    }

    private func createLiveGenesisOperation() -> BaseOperation<String> {
        JSONRPCListOperation<String>(
            engine: engine,
            method: RPCMethod.getBlockHash,
            parameters: ["0x00000000"],
            timeout: 30
        )
    }

    private func createEraOperation(dependingOn finalizedHead: BaseOperation<String>)
    -> JSONRPCListOperation<Block.Header> {
        let headerOperation = JSONRPCListOperation<Block.Header>(engine: self.engine,
                                                                 method: RPCMethod.getHeader)
        headerOperation.configurationBlock = {
            guard let hash = try? finalizedHead.extractNoCancellableResultData() else {
                headerOperation.cancel()
                return
            }
            headerOperation.parameters = [hash]
        }

        return headerOperation
    }

    typealias EraAndHash = (era: Era, hash: String, blockNumber: Int)
    private func createBlockhashAndEraOperation(dependingOn finalizedHead: BaseOperation<String>,
                                                headerOperation: JSONRPCListOperation<Block.Header>)
    -> BaseOperation<EraAndHash> {
        return ClosureOperation {
            let header = try headerOperation.extractNoCancellableResultData()
            guard let blockNumber = BigUInt(hexString: header.number, radix: 16) else {
                throw BaseOperationError.unexpectedDependentResult
            }

            guard
                let exactBlockNumber = Int(exactly: blockNumber),
                let unsignedBlockNumber = UInt64(exactly: blockNumber)
            else {
                throw BaseOperationError.unexpectedDependentResult
            }
            let era = Era(
                blockNumber: unsignedBlockNumber,
                eraLength: UInt64(
                    Sora2SubmissionRecoveryContext.reviewedEraPeriod
                )
            )
            let hash = try finalizedHead.extractNoCancellableResultData()
            return (
                era: era,
                hash: hash,
                blockNumber: exactBlockNumber
            )
        }
    }

    private func createCodingFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        runtimeRegistry.fetchCoderFactoryOperation()
    }

    // 
    private func createExtrinsicOperation(dependingOn nonceOperation: BaseOperation<UInt32>,
                                          genesisOperation: BaseOperation<String>,
                                          hashAndEraOperation: BaseOperation<EraAndHash>,
                                          codingFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>,
                                          customClosure: @escaping ExtrinsicBuilderClosure,
                                          runtimeValidation:
                                            ((RuntimeCoderFactoryProtocol) throws -> Void)? = nil,
                                          finalizedHeadValidation:
                                            ((String) throws -> Void)? = nil,
                                          preSigningValidation:
                                            (() throws -> Void)? = nil,
                                          signingClosure: @escaping (Data) throws -> Data)
    -> BaseOperation<ExtrinsicInfo> {

        let currentCryptoType = cryptoType
        let currentAddress = address
        let engine = self.engine

        let build: () throws -> ExtrinsicInfo = {
            let nonce = try nonceOperation.extractNoCancellableResultData()
            let connectedGenesisHash = try genesisOperation
                .extractNoCancellableResultData()
            let hashAndEra = try hashAndEraOperation.extractNoCancellableResultData()
            let codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            try runtimeValidation?(codingFactory)
            try finalizedHeadValidation?(hashAndEra.hash)

            let addressFactory = SS58AddressFactory()

            let addressType = try addressFactory.extractAddressType(from: currentAddress)
            let accountId = try addressFactory.accountId(fromAddress: currentAddress, type: addressType)
            let signingGenesisHash = addressType.chain.genesisHash()
            let snapshot = try self.loadWalletNetworkSnapshot()
            let matchingNetworkAccounts = snapshot?.accounts.filter {
                $0.walletId == currentAddress &&
                    $0.networkId == .sora2 &&
                    $0.address == currentAddress
            } ?? []

            // Reject a custom/cross-network identity before the signing closure
            // can read the wallet secret. Address-derived/static genesis alone
            // is insufficient: the same live engine supplying nonce, head and
            // submission must prove canonical block zero here.
            guard
                addressType == 69,
                snapshot?.schemaVersion ==
                    WalletNetworkSnapshot.currentSchemaVersion,
                snapshot?.wallets.contains(where: {
                    $0.id == currentAddress &&
                        $0.existingSoraAddress == currentAddress
                }) == true,
                matchingNetworkAccounts.count == 1,
                try addressFactory.address(
                    fromAccountId: matchingNetworkAccounts[0].publicKey,
                    type: addressType
                ) == currentAddress
            else {
                // The account is not bound to one verified SORA2 account row
                // on this device. Nothing is signed; other accounts are not
                // affected.
                throw ExtrinsicServiceError.signingAccountUnavailable
            }
            guard
                PolkamarktRuntimeContract.matchesReviewedGenesisHash(
                    signingGenesisHash
                ),
                PolkamarktRuntimeContract.matchesReviewedGenesisHash(
                    connectedGenesisHash
                )
            else {
                throw ExtrinsicServiceError.unexpectedNetwork
            }
            guard
                Sora2PendingSubmissionStore.normalizedHash(
                    hashAndEra.hash
                ) != nil,
                case let .mortal(period, phase) = hashAndEra.era,
                period == UInt64(
                    Sora2SubmissionRecoveryContext.reviewedEraPeriod
                ),
                phase == UInt64(
                    hashAndEra.blockNumber %
                        Sora2SubmissionRecoveryContext.reviewedEraPeriod
                )
            else {
                throw ExtrinsicServiceError.unsupportedRuntimeMetadata
            }

            let guardedSigningClosure: (Data) throws -> Data = { data in
                // The builder has now encoded the exact signature payload.
                // Validate once, at the last synchronous boundary before the
                // lifecycle signer can read a secret.
                try preSigningValidation?()
                return try signingClosure(data)
            }
            let (extrinsicData, extrinsic) = try Self.assembleSignedExtrinsic(
                codingFactory: codingFactory,
                genesisHash: signingGenesisHash,
                accountId: accountId,
                nonce: nonce,
                era: hashAndEra.era,
                eraBlockHash: hashAndEra.hash,
                cryptoType: currentCryptoType,
                customClosure: customClosure,
                signingClosure: guardedSigningClosure
            )
            let transactionHash = try extrinsicData.blake2b32()
                .toHex(includePrefix: true)
            let recoveryContext = try Sora2SubmissionRecoveryContext.make(
                walletId: currentAddress,
                accountId: accountId,
                publicKey: matchingNetworkAccounts[0].publicKey,
                transactionHash: transactionHash,
                genesisHash: signingGenesisHash,
                specVersion: codingFactory.specVersion,
                transactionVersion: codingFactory.txVersion,
                metadataSHA256: try PolkamarktRuntimeContract
                    .signingMetadataSHA256(for: codingFactory),
                era: hashAndEra.era,
                eraBirthBlock: hashAndEra.blockNumber,
                eraBirthBlockHash: hashAndEra.hash
            )
            return ExtrinsicInfo(
                data: extrinsicData,
                object: extrinsic,
                recoveryContext: recoveryContext
            )
        }
        return ClosureOperation {
            do {
                return try build()
            } catch {
                // Every signing flow builds here. When the reason is an app
                // update or a node without a signing route, say so, also in
                // flows that show only a general error of their own.
                Sora2SigningNotice.report(error, nodeURL: engine.url)
                throw error
            }
        }
    }

    /// Encodes and signs one SORA2 extrinsic with the given runtime. The
    /// service calls this only after its wallet, chain and live-runtime
    /// checks; the live-network signing test calls it with a throwaway key,
    /// so both produce bytes with exactly the same code.
    static func assembleSignedExtrinsic(
        codingFactory: RuntimeCoderFactoryProtocol,
        genesisHash: String,
        accountId: Data,
        nonce: UInt32,
        era: Era,
        eraBlockHash: String,
        cryptoType: CryptoType,
        customClosure: ExtrinsicBuilderClosure,
        signingClosure: @escaping (Data) throws -> Data
    ) throws -> (data: Data, extrinsic: Extrinsic) {
        let account = MultiAddress.accoundId(accountId)

        var builder: ExtrinsicBuilderProtocol =
            try ExtrinsicBuilder(specVersion: codingFactory.specVersion,
                                 transactionVersion: codingFactory.txVersion,
                                 genesisHash: genesisHash)
                .with(address: account)
                .with(nonce: nonce)
                .with(era: era, blockHash: eraBlockHash)

        builder = try customClosure(builder)
        builder = try builder.signing(by: signingClosure,
                                      of: cryptoType,
                                      using: codingFactory.createEncoder(),
                                      metadata: codingFactory.metadata)
        let extrinsic = try builder.buildExtrinsic(metadata: codingFactory.metadata)
        let extrinsicData = try builder.build(encodingBy: codingFactory.createEncoder(), metadata: codingFactory.metadata)
        return (extrinsicData, extrinsic)
    }

    private func createSigningLeaseOperation(
        suppliedLease: WalletLifecycleLease?
    ) -> (
        operation: BaseOperation<WalletLifecycleLease>,
        ownsLease: Bool
    ) {
        let coordinator = lifecycleCoordinator
        let operation = coordinator.makeAcquireOperation(
            using: suppliedLease
        )
        return (operation, suppliedLease == nil)
    }

    private func enqueueSigningLeaseIfOwned(
        _ lifecycle: (
            operation: BaseOperation<WalletLifecycleLease>,
            ownsLease: Bool
        )
    ) {
        guard lifecycle.ownsLease else {
            return
        }
        lifecycleCoordinator
            .enqueueOwnedAcquireOperation(lifecycle.operation)
    }

    func createLiveRuntimeOperations() -> (
        version: BaseOperation<RuntimeVersion>,
        identity: BaseOperation<Sora2LiveRuntime>,
        all: [Operation]
    ) {
        // Both reads come from the same live engine that supplies the nonce,
        // the era and genesis, and that receives the signed bytes.
        let versionOperation = JSONRPCListOperation<RuntimeVersion>(
            engine: engine,
            method: RPCMethod.getRuntimeVersion,
            timeout: 30
        )
        let engine = self.engine
        let cache = liveRuntimeIdentityCache
        let identityOperation = ClosureOperation<Sora2LiveRuntime> {
            let version = try versionOperation.extractNoCancellableResultData()
            // A proof belongs to the node that served the metadata. A node
            // without an HTTPS route cannot be asked at all.
            guard let node = Sora2LiveRuntimeIdentityCache.nodeIdentity(
                for: engine.url
            ) else {
                throw Sora2BoundedHTTPJSONRPCError.invalidEndpoint
            }
            // The node's metadata is downloaded only when no proof for this
            // node and runtime version is stored yet, and only once at a
            // time.
            return try cache.liveRuntime(for: version, node: node) {
                let metadataHex = try Self.fetchCurrentMetadataHex(
                    engine: engine,
                    timeout: 60
                )
                // The connection may have moved to another node during the
                // download. Its bytes must not be recorded for this node.
                guard Sora2LiveRuntimeIdentityCache.nodeIdentity(
                    for: engine.url
                ) == node else {
                    throw ExtrinsicServiceError.connectionChanged
                }
                return metadataHex
            }
        }
        identityOperation.addDependency(versionOperation)

        return (
            versionOperation,
            identityOperation,
            [versionOperation, identityOperation]
        )
    }

    /// `state_getMetadata` at the node's best block, waited for
    /// synchronously like `JSONRPCOperation` does.
    static func fetchCurrentMetadataHex(
        engine: JSONRPCEngine,
        timeout: TimeInterval
    ) throws -> String {
        let semaphore = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var received: Result<String, Error>?
        let requestId = try engine.callMethod(
            RPCMethod.getRuntimeMetadata,
            params: [String]?.none
        ) { (result: Result<String, Error>) in
            lock.lock()
            received = result
            lock.unlock()
            semaphore.signal()
        }
        guard semaphore.wait(timeout: .now() + timeout) == .success else {
            engine.cancelForIdentifier(requestId)
            throw URLError(.timedOut)
        }
        lock.lock()
        defer { lock.unlock() }
        guard let received else {
            throw URLError(.cancelled)
        }
        return try received.get()
    }

    /// Every SORA2 extrinsic (fee estimates included) is encoded only with
    /// the runtime the connected node runs right now. When the app's metadata
    /// is behind a runtime upgrade, nothing is signed and the runtime sync
    /// service is asked to fetch the new metadata.
    func validateLiveSora2SigningRuntime(
        _ factory: RuntimeCoderFactoryProtocol,
        live: (
            version: BaseOperation<RuntimeVersion>,
            identity: BaseOperation<Sora2LiveRuntime>,
            all: [Operation]
        )
    ) throws {
        do {
            let liveRuntime = try live.identity
                .extractNoCancellableResultData()
            try Sora2LiveRuntimeValidator.validate(
                factory: factory,
                live: liveRuntime
            )
        } catch {
            refreshRuntime(error, try? live.version.extractNoCancellableResultData())
            throw error
        }
    }

    private func signingClosure(
        signer: SigningWrapperProtocol,
        lifecycleOperation: BaseOperation<WalletLifecycleLease>
    ) throws -> (Data) throws -> Data {
        guard let signer = signer as? LifecycleSigningWrapperProtocol else {
            throw ExtrinsicServiceError.lifecycleSignerRequired
        }
        return { data in
            let lease = try lifecycleOperation
                .extractNoCancellableResultData()
            return try signer.sign(
                data,
                lifecycleLease: lease
            ).rawData()
        }
    }

    /// Signed bytes were handed to the network (or may have been): have
    /// their status looked up shortly instead of at the next start.
    private static func noteSubmissionForReconciliation() {
        Task { @MainActor in
            Sora2PendingSubmissionRecoveryRuntime.shared.noteSubmission()
        }
    }

    private func releaseOwnedLease(
        operation: BaseOperation<WalletLifecycleLease>,
        ownsLease: Bool
    ) {
        guard ownsLease else {
            return
        }
        (try? operation.extractNoCancellableResultData())?.release()
    }
}

extension ExtrinsicService: ExtrinsicServiceProtocol {
    func estimateFee(_ closure: @escaping ExtrinsicBuilderClosure,
                     runningIn queue: DispatchQueue,
                     completion completionClosure: @escaping EstimateFeeClosure) {
        let nonceOperation = createNonceOperation()
        let genesisOperation = createLiveGenesisOperation()
        let headOperation = createBlockHeadOperation()
        let eraOperation = createEraOperation(dependingOn: headOperation)
        let hashAndEraOperation = createBlockhashAndEraOperation(dependingOn: headOperation, headerOperation: eraOperation)
        let codingFactoryOperation = runtimeRegistry.fetchCoderFactoryOperation()
        let liveRuntime = createLiveRuntimeOperations()

        let currentCryptoType = cryptoType

        let signingClosure: (Data) throws -> Data = { data in
            return try DummySigner(cryptoType: currentCryptoType).sign(data).rawData()
        }

        let builderOperation = createExtrinsicOperation(dependingOn: nonceOperation,
                                                        genesisOperation: genesisOperation,
                                                        hashAndEraOperation: hashAndEraOperation,
                                                        codingFactoryOperation: codingFactoryOperation,
                                                        customClosure: closure,
                                                        runtimeValidation: { factory in
                                                            try self.validateLiveSora2SigningRuntime(
                                                                factory,
                                                                live: liveRuntime
                                                            )
                                                        },
                                                        signingClosure: signingClosure)
        eraOperation.addDependency(headOperation)
        hashAndEraOperation.addDependency(headOperation)
        hashAndEraOperation.addDependency(eraOperation)
        builderOperation.addDependency(nonceOperation)
        builderOperation.addDependency(genesisOperation)
        builderOperation.addDependency(hashAndEraOperation)
        builderOperation.addDependency(codingFactoryOperation)
        builderOperation.addDependency(liveRuntime.identity)

        let infoOperation = feeDetailsOperation(queue: queue, builderOperation: builderOperation, completionClosure: completionClosure)

        let operations: [Operation] = [nonceOperation, genesisOperation, headOperation,
                                       eraOperation, hashAndEraOperation,
                                       codingFactoryOperation, builderOperation, infoOperation] +
            liveRuntime.all
        operationManager.enqueue(operations: operations, in: .transient)
    }

    @discardableResult
    func prepareAndEstimateFee(
        _ closure: @escaping ExtrinsicBuilderClosure,
        signer: SigningWrapperProtocol,
        preSigningValidation: @escaping () throws -> Void,
        runningIn queue: DispatchQueue,
        completion: @escaping (
            Result<PreparedExtrinsicFeeQualification, Error>
        ) -> Void
    ) -> CancellableCall {
        return prepareAndEstimateFee(
            closure,
            signer: signer,
            lifecycleLease: nil,
            runtimeValidation: nil,
            finalizedHeadValidation: nil,
            preSigningValidation: preSigningValidation,
            runningIn: queue,
            completion: completion
        )
    }

    @discardableResult
    func prepareAndEstimateFee(
        _ closure: @escaping ExtrinsicBuilderClosure,
        signer: SigningWrapperProtocol,
        lifecycleLease: WalletLifecycleLease?,
        runtimeValidation:
            ((RuntimeCoderFactoryProtocol) throws -> Void)?,
        finalizedHeadValidation: ((String) throws -> Void)?,
        preSigningValidation: @escaping () throws -> Void,
        runningIn queue: DispatchQueue,
        completion: @escaping (
            Result<PreparedExtrinsicFeeQualification, Error>
        ) -> Void
    ) -> CancellableCall {
        guard signer is LifecycleSigningWrapperProtocol else {
            queue.async {
                completion(.failure(ExtrinsicServiceError.lifecycleSignerRequired))
            }
            return EmptyCancellableCall()
        }

        let nonceOperation = createNonceOperation()
        let genesisOperation = createLiveGenesisOperation()
        let headOperation = createBlockHeadOperation()
        let eraOperation = createEraOperation(dependingOn: headOperation)
        eraOperation.addDependency(headOperation)
        let hashAndEraOperation = createBlockhashAndEraOperation(
            dependingOn: headOperation,
            headerOperation: eraOperation
        )
        hashAndEraOperation.addDependency(headOperation)
        hashAndEraOperation.addDependency(eraOperation)
        let codingFactoryOperation = runtimeRegistry.fetchCoderFactoryOperation()
        let liveRuntime = createLiveRuntimeOperations()
        let lifecycle = createSigningLeaseOperation(
            suppliedLease: lifecycleLease
        )
        lifecycle.operation.addDependency(nonceOperation)
        lifecycle.operation.addDependency(genesisOperation)
        lifecycle.operation.addDependency(hashAndEraOperation)
        lifecycle.operation.addDependency(codingFactoryOperation)
        lifecycle.operation.addDependency(liveRuntime.identity)

        let signingClosure: (Data) throws -> Data
        do {
            signingClosure = try self.signingClosure(
                signer: signer,
                lifecycleOperation: lifecycle.operation
            )
        } catch {
            queue.async { completion(.failure(error)) }
            return EmptyCancellableCall()
        }

        let builderOperation = createExtrinsicOperation(
            dependingOn: nonceOperation,
            genesisOperation: genesisOperation,
            hashAndEraOperation: hashAndEraOperation,
            codingFactoryOperation: codingFactoryOperation,
            customClosure: closure,
            runtimeValidation: { factory in
                try self.validateLiveSora2SigningRuntime(
                    factory,
                    live: liveRuntime
                )
                try runtimeValidation?(factory)
            },
            finalizedHeadValidation: finalizedHeadValidation,
            preSigningValidation: preSigningValidation,
            signingClosure: signingClosure
        )
        builderOperation.addDependency(nonceOperation)
        builderOperation.addDependency(genesisOperation)
        builderOperation.addDependency(headOperation)
        builderOperation.addDependency(eraOperation)
        builderOperation.addDependency(hashAndEraOperation)
        builderOperation.addDependency(codingFactoryOperation)
        builderOperation.addDependency(liveRuntime.identity)
        builderOperation.addDependency(lifecycle.operation)

        let feeOperation = JSONRPCListOperation<InclusionFeeInfo>(
            engine: engine,
            method: RPCMethod.feeDetails,
            timeout: 60
        )
        feeOperation.configurationBlock = {
            do {
                let exactBytes = try builderOperation
                    .extractNoCancellableResultData().data
                feeOperation.parameters = [
                    exactBytes.toHex(includePrefix: true)
                ]
            } catch {
                feeOperation.result = .failure(error)
            }
        }
        feeOperation.addDependency(builderOperation)

        builderOperation.completionBlock = {
            self.releaseOwnedLease(
                operation: lifecycle.operation,
                ownsLease: lifecycle.ownsLease
            )
        }
        feeOperation.completionBlock = {
            let result: Result<PreparedExtrinsicFeeQualification, Error>
            do {
                let info = try builderOperation
                    .extractNoCancellableResultData()
                let feeDetails = try feeOperation
                    .extractNoCancellableResultData()
                let rawFee = feeDetails.fee
                guard let fee = BigUInt(rawFee), fee > 0 else {
                    throw WalletNetworkOperationFactoryError.invalidFee
                }
                let hash = try info.data.blake2b32()
                    .toHex(includePrefix: true)
                result = .success(
                    PreparedExtrinsicFeeQualification(
                        prepared: PreparedExtrinsicSubmission(
                            data: info.data,
                            hash: hash,
                            call: info.object.call,
                            recoveryContext: info.recoveryContext
                        ),
                        rawFee: rawFee
                    )
                )
            } catch {
                result = .failure(error)
            }
            queue.async { completion(result) }
        }

        enqueueSigningLeaseIfOwned(lifecycle)
        var managedOperations: [Operation] = [
            nonceOperation,
            genesisOperation,
            headOperation,
            eraOperation,
            hashAndEraOperation,
            codingFactoryOperation,
            liveRuntime.version,
            liveRuntime.identity,
            builderOperation,
            feeOperation
        ]
        if !lifecycle.ownsLease {
            managedOperations.insert(lifecycle.operation, at: 0)
        }
        operationManager.enqueue(
            operations: managedOperations,
            in: .transient
        )

        return CompoundOperationWrapper(
            targetOperation: feeOperation,
            dependencies: [
                lifecycle.operation,
                nonceOperation,
                genesisOperation,
                headOperation,
                eraOperation,
                hashAndEraOperation,
                codingFactoryOperation,
                liveRuntime.version,
                    liveRuntime.identity,
                builderOperation
            ]
        )
    }
    
    private func feeDetailsOperation(queue: DispatchQueue,
                                      builderOperation: BaseOperation<ExtrinsicInfo>,
                                      completionClosure: @escaping EstimateFeeClosure) -> JSONRPCListOperation<InclusionFeeInfo> {
        let infoOperation = JSONRPCListOperation<InclusionFeeInfo>(engine: engine,
                                                                   method: RPCMethod.feeDetails,
                                                                   timeout: 60)
        infoOperation.configurationBlock = {
            do {
                let extrinsic = try builderOperation.extractNoCancellableResultData().data.toHex(includePrefix: true)
                infoOperation.parameters = [extrinsic]
            } catch {
                infoOperation.result = .failure(error)
            }
        }

        infoOperation.addDependency(builderOperation)

        infoOperation.completionBlock = {
            queue.async {
                if case let .success(model) = infoOperation.result {
                    completionClosure(.success(model.fee))
                    return
                }
                
                if case let .failure(error) = infoOperation.result {
                    completionClosure(.failure(error))
                    return
                }

                completionClosure(.failure(BaseOperationError.parentOperationCancelled))
            }
        }

        return infoOperation
    }

    func prepare(
        _ closure: @escaping ExtrinsicBuilderClosure,
        signer: SigningWrapperProtocol,
        runningIn queue: DispatchQueue,
        completion: @escaping (Result<PreparedExtrinsicSubmission, Error>) -> Void
    ) {
        prepare(
            closure,
            signer: signer,
            lifecycleLease: nil,
            runtimeValidation: nil,
            preSigningValidation: nil,
            runningIn: queue,
            completion: completion
        )
    }

    func prepare(
        _ closure: @escaping ExtrinsicBuilderClosure,
        signer: SigningWrapperProtocol,
        lifecycleLease: WalletLifecycleLease?,
        runtimeValidation:
            ((RuntimeCoderFactoryProtocol) throws -> Void)?,
        preSigningValidation: (() throws -> Void)?,
        runningIn queue: DispatchQueue,
        completion: @escaping (
            Result<PreparedExtrinsicSubmission, Error>
        ) -> Void
    ) {
        let nonceOperation = createNonceOperation()
        let genesisOperation = createLiveGenesisOperation()
        let headOperation = createBlockHeadOperation()
        let eraOperation = createEraOperation(dependingOn: headOperation)
        eraOperation.addDependency(headOperation)

        let hashAndEraOperation = createBlockhashAndEraOperation(
            dependingOn: headOperation,
            headerOperation: eraOperation
        )
        hashAndEraOperation.addDependency(headOperation)
        hashAndEraOperation.addDependency(eraOperation)

        let codingFactoryOperation = runtimeRegistry.fetchCoderFactoryOperation()
        let liveRuntime = createLiveRuntimeOperations()
        guard signer is LifecycleSigningWrapperProtocol else {
            queue.async {
                completion(
                    .failure(
                        ExtrinsicServiceError.lifecycleSignerRequired
                    )
                )
            }
            return
        }
        let lifecycle = createSigningLeaseOperation(
            suppliedLease: lifecycleLease
        )
        lifecycle.operation.addDependency(nonceOperation)
        lifecycle.operation.addDependency(genesisOperation)
        lifecycle.operation.addDependency(hashAndEraOperation)
        lifecycle.operation.addDependency(codingFactoryOperation)
        lifecycle.operation.addDependency(liveRuntime.identity)
        let signingClosure: (Data) throws -> Data
        do {
            signingClosure = try self.signingClosure(
                signer: signer,
                lifecycleOperation: lifecycle.operation
            )
        } catch {
            releaseOwnedLease(
                operation: lifecycle.operation,
                ownsLease: lifecycle.ownsLease
            )
            queue.async {
                completion(.failure(error))
            }
            return
        }
        let builderOperation = createExtrinsicOperation(
            dependingOn: nonceOperation,
            genesisOperation: genesisOperation,
            hashAndEraOperation: hashAndEraOperation,
            codingFactoryOperation: codingFactoryOperation,
            customClosure: closure,
            runtimeValidation: { factory in
                try self.validateLiveSora2SigningRuntime(
                    factory,
                    live: liveRuntime
                )
                try runtimeValidation?(factory)
            },
            preSigningValidation: preSigningValidation,
            signingClosure: signingClosure
        )
        builderOperation.addDependency(nonceOperation)
        builderOperation.addDependency(genesisOperation)
        builderOperation.addDependency(headOperation)
        builderOperation.addDependency(eraOperation)
        builderOperation.addDependency(hashAndEraOperation)
        builderOperation.addDependency(codingFactoryOperation)
        builderOperation.addDependency(liveRuntime.identity)
        builderOperation.addDependency(lifecycle.operation)
        builderOperation.completionBlock = {
            let result: Result<PreparedExtrinsicSubmission, Error>
            do {
                let info = try builderOperation
                    .extractNoCancellableResultData()
                let hash = try info.data.blake2b32()
                    .toHex(includePrefix: true)
                result = .success(
                    PreparedExtrinsicSubmission(
                        data: info.data,
                        hash: hash,
                        call: info.object.call,
                        recoveryContext: info.recoveryContext
                    )
                )
            } catch {
                result = .failure(error)
            }
            self.releaseOwnedLease(
                operation: lifecycle.operation,
                ownsLease: lifecycle.ownsLease
            )
            queue.async {
                completion(result)
            }
        }

        var operations: [Operation] = [
            nonceOperation,
            genesisOperation,
            headOperation,
            eraOperation,
            hashAndEraOperation,
            codingFactoryOperation,
            liveRuntime.version,
            liveRuntime.identity,
            builderOperation
        ]
        if !lifecycle.ownsLease {
            operations.insert(lifecycle.operation, at: 0)
        }
        enqueueSigningLeaseIfOwned(lifecycle)
        operationManager.enqueue(
            operations: operations,
            in: .transient
        )
    }

    func submitPrepared(
        _ prepared: PreparedExtrinsicSubmission,
        retainingTransportWitness: Bool,
        expectedRawFee: String,
        preTransportValidation: @escaping () throws -> Void,
        runningIn queue: DispatchQueue,
        completion: @escaping (Result<String, Error>) -> Void
    ) -> CancellableCall {
        var acquiredTransportLease: WalletLifecycleLease?
        var pendingSubmission: Sora2PendingSubmission?
        let signedPayload: MutableSignedTransportPayload
        do {
            guard let pendingSubmissionStore else {
                throw ExtrinsicServiceError.invalidLocalHash
            }
            guard let recoveryContext = prepared.recoveryContext else {
                // Every newly submitted generic SORA2 transaction must carry
                // the complete, versioned status-recovery witness produced by
                // the reviewed builder. Allowing a caller-created prepared
                // value without it would make a post-handoff crash permanently
                // unrecoverable.
                throw ExtrinsicServiceError
                    .invalidPendingSubmissionTransition
            }
            pendingSubmission = try pendingSubmissionStore.stage(
                account: address,
                hash: prepared.hash,
                retainingTransportWitness: retainingTransportWitness,
                recoveryContext: recoveryContext
            )
            guard
                let acquired =
                    try lifecycleCoordinator
                        .tryAcquireForMutableWalletAccess()
            else {
                throw WalletNetworkMigrationError
                    .lifecycleMutationBusy
            }
            acquiredTransportLease = acquired
            try recoveryGate
                .requireAuthorizedLifecycleContinuation()
            try preTransportValidation()
            signedPayload = try prepared.consumeForTransport()
        } catch {
            acquiredTransportLease?.release()
            if let pendingSubmission {
                try? pendingSubmissionStore?.removeBeforeSubmission(
                    pendingSubmission
                )
            }
            let classified: PreparedExtrinsicTransportError
            if let serviceError = error as? ExtrinsicServiceError,
               case .duplicatePreparedSubmission = serviceError {
                // A matching durable hash means these exact bytes belong to a
                // prior attempt whose transport outcome may already be
                // ambiguous. Refuse the new handoff and retain reconciliation
                // state instead of presenting this as safely retryable.
                classified = .submissionUnknown(
                    localHash:
                        Sora2PendingSubmissionStore.normalizedHash(
                            prepared.hash
                        ) ?? prepared.hash,
                    error: error
                )
            } else {
                classified = .failedBeforeTransport(error)
            }
            queue.async {
                completion(.failure(classified))
            }
            return EmptyCancellableCall()
        }
        guard let transportLease = acquiredTransportLease else {
            if let pendingSubmission {
                try? pendingSubmissionStore?.removeBeforeSubmission(
                    pendingSubmission
                )
            }
            queue.async {
                completion(
                    .failure(
                        PreparedExtrinsicTransportError
                            .failedBeforeTransport(
                                WalletNetworkMigrationError
                                    .lifecycleMutationBusy
                            )
                    )
                )
            }
            return EmptyCancellableCall()
        }
        guard let stagedPendingSubmission = pendingSubmission else {
            transportLease.release()
            signedPayload.discard()
            queue.async {
                completion(
                    .failure(
                        PreparedExtrinsicTransportError
                            .failedBeforeTransport(
                                ExtrinsicServiceError.invalidLocalHash
                            )
                    )
                )
            }
            return EmptyCancellableCall()
        }
        let feeOperation = JSONRPCListOperation<InclusionFeeInfo>(
            engine: engine,
            method: RPCMethod.feeDetails,
            timeout: 60
        )
        feeOperation.configurationBlock = {
            do {
                feeOperation.parameters = [
                    try signedPayload.hexForFeeQualification()
                ]
            } catch {
                feeOperation.result = .failure(error)
            }
        }
        feeOperation.completionBlock = {
            feeOperation.parameters = nil
        }
        let operation = PreparedExtrinsicRPCOperation(
            engine: engine,
            method: RPCMethod.submitExtrinsic,
            parameters: nil,
            timeout: 60,
            preTransportValidation: {
                _ = try Sora2SignedFeeRevalidation.requireExact(
                    expectedRawFee: expectedRawFee,
                    actualRawFee: try feeOperation
                        .extractNoCancellableResultData().fee
                )
                try self.recoveryGate
                    .requireAuthorizedLifecycleContinuation()
                try preTransportValidation()
                if retainingTransportWitness {
                    // This durable transition is the last step before the RPC
                    // operation can mark transport as started. A crash before
                    // it retains `stagedBeforeTransport`; a crash after it is
                    // conservatively ambiguous and must never be retried.
                    guard let pendingSubmissionStore =
                        self.pendingSubmissionStore
                    else {
                        throw ExtrinsicServiceError.invalidLocalHash
                    }
                    try pendingSubmissionStore.update(
                        stagedPendingSubmission,
                        state: .submitting
                    )
                }
            },
            transportDidHandoff: {
                transportLease.release()
            }
        )
        operation.addDependency(feeOperation)
        operation.configurationBlock = {
            do {
                try self.recoveryGate
                    .requireAuthorizedLifecycleContinuation()
                let signedHex =
                    try signedPayload.consumeHexForTransport()
                operation.parameters = [
                    signedHex
                ]
            } catch {
                operation.result = .failure(error)
            }
        }
        operation.completionBlock = {
            // Also releases on cancellation before configuration. Release is
            // idempotent, so the normal configured path is safe.
            transportLease.release()
            signedPayload.discard()
            let mayHaveEnteredTransport =
                operation.mayHaveEnteredTransport
            operation.parameters = nil
            queue.async {
                if let result = operation.result {
                    switch result {
                    case let .success(returnedHash):
                        guard
                            Sora2PendingSubmissionStore.normalizedHash(
                                returnedHash
                            ) ==
                                Sora2PendingSubmissionStore.normalizedHash(
                                    prepared.hash
                                )
                        else {
                            try? self.pendingSubmissionStore?.update(
                                stagedPendingSubmission,
                                state: .submissionUnknown
                            )
                            completion(
                                .failure(
                                    PreparedExtrinsicTransportError
                                        .submissionUnknown(
                                            localHash:
                                                stagedPendingSubmission
                                                    .extrinsicHash,
                                            error: ExtrinsicServiceError
                                                .invalidLocalHash
                                        )
                                )
                            )
                            return
                        }
                        // A journal write failure after successful transport
                        // must never turn success into a retryable transaction
                        // failure. The durable `submitting` record remains
                        // reconciliation-safe.
                        try? self.pendingSubmissionStore?.update(
                            stagedPendingSubmission,
                            state: retainingTransportWitness
                                ? .submittedRetained
                                : .submitted
                        )
                        self.onSubmission()
                        completion(.success(returnedHash))
                    case let .failure(error):
                        if mayHaveEnteredTransport {
                            try? self.pendingSubmissionStore?.update(
                                stagedPendingSubmission,
                                state: .submissionUnknown
                            )
                            self.onSubmission()
                        } else {
                            try? self.pendingSubmissionStore?
                                .removeBeforeSubmission(
                                    stagedPendingSubmission
                                )
                        }
                        let classified =
                            mayHaveEnteredTransport
                            ? PreparedExtrinsicTransportError
                                .submissionUnknown(
                                    localHash:
                                        stagedPendingSubmission
                                            .extrinsicHash,
                                    error: error
                                )
                            : PreparedExtrinsicTransportError
                                .failedBeforeTransport(error)
                        completion(.failure(classified))
                    }
                } else {
                    let cancelled =
                        BaseOperationError.parentOperationCancelled
                    if mayHaveEnteredTransport {
                        try? self.pendingSubmissionStore?.update(
                            stagedPendingSubmission,
                            state: .submissionUnknown
                        )
                        self.onSubmission()
                    } else {
                        try? self.pendingSubmissionStore?
                            .removeBeforeSubmission(
                                stagedPendingSubmission
                            )
                    }
                    let classified =
                        mayHaveEnteredTransport
                        ? PreparedExtrinsicTransportError
                            .submissionUnknown(
                                localHash:
                                    stagedPendingSubmission
                                        .extrinsicHash,
                                error: cancelled
                            )
                        : PreparedExtrinsicTransportError
                            .failedBeforeTransport(cancelled)
                    completion(
                        .failure(classified)
                    )
                }
            }
        }
        operationManager.enqueue(
            operations: [feeOperation, operation],
            in: .transient
        )
        // Cancellation owns the fee query as well as its dependent transport
        // operation. Returning only the target would let an abandoned exact-byte
        // qualification RPC continue after the Swift task was cancelled.
        return CompoundOperationWrapper(
            targetOperation: operation,
            dependencies: [feeOperation]
        )
    }

    func submit(_ closure: @escaping ExtrinsicBuilderClosure,
                signer: SigningWrapperProtocol,
                runningIn queue: DispatchQueue,
                completion completionClosure: @escaping ExtrinsicSubmitClosure) {
        submit(
            closure,
            signer: signer,
            lifecycleLease: nil,
            runningIn: queue,
            completion: completionClosure
        )
    }

    func submit(
        _ closure: @escaping ExtrinsicBuilderClosure,
        signer: SigningWrapperProtocol,
        lifecycleLease: WalletLifecycleLease?,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping ExtrinsicSubmitClosure
    ) {
        submit(
            closure,
            signer: signer,
            lifecycleLease: lifecycleLease,
            purpose: .generic,
            runningIn: queue,
            completion: completionClosure
        )
    }

    func submit(
        _ closure: @escaping ExtrinsicBuilderClosure,
        signer: SigningWrapperProtocol,
        lifecycleLease: WalletLifecycleLease?,
        purpose: Sora2PendingSubmissionPurpose,
        preSigningValidation: (() throws -> Void)? = nil,
        runningIn queue: DispatchQueue,
        completion completionClosure: @escaping ExtrinsicSubmitClosure
    ) {
        guard signer is LifecycleSigningWrapperProtocol else {
            queue.async {
                completionClosure(
                    .failure(
                        ExtrinsicServiceError.lifecycleSignerRequired
                    ),
                    nil,
                    nil
                )
            }
            return
        }
        let nonceOperation = createNonceOperation()
        let genesisOperation = createLiveGenesisOperation()

        let headOperation = createBlockHeadOperation()
        let eraOperation = createEraOperation(dependingOn: headOperation)
        eraOperation.addDependency(headOperation)

        let hashAndEraOperation = createBlockhashAndEraOperation(dependingOn: headOperation, headerOperation: eraOperation)
        hashAndEraOperation.addDependency(headOperation)
        hashAndEraOperation.addDependency(eraOperation)

        let codingFactoryOperation = runtimeRegistry.fetchCoderFactoryOperation()
        let liveRuntime = createLiveRuntimeOperations()

        let lifecycle = createSigningLeaseOperation(
            suppliedLease: lifecycleLease
        )
        lifecycle.operation.addDependency(nonceOperation)
        lifecycle.operation.addDependency(genesisOperation)
        lifecycle.operation.addDependency(hashAndEraOperation)
        lifecycle.operation.addDependency(codingFactoryOperation)
        lifecycle.operation.addDependency(liveRuntime.identity)

        let signingClosure: (Data) throws -> Data
        do {
            signingClosure = try self.signingClosure(
                signer: signer,
                lifecycleOperation: lifecycle.operation
            )
        } catch {
            queue.async {
                completionClosure(.failure(error), nil, nil)
            }
            return
        }

        let builderOperation = createExtrinsicOperation(
            dependingOn: nonceOperation,
            genesisOperation: genesisOperation,
            hashAndEraOperation: hashAndEraOperation,
            codingFactoryOperation: codingFactoryOperation,
            customClosure: closure,
            runtimeValidation: { factory in
                try self.validateLiveSora2SigningRuntime(
                    factory,
                    live: liveRuntime
                )
            },
            preSigningValidation: preSigningValidation,
            signingClosure: signingClosure
        )

        builderOperation.addDependency(nonceOperation)
        builderOperation.addDependency(genesisOperation)
        builderOperation.addDependency(headOperation)
        builderOperation.addDependency(eraOperation)
        builderOperation.addDependency(hashAndEraOperation)
        builderOperation.addDependency(codingFactoryOperation)
        builderOperation.addDependency(liveRuntime.identity)
        builderOperation.addDependency(lifecycle.operation)

        let stageOperation = ClosureOperation<StagedExtrinsicInfo> {
            let info = try builderOperation
                .extractNoCancellableResultData()
            let hash = try info.data.blake2b32()
                .toHex(includePrefix: true)
            guard let store = self.pendingSubmissionStore else {
                throw ExtrinsicServiceError.invalidLocalHash
            }
            let pending = try store.stage(
                account: self.address,
                hash: hash,
                recoveryContext: info.recoveryContext,
                purpose: purpose
            )
            return StagedExtrinsicInfo(
                info: info,
                pending: pending
            )
        }
        stageOperation.addDependency(builderOperation)

        let submitOperation = PreparedExtrinsicRPCOperation(
            // Every mutation uses one bounded HTTPS handoff. Finality is
            // recovered from canonical finalized blocks by exact local hash;
            // no watched-submission/reconnect mutation path remains.
            engine: engine,
            method: RPCMethod.submitExtrinsic,
            parameters: nil,
            timeout: 60,
            preTransportValidation: {
                try self.recoveryGate
                    .requireAuthorizedLifecycleContinuation()
            },
            transportDidHandoff: {
                self.releaseOwnedLease(
                    operation: lifecycle.operation,
                    ownsLease: lifecycle.ownsLease
                )
            }
        )
        submitOperation.configurationBlock = {
            do {
                let staged = try stageOperation
                    .extractNoCancellableResultData()
                try self.recoveryGate
                    .requireMutableWalletAccess()
                let extrinsicHex = staged.info.data
                    .toHex(includePrefix: true)

                self.eventCenter.notify(
                    with: ExtricsicSubmittedEvent(
                        extrinsicHex: extrinsicHex,
                        extrinsicInfo: staged.info
                    )
                )
                submitOperation.parameters = [extrinsicHex]
            } catch {
                submitOperation.result = .failure(error)
            }
        }

        submitOperation.addDependency(stageOperation)

        submitOperation.completionBlock = {
            self.releaseOwnedLease(
                operation: lifecycle.operation,
                ownsLease: lifecycle.ownsLease
            )
            queue.async {
                let staged = try? stageOperation
                    .extractNoCancellableResultData()
                var callbackHash = staged?.pending.extrinsicHash
                var result: Result<String, Error> = submitOperation.result ??
                    .failure(
                        BaseOperationError.parentOperationCancelled
                    )
                if let staged {
                    switch result {
                    case let .success(returnedHash):
                        if Sora2PendingSubmissionStore
                            .normalizedHash(returnedHash) !=
                            staged.pending.extrinsicHash {
                            try? self.pendingSubmissionStore?.update(
                                staged.pending,
                                state: .submissionUnknown
                            )
                            result = .failure(
                                PreparedExtrinsicTransportError
                                    .submissionUnknown(
                                        localHash:
                                            staged.pending
                                                .extrinsicHash,
                                        error: ExtrinsicServiceError
                                            .invalidLocalHash
                                    )
                            )
                        } else {
                            // Transport has returned success. A subsequent
                            // journal write failure must retain that success;
                            // the durable `submitting` record remains a
                            // conservative reconciliation barrier and prevents
                            // an ambiguous automatic retry.
                            result = Sora2TransportCompletionPolicy
                                .preservingConfirmedSuccess(result) {
                                    try self.pendingSubmissionStore?.update(
                                        staged.pending,
                                        state: .submitted
                                    )
                                }
                        }
                    case let .failure(error):
                        if submitOperation.mayHaveEnteredTransport {
                            try? self.pendingSubmissionStore?.update(
                                staged.pending,
                                state: .submissionUnknown
                            )
                            result = .failure(
                                PreparedExtrinsicTransportError
                                    .submissionUnknown(
                                        localHash:
                                            staged.pending
                                                .extrinsicHash,
                                        error: error
                                    )
                            )
                        } else {
                            try? self.pendingSubmissionStore?
                                .removeBeforeSubmission(
                                    staged.pending
                                )
                            result = .failure(
                                PreparedExtrinsicTransportError
                                    .failedBeforeTransport(error)
                            )
                        }
                    }
                } else {
                    let stageError: Error
                    switch stageOperation.result {
                    case let .failure(error):
                        stageError = error
                    case .success, .none:
                        stageError =
                            BaseOperationError.parentOperationCancelled
                    }
                    if let serviceError =
                        stageError as? ExtrinsicServiceError,
                       case .duplicatePreparedSubmission = serviceError,
                       let info = try? builderOperation
                           .extractNoCancellableResultData(),
                       let computedHash = try? info.data.blake2b32()
                           .toHex(includePrefix: true),
                       let localHash =
                           Sora2PendingSubmissionStore.normalizedHash(
                               computedHash
                           ) {
                        callbackHash = localHash
                        result = .failure(
                            PreparedExtrinsicTransportError
                                .submissionUnknown(
                                    localHash: localHash,
                                    error: stageError
                                )
                        )
                    } else {
                        result = .failure(
                            PreparedExtrinsicTransportError
                                .failedBeforeTransport(stageError)
                        )
                    }
                }
                if staged != nil, submitOperation.mayHaveEnteredTransport {
                    self.onSubmission()
                }
                completionClosure(
                    result,
                    callbackHash,
                    staged?.info.object
                )
            }
        }

        var operations: [Operation] = [
            nonceOperation,
            genesisOperation,
            headOperation,
            eraOperation,
            hashAndEraOperation,
            codingFactoryOperation,
            liveRuntime.version,
            liveRuntime.identity,
            builderOperation,
            stageOperation,
            submitOperation
        ]
        if !lifecycle.ownsLease {
            operations.insert(lifecycle.operation, at: 0)
        }
        enqueueSigningLeaseIfOwned(lifecycle)
        operationManager.enqueue(operations: operations, in: .transient)
    }
}
