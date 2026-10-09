// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import BigInt
import Foundation
import IrohaCrypto
import RobinHood
import Security
import SSFModels
import SSFUtils
import XCTest
@testable import SoraPassport

/// LIVE NETWORK TEST: talks to SORA2 mainnet. It is excluded from default
/// runs and from CI. It runs only when the test runner environment sets
/// `SORA_LIVE_NETWORK_TESTS=1`, for example:
///
///     TEST_RUNNER_SORA_LIVE_NETWORK_TESTS=1 xcodebuild test ... \
///       -only-testing:SoraPassportTests/Sora2MainnetLiveSigningTests
///
/// It proves that the app's runtime admission, snapshot (bundled SORA2 type
/// registry), live-runtime validation, extrinsic assembly and sr25519 signing
/// produce a transaction that the live mainnet runtime accepts as correctly
/// encoded and signed. It uses a throwaway random key that is generated in
/// memory and never stored; it never reads or touches a user key. The key has
/// no XOR, so the node must reject the transfer only because the account
/// cannot pay the fee (error 1010, "Inability to pay some fees"). Any other
/// rejection (bad signature, bad proof, stale or future transaction, invalid
/// call) fails the test.
final class Sora2MainnetLiveSigningTests: XCTestCase {
    private static let node = URL(string: "wss://ws.mof.sora.org")!
    private static let xorAssetId =
        "0x0200000000000000000000000000000000000000000000000000000000000000"

    private final class FixedRuntimeService: SoraPassport.RuntimeCodingServiceProtocol {
        let factory: RuntimeCoderFactoryProtocol

        init(factory: RuntimeCoderFactoryProtocol) {
            self.factory = factory
        }

        func fetchCoderFactoryOperation(
            with _: TimeInterval,
            closure _: SoraPassport.RuntimeMetadataClosure?
        ) -> BaseOperation<RuntimeCoderFactoryProtocol> {
            let factory = self.factory
            return ClosureOperation { factory }
        }
    }

    private struct QueryInfo: Decodable {
        let partialFee: String
        let dispatchClass: String

        private enum CodingKeys: String, CodingKey {
            case partialFee
            case dispatchClass = "class"
        }
    }

    private struct NodeError: Decodable {
        let code: Int
        let message: String
        let data: String?
    }

    private struct NodeResponse: Decodable {
        let result: String?
        let error: NodeError?
    }

    /// Signs with the app's own sr25519 implementation
    /// (`SigningWrapperProtocol.signSr25519`).
    private final class ThrowawaySigner: SigningWrapperProtocol {
        init(secretKey: Data, publicKey: Data) {
            self.secretKey = secretKey
            self.publicKey = publicKey
        }

        let secretKey: Data
        let publicKey: Data

        func sign(_ originalData: Data) throws -> IRSignatureProtocol {
            try signSr25519(
                originalData,
                secretKeyData: secretKey,
                publicKeyData: publicKey
            )
        }
    }

    func testThrowawayAccountSignsTransferForTheLiveMainnetRuntime()
        async throws
    {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["SORA_LIVE_NETWORK_TESTS"] == "1",
            "Live-network test. Set TEST_RUNNER_SORA_LIVE_NETWORK_TESTS=1 to run it."
        )

        let source = WebSocketEngine(
            connectionName: nil,
            url: Self.node,
            reachabilityManager: nil,
            reconnectionStrategy: nil,
            autoconnect: false
        )
        // The same bounded HTTPS transport the app uses for every SORA2
        // mutation and status request.
        let engine = Sora2BoundedHTTPJSONRPCEngine(sourceEngine: source)
        let rpc = PolkamarktRPCClient(engine: engine)

        // 1. Chain identity: block zero must be the pinned SORA2 genesis.
        let genesis = try await rpc.reviewedGenesisHash()
        XCTAssertEqual(genesis, PIIndexerClient.soraMainnetGenesis)

        // 2. The live runtime at the finalized head, and its metadata.
        let finalizedHash = try await rpc.finalizedHead()
        let header = try await rpc.header(at: finalizedHash)
        let version = try await rpc.runtimeVersion(at: finalizedHash)
        let metadataHex = try await rpc.metadataHex(at: finalizedHash)
        let live = try Sora2LiveRuntimeValidator.liveRuntime(
            version: version,
            metadataHex: metadataHex
        )
        XCTAssertGreaterThanOrEqual(
            live.specVersion,
            Sora2RuntimeIdentity.minimumSpecVersion
        )

        // 3. App admission and snapshot with the bundled SORA2 type registry,
        //    then the app's live-runtime check (versions + metadata hash).
        let snapshot = try RuntimeSnapshotFactory.makeOwnTypesSnapshot(
            chainId: genesis,
            runtimeMetadataItem: SoraPassport.RuntimeMetadataItem(
                chain: genesis,
                version: version.specVersion,
                txVersion: version.transactionVersion,
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
        try Sora2LiveRuntimeValidator.validate(factory: factory, live: live)

        // 3b. The extrinsic service's own live-runtime operations (the ones
        //     every fee estimate, prepare and submit depends on) agree. The
        //     first run downloads and proves the node's metadata (a fresh,
        //     in-memory proof cache); the second uses the stored proof.
        let proofs = Sora2LiveRuntimeIdentityCache()
        let service = ExtrinsicService(
            address: try SS58AddressFactory().address(
                fromAccountId: Data(repeating: 0x42, count: 32),
                type: Chain.sora.addressType()
            ),
            cryptoType: .sr25519,
            runtimeRegistry: FixedRuntimeService(factory: factory),
            engine: source,
            operationManager: OperationManager(),
            liveRuntimeIdentityCache: proofs
        )
        XCTAssertNil(proofs.metadataSHA256(
            specVersion: live.specVersion,
            transactionVersion: live.transactionVersion
        ))
        for _ in 0 ..< 2 {
            let operations = service.createLiveRuntimeOperations()
            OperationQueue().addOperations(
                operations.all,
                waitUntilFinished: true
            )
            guard case let .success(serviceLive) = operations.identity.result else {
                return XCTFail("Live runtime operations failed: \(String(describing: operations.identity.result))")
            }
            XCTAssertEqual(serviceLive, live)
            XCTAssertNoThrow(
                try service.validateLiveSora2SigningRuntime(
                    factory,
                    live: operations
                )
            )
        }

        // 4. Throwaway key, generated in memory only.
        var seed = Data(count: 32)
        let status = seed.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, 32, $0.baseAddress!)
        }
        XCTAssertEqual(status, errSecSuccess)
        // The same sr25519 key factory the app uses for SORA2 accounts.
        let keypair = try SNKeyFactory().createKeypair(fromSeed: seed)
        seed.resetBytes(in: 0 ..< seed.count)
        let publicKey = keypair.publicKey().rawData()
        let signer = ThrowawaySigner(
            secretKey: keypair.privateKey().rawData(),
            publicKey: publicKey
        )
        let address = try SS58AddressFactory().address(
            fromAccountId: publicKey,
            type: Chain.sora.addressType()
        )

        // 5. Nonce, mortal era from the finalized head, self-transfer of
        //    1 planck XOR, assembled and signed by the app's code.
        let nonce: UInt32 = try call(
            engine,
            SoraPassport.RPCMethod.getExtrinsicNonce,
            [address]
        )
        let numberHex = header.number.hasPrefix("0x")
            ? String(header.number.dropFirst(2))
            : header.number
        let blockNumber = try XCTUnwrap(UInt64(numberHex, radix: 16))
        let era = Era(
            blockNumber: blockNumber,
            eraLength: UInt64(Sora2SubmissionRecoveryContext.reviewedEraPeriod)
        )
        let (extrinsicData, _) = try ExtrinsicService.assembleSignedExtrinsic(
            codingFactory: factory,
            genesisHash: genesis,
            accountId: publicKey,
            nonce: nonce,
            era: era,
            eraBlockHash: finalizedHash,
            cryptoType: .sr25519,
            customClosure: { builder in
                try builder.adding(
                    call: try SubstrateCallFactory().transfer(
                        to: publicKey.toHex(includePrefix: true),
                        asset: Self.xorAssetId,
                        amount: BigUInt(1)
                    )
                )
            },
            signingClosure: { payload in
                try signer.sign(payload).rawData()
            }
        )
        let extrinsicHex = extrinsicData.toHex(includePrefix: true)

        // 6. Fee queries decode (payment_queryInfo, and the
        //    payment_queryFeeDetails model the app uses for its fee display).
        let info: QueryInfo = try call(
            engine,
            SoraPassport.RPCMethod.paymentInfo,
            [extrinsicHex]
        )
        let partialFee = try XCTUnwrap(BigUInt(info.partialFee))
        XCTAssertGreaterThan(partialFee, 0)
        let details: InclusionFeeInfo = try call(
            engine,
            SoraPassport.RPCMethod.feeDetails,
            [extrinsicHex]
        )
        XCTAssertGreaterThan(try XCTUnwrap(BigUInt(details.fee)), 0)

        // 7. Submission. A raw JSON-RPC call is used here only so the node's
        //    error code and reason survive (the app's bounded transport
        //    deliberately hides remote error text).
        let response = try await submitRaw(extrinsicHex)
        XCTAssertNil(response.result, "A zero-balance account must not submit")
        let error = try XCTUnwrap(response.error)
        let reason = error.data ?? ""
        print(
            "SoraLiveSigning spec=\(live.specVersion) tx=\(live.transactionVersion) " +
                "metadataSHA256=\(live.metadataSHA256) finalized=\(blockNumber) " +
                "partialFee=\(partialFee) inclusionFee=\(details.fee) " +
                "submit=\(error.code) \(error.message): \(reason)"
        )
        XCTAssertEqual(error.code, 1010, "\(error.message) \(reason)")
        XCTAssertTrue(
            reason.contains("Inability to pay some fees"),
            "Rejected for another reason: \(error.message) \(reason)"
        )
        for unexpected in ["BadProof", "bad signature", "Stale", "Future", "BadMandatory", "Call"] {
            XCTAssertFalse(
                reason.localizedCaseInsensitiveContains(unexpected),
                reason
            )
        }
    }

    /// Runs one request on the given engine. `JSONRPCOperation.main` waits
    /// for the response (bounded by `timeout`), so this blocks the caller.
    private func call<Value: Decodable>(
        _ engine: JSONRPCEngine,
        _ method: String,
        _ parameters: [String]
    ) throws -> Value {
        let operation = JSONRPCListOperation<Value>(
            engine: engine,
            method: method,
            parameters: parameters,
            timeout: 60
        )
        operation.start()
        switch operation.result {
        case let .success(value):
            return value
        case let .failure(error):
            throw error
        case .none:
            throw JSONRPCEngineError.clientCancelled
        }
    }

    private func submitRaw(_ extrinsicHex: String) async throws -> NodeResponse {
        var request = URLRequest(
            url: try Sora2BoundedHTTPJSONRPCEngine.httpEndpoint(for: Self.node)
        )
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "jsonrpc": "2.0",
            "id": 1,
            "method": SoraPassport.RPCMethod.submitExtrinsic,
            "params": [extrinsicHex]
        ])
        let (data, _) = try await URLSession(
            configuration: .ephemeral
        ).data(for: request)
        return try JSONDecoder().decode(NodeResponse.self, from: data)
    }
}
