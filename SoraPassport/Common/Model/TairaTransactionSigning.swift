// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import BigInt
import Foundation
import NexusTransferCodec

/// Taira's current protocol is encoded locally. Only public transaction data
/// and signatures leave the wallet; key access uses the existing identity-
/// checked, scoped wallet signing provider.
actor TairaTransactionSigner: NexusTransactionSigning {
    private let client: TairaClient
    private var cached: [(request: NexusTransferRequest, draft: TairaClient.Draft, quote: TairaClient.Quote?)] = []

    init(client: TairaClient = TairaClient()) { self.client = client }

    nonisolated func isQualified(for configuration: NexusNetworkConfiguration) -> Bool {
        configuration.networkId == .taira && configuration.isLive && configuration.satisfiesCurrentTairaContract
    }

    func quoteTransfer(_ request: NexusTransferRequest, assetDefinitionID: String,
                       configuration: NexusNetworkConfiguration) async throws -> NexusTransferFeeQuote {
        guard isQualified(for: configuration), request.networkId == .taira,
              assetDefinitionID == TairaClient.xorDefinition else { throw NexusToriiError.wrongWalletOrNetwork }
        let sender = try IrohaAddressCodec.parse(request.sender, expectedDiscriminant: configuration.i105Discriminant)
        let receiver = try IrohaAddressCodec.parse(request.receiver, expectedDiscriminant: configuration.i105Discriminant)
        let publicKey = try Data(hex: sender.publicKeyHex)
        let context = IrohaConnectWalletContext(walletId: request.walletId, networkId: request.networkId,
                                              accountId: request.sender, publicKey: publicKey)
        cached.removeAll { (try? $0.draft.requireFresh()) == nil }
        let draft: TairaClient.Draft
        if let prior = cached.first(where: { $0.request == request }) {
            draft = prior.draft
        } else {
            draft = try TairaClient.Draft(authority: request.sender,
                authorityHeader: sender.canonicalHex.hasPrefix("0x") ? sender.canonicalHex : "0x" + sender.canonicalHex,
                authorityKey: publicKey, recipientKey: Data(hex: receiver.publicKeyHex), amount: request.amount.rawValue)
            if cached.count >= 8 { cached.removeFirst() }
            cached.append((request, draft, nil))
        }
        let provider = try IrohaConnectWalletProvider()
        let result = try await client.quote(draft) { try provider.sign($0, context: context) }
        guard let index = cached.firstIndex(where: { $0.request == request && $0.draft.createdAt == draft.createdAt && $0.draft.nonce == draft.nonce }) else {
            throw NexusToriiError.quoteChanged
        }
        cached[index].quote = result
        return try quoteModel(result, request: request, asset: assetDefinitionID)
    }

    func signTransfer(_ request: NexusTransferRequest, assetDefinitionID: String, quote: NexusTransferFeeQuote,
                      configuration: NexusNetworkConfiguration) async throws -> NexusSignedTransaction {
        guard isQualified(for: configuration), assetDefinitionID == TairaClient.xorDefinition,
              let entry = cached.first(where: { $0.request == request }), let result = entry.quote,
              try quoteModel(result, request: request, asset: assetDefinitionID) == quote else {
            throw NexusToriiError.quoteChanged
        }
        try entry.draft.requireFresh()
        let provider = try IrohaConnectWalletProvider()
        let context = IrohaConnectWalletContext(walletId: request.walletId, networkId: request.networkId,
            accountId: request.sender, publicKey: entry.draft.authorityKey)
        let signature = try provider.sign(NexusTransferCodec.signingMessage(result.payload), context: context)
        let signed = try NexusTransferCodec.envelope(payload: result.payload, signature: signature, publicKey: entry.draft.authorityKey)
        cached.removeAll { $0.request == request }
        return NexusSignedTransaction(payload: signed, pipelineHash: NexusTransferCodec.transactionHash(result.payload).map { String(format: "%02x", $0) }.joined())
    }

    private func quoteModel(_ result: TairaClient.Quote, request: NexusTransferRequest, asset: String) throws -> NexusTransferFeeQuote {
        var units = BigInt(0)
        for maximum in result.maxima {
            guard let decimal = NexusExactDecimal(maximum), decimal.unscaled >= 0, decimal.scale <= 9 else { throw NexusToriiError.invalidResponse }
            units += decimal.unscaled * BigInt(10).power(9 - decimal.scale)
        }
        let digits = String(units)
        let padded = String(repeating: "0", count: max(0, 10 - digits.count)) + digits
        let cut = padded.index(padded.endIndex, offsetBy: -9)
        var total = String(padded[..<cut]) + "." + String(padded[cut...])
        while total.last == "0" { total.removeLast() }
        if total.last == "." { total.removeLast() }
        return NexusTransferFeeQuote(networkId: .taira, authority: request.sender, receiver: request.receiver,
            assetDefinitionId: asset, amount: request.amount, fee: try PIQuantity(total),
            quoteIdentity: result.identity, validUntilBlock: nil)
    }
}

/// HTTPS Torii confirmation policy for the public testnet. This reader binds
/// the response to Taira's genesis and a fresh challenge; it does not claim
/// independent cryptographic consensus verification or enable production.
struct TairaToriiConfirmationReader: NexusFinalityReading {
    let client: TairaClient
    init(client: TairaClient = TairaClient()) { self.client = client }
    func isQualified(for configuration: NexusNetworkConfiguration) -> Bool {
        configuration.networkId == .taira && configuration.isLive && configuration.satisfiesCurrentTairaContract
    }
    func finalizedCheckpoint(for configuration: NexusNetworkConfiguration) async throws -> NexusFinalityCheckpoint {
        guard isQualified(for: configuration) else { throw NexusToriiError.finalizedHeadUnavailable }
        let checkpoint = try await client.checkpoint()
        return NexusFinalityCheckpoint(networkId: .taira, chainId: configuration.chainId,
            finalizedBlockHeight: checkpoint.height, finalizedBlockHash: checkpoint.hash)
    }
}
