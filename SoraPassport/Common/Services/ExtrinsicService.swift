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
import SSFUtils
import RobinHood
import IrohaCrypto
import BigInt

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
}

enum Sora2BoundedHTTPJSONRPCError: LocalizedError {
    case invalidEndpoint
    case methodNotAllowed
    case requestTooLarge
    case responseTooLarge
    case invalidResponse
    case httpStatus
    case remoteError
    case subscriptionsUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "The selected SORA2 node has no reviewed HTTPS RPC route."
        case .methodNotAllowed:
            return "The SORA2 RPC method is not admitted by the mobile manifest."
        case .requestTooLarge:
            return "The SORA2 RPC request exceeded the mobile byte limit."
        case .responseTooLarge:
            return "The SORA2 RPC response exceeded the mobile byte limit."
        case .invalidResponse:
            return "The SORA2 node returned an invalid JSON-RPC response."
        case .httpStatus:
            return "The SORA2 node rejected the HTTPS RPC request."
        case .remoteError:
            return "The SORA2 node rejected the JSON-RPC operation."
        case .subscriptionsUnavailable:
            return "Subscriptions are unavailable on the bounded one-shot RPC route."
        }
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

    private let sourceEngine: JSONRPCEngine
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

    init(sourceEngine: JSONRPCEngine, session: URLSession? = nil) {
        self.sourceEngine = sourceEngine
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
        get { sourceEngine.url }
        set { sourceEngine.url = newValue }
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
        let endpoint = try Self.httpEndpoint(for: sourceEngine.url)
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
            if let http = response as? HTTPURLResponse,
               http.statusCode != 200 {
                throw Sora2BoundedHTTPJSONRPCError.httpStatus
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
            specVersion == PolkamarktRuntimeContract.specVersion &&
            transactionVersion ==
                PolkamarktRuntimeContract.transactionVersion &&
            metadataSHA256 ==
                PolkamarktRuntimeContract.metadataFileSHA256 &&
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

    /// Legacy submitted rows predate generic recovery and retain their prior
    /// pruning behavior. Every newly qualified row remains deletion- and
    /// capacity-protected until a durable authoritative terminal resolution
    /// accompanies the submitted transport state.
    var isPrunable: Bool {
        state == .submitted &&
            (recoveryContext == nil || terminalResolution != nil)
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
        purpose: Sora2PendingSubmissionPurpose = .generic
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
        if values.count == Self.maximumEntries {
            guard let pruneIndex = values.indices
                .filter({ values[$0].isPrunable })
                .min(by: {
                    values[$0].updatedAt < values[$1].updatedAt
                })
            else {
                throw ExtrinsicServiceError.pendingSubmissionCapacityExceeded
            }
            values.remove(at: pruneIndex)
        }
        let now = Date()
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
                let blockHash = Self.normalizedHash(rawBlockHash)
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
                finalizedHeight >= context.eraDeathBlockExclusive
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
        return values
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

/// Status-only recovery for ordinary SORA2 submissions. It scans canonical
/// finalized blocks from the exact signed mortal era and decodes only System
/// execution events. It has no signer, builder, signed bytes, or submission
/// API, so restart and foreground recovery cannot resubmit an ambiguous hash.
final class Sora2PendingSubmissionReconciler {
    private static let maximumWitnessesPerPass = 16
    private typealias CanonicalBlock = (
        blockHash: String,
        extrinsicIndices: [String: UInt32]
    )

    private let store: Sora2PendingSubmissionStore
    private let rpc: PolkamarktRPCClient
    private let runtimeValidator: PolkamarktRuntimeValidator
    private let engine: JSONRPCEngine
    private var canonicalBlockCache: [Int: CanonicalBlock] = [:]
    private var recoveryHashes = Set<String>()

    init(
        store: Sora2PendingSubmissionStore,
        engine: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) {
        self.store = store
        self.engine = Sora2BoundedHTTPJSONRPCEngine.wrapping(engine)
        rpc = PolkamarktRPCClient(engine: self.engine)
        runtimeValidator = PolkamarktRuntimeValidator(
            runtimeService: runtimeService,
            rpc: rpc
        )
    }

    func reconcileStatusOnly() async throws {
        try Task.checkCancellation()
        canonicalBlockCache.removeAll(keepingCapacity: true)
        recoveryHashes.removeAll(keepingCapacity: true)
        let values = try store.all()
        let qualified = values.filter {
            !$0.isPrunable &&
                $0.state != .stagedBeforeTransport &&
                $0.recoveryContext != nil
        }
        guard !qualified.isEmpty else {
            return
        }
        guard let snapshot = try WalletNetworkStore().load() else {
            throw Sora2PendingRecoveryError.unavailable
        }
        for pending in qualified {
            try validateWalletBinding(pending, snapshot: snapshot)
        }

        let finalized = try await rpc.finalizedBlockNumber()
        guard let finalizedHeight = Int(exactly: finalized) else {
            throw Sora2PendingRecoveryError.unavailable
        }
        let ordered = qualified.sorted { lhs, rhs in
            let lhsExpired = lhs.recoveryContext.map {
                finalizedHeight >= $0.eraDeathBlockExclusive
            } ?? false
            let rhsExpired = rhs.recoveryContext.map {
                finalizedHeight >= $0.eraDeathBlockExclusive
            } ?? false
            if lhsExpired != rhsExpired {
                return lhsExpired && !rhsExpired
            }
            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt < rhs.updatedAt
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
        let selected = Array(
            ordered.prefix(Self.maximumWitnessesPerPass)
        )
        recoveryHashes = Set(selected.map(\.extrinsicHash))
        guard
            recoveryHashes.count == selected.count,
            let canonicalGenesis = try await canonicalBlock(
                at: 0,
                finalized: finalized
            )
        else {
            throw Sora2PendingRecoveryError.unavailable
        }
        let factory = try await runtimeValidator.validate()

        for pending in selected {
            try Task.checkCancellation()
            guard let context = pending.recoveryContext else {
                continue
            }
            guard
                canonicalGenesis.blockHash == context.genesisHash,
                factory.specVersion == context.specVersion,
                factory.txVersion == context.transactionVersion,
                try PolkamarktRuntimeContract.signingMetadataSHA256(
                    for: factory
                ) == context.metadataSHA256
            else {
                throw Sora2PendingRecoveryError.unavailable
            }
            try await reconcile(
                pending,
                context: context,
                finalizedHeight: finalizedHeight,
                finalized: finalized,
                factory: factory
            )
        }
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
        finalized: BigUInt,
        factory: RuntimeCoderFactoryProtocol
    ) async throws {
        guard finalizedHeight >= context.eraBirthBlock else {
            throw Sora2PendingRecoveryError.unavailable
        }
        let lastEraBlock = context.eraDeathBlockExclusive - 1
        let scanThrough = min(finalizedHeight, lastEraBlock)
        var foundInclusion: (
            blockNumber: Int,
            blockHash: String,
            extrinsicIndex: UInt32
        )?

        for blockNumber in context.eraBirthBlock ... scanThrough {
            try Task.checkCancellation()
            guard let canonical = try await canonicalBlock(
                at: blockNumber,
                finalized: finalized
            ) else {
                throw Sora2PendingRecoveryError.unavailable
            }
            if blockNumber == context.eraBirthBlock,
               canonical.blockHash != context.eraBirthBlockHash {
                throw Sora2PendingRecoveryError.unavailable
            }
            if let extrinsicIndex =
                canonical.extrinsicIndices[pending.extrinsicHash] {
                guard foundInclusion == nil else {
                    throw Sora2PendingRecoveryError.unavailable
                }
                foundInclusion = (
                    blockNumber,
                    canonical.blockHash,
                    extrinsicIndex
                )
            }
        }

        if let inclusion = foundInclusion {
            guard let succeeded = try await authoritativeExecutionResult(
                at: inclusion.blockHash,
                extrinsicIndex: inclusion.extrinsicIndex,
                factory: factory
            ) else {
                // Inclusion without exactly one System terminal event remains
                // ambiguous. Never synthesize an outcome from PI or UI state.
                return
            }
            try Task.checkCancellation()
            try store.resolveAuthoritatively(
                pending,
                proof: .finalizedInclusion(
                    blockNumber: inclusion.blockNumber,
                    blockHash: inclusion.blockHash,
                    succeeded: succeeded,
                    finalizedHeight: finalizedHeight
                )
            )
            return
        }

        guard finalizedHeight >= context.eraDeathBlockExclusive else {
            // A pre-expiry absence is not terminal and remains deletion- and
            // capacity-protected for the next foreground recovery pass.
            return
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

    private func authoritativeExecutionResult(
        at normalizedBlockHash: String,
        extrinsicIndex: UInt32,
        factory: RuntimeCoderFactoryProtocol
    ) async throws -> Bool? {
        guard
            Sora2PendingSubmissionStore.normalizedHash(
                normalizedBlockHash
            ) == normalizedBlockHash
        else {
            throw Sora2PendingRecoveryError.unavailable
        }
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
            engine: engine,
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

/// Gates recovery until both lossless wallet storage and the SORA2 chain
/// registry are ready. Foreground calls before either gate are no-ops.
@MainActor
final class Sora2PendingSubmissionRecoveryRuntime {
    static let shared = Sora2PendingSubmissionRecoveryRuntime()

    private let store: Sora2PendingSubmissionStore?
    private var walletStorageReady = false
    private var chainReady = false
    private var recoveryTask: Task<Void, Never>?
    private var restartRequested = false

    private init() {
        store = try? Sora2PendingSubmissionStore()
    }

    func prepareForWalletStorageMigration() {
        walletStorageReady = false
        chainReady = false
        restartRequested = false
        recoveryTask?.cancel()
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

    func resumePendingAfterProcessStart() {
        guard walletStorageReady, chainReady else {
            return
        }
        guard recoveryTask == nil else {
            restartRequested = true
            return
        }
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
            chainReady = false
            return
        }
        let reconciler = Sora2PendingSubmissionReconciler(
            store: store,
            engine: engine,
            runtimeService: runtimeService
        )
        recoveryTask = Task { [weak self] in
            // Errors remain represented by the protected journal. Never log
            // hashes, addresses, signed bytes, or raw RPC responses here.
            try? await reconciler.reconcileStatusOnly()
            guard let self else {
                return
            }
            self.recoveryTask = nil
            let shouldRestart = self.restartRequested &&
                self.walletStorageReady && self.chainReady
            self.restartRequested = false
            if shouldRestart {
                self.resumePendingAfterProcessStart()
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
    private let pendingSubmissionStore: Sora2PendingSubmissionStore?

    init(address: String,
         cryptoType: CryptoType,
         runtimeRegistry: RuntimeCodingServiceProtocol,
         engine: JSONRPCEngine,
         operationManager: OperationManagerProtocol) {
        self.address = address
        self.cryptoType = cryptoType
        self.runtimeRegistry = runtimeRegistry
        self.engine = Sora2BoundedHTTPJSONRPCEngine.wrapping(engine)
        self.operationManager = operationManager
        pendingSubmissionStore = try? Sora2PendingSubmissionStore()
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

        return ClosureOperation {
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
            let snapshot = try WalletNetworkStore().load()
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
                ) == currentAddress,
                PolkamarktRuntimeContract.matchesReviewedGenesisHash(
                    signingGenesisHash
                ),
                PolkamarktRuntimeContract.matchesReviewedGenesisHash(
                    connectedGenesisHash
                ),
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

            let account = MultiAddress.accoundId(accountId)

            var builder: ExtrinsicBuilderProtocol =
                try ExtrinsicBuilder(specVersion: codingFactory.specVersion,
                                     transactionVersion: codingFactory.txVersion,
                                     genesisHash: signingGenesisHash)
                    .with(address: account)
                    .with(nonce: nonce)
                    .with(era: hashAndEra.era, blockHash: hashAndEra.hash)

            builder = try customClosure(builder)
            let guardedSigningClosure: (Data) throws -> Data = { data in
                // The builder has now encoded the exact signature payload.
                // Validate once, at the last synchronous boundary before the
                // lifecycle signer can read a secret.
                try preSigningValidation?()
                return try signingClosure(data)
            }
            builder = try builder.signing(by: guardedSigningClosure,
                                          of: currentCryptoType,
                                          using: codingFactory.createEncoder(),
                                          metadata: codingFactory.metadata)
            let extrinsic = try builder.buildExtrinsic(metadata: codingFactory.metadata)
            let extrinsicData = try builder.build(encodingBy: codingFactory.createEncoder(), metadata: codingFactory.metadata)
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
    }

    private func createSigningLeaseOperation(
        suppliedLease: WalletLifecycleLease?
    ) -> (
        operation: BaseOperation<WalletLifecycleLease>,
        ownsLease: Bool
    ) {
        let coordinator = WalletLifecycleCoordinator.shared
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
        WalletLifecycleCoordinator.shared
            .enqueueOwnedAcquireOperation(lifecycle.operation)
    }

    private func validateSora2SigningRuntime(
        _ factory: RuntimeCoderFactoryProtocol
    ) throws {
        guard
            factory.specVersion == PolkamarktRuntimeContract.specVersion,
            factory.txVersion ==
                PolkamarktRuntimeContract.transactionVersion
        else {
            throw ExtrinsicServiceError.unsupportedRuntime(
                spec: factory.specVersion,
                transaction: factory.txVersion
            )
        }
        let metadataSHA256 = try PolkamarktRuntimeContract
            .signingMetadataSHA256(for: factory)
        guard PolkamarktRuntimeContract.matchesReviewedSigningIdentity(
            specVersion: factory.specVersion,
            transactionVersion: factory.txVersion,
            metadataSHA256: metadataSHA256
        ) else {
            // Runtime versions are not a metadata identity. Pallet/call
            // indices and types used for the signed bytes must match the
            // reviewed runtime-130 fixture on every SORA2 mutation, not only
            // on the Polkamarkt paths.
            throw ExtrinsicServiceError.unsupportedRuntimeMetadata
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
                                                            try self.validateSora2SigningRuntime(factory)
                                                        },
                                                        signingClosure: signingClosure)
        eraOperation.addDependency(headOperation)
        hashAndEraOperation.addDependency(headOperation)
        hashAndEraOperation.addDependency(eraOperation)
        builderOperation.addDependency(nonceOperation)
        builderOperation.addDependency(genesisOperation)
        builderOperation.addDependency(hashAndEraOperation)
        builderOperation.addDependency(codingFactoryOperation)

        let infoOperation = feeDetailsOperation(queue: queue, builderOperation: builderOperation, completionClosure: completionClosure)

        let operations = [nonceOperation, genesisOperation, headOperation,
                          eraOperation, hashAndEraOperation,
                          codingFactoryOperation, builderOperation, infoOperation]
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
        let lifecycle = createSigningLeaseOperation(
            suppliedLease: lifecycleLease
        )
        lifecycle.operation.addDependency(nonceOperation)
        lifecycle.operation.addDependency(genesisOperation)
        lifecycle.operation.addDependency(hashAndEraOperation)
        lifecycle.operation.addDependency(codingFactoryOperation)

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
                try self.validateSora2SigningRuntime(factory)
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
                try self.validateSora2SigningRuntime(factory)
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
                    try WalletLifecycleCoordinator.shared
                        .tryAcquireForMutableWalletAccess()
            else {
                throw WalletNetworkMigrationError
                    .lifecycleMutationBusy
            }
            acquiredTransportLease = acquired
            try WalletRecoveryCapabilityGate.shared
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
                try WalletRecoveryCapabilityGate.shared
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
                try WalletRecoveryCapabilityGate.shared
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
                        completion(.success(returnedHash))
                    case let .failure(error):
                        if mayHaveEnteredTransport {
                            try? self.pendingSubmissionStore?.update(
                                stagedPendingSubmission,
                                state: .submissionUnknown
                            )
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

        let lifecycle = createSigningLeaseOperation(
            suppliedLease: lifecycleLease
        )
        lifecycle.operation.addDependency(nonceOperation)
        lifecycle.operation.addDependency(genesisOperation)
        lifecycle.operation.addDependency(hashAndEraOperation)
        lifecycle.operation.addDependency(codingFactoryOperation)

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
                try self.validateSora2SigningRuntime(factory)
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
                try WalletRecoveryCapabilityGate.shared
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
                try WalletRecoveryCapabilityGate.shared
                    .requireMutableWalletAccess()
                let extrinsicHex = staged.info.data
                    .toHex(includePrefix: true)

                EventCenter.shared.notify(
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
