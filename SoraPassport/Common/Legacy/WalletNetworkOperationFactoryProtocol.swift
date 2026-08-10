//
//  WalletNetworkOperationFactoryProtocol.swift
//  SoraPassport
//
//  Created by Ivan Shlyapkin on 3/12/24.
//  Copyright © 2024 Soramitsu. All rights reserved.
//

import Foundation
import RobinHood

/// Exact-fee and balance predicates shared by the ordinary SORA2 send UI and
/// its prepared-submission path. A reviewed fee is an exact authorization, not
/// a ceiling: any byte-qualified change requires a fresh confirmation.
enum Sora2TransferFeeQualification {
    static func requireExact(
        reviewedFee: Decimal,
        signedBytesFee: Decimal
    ) throws -> Decimal {
        guard reviewedFee > 0,
              signedBytesFee > 0,
              reviewedFee == signedBytesFee else {
            throw WalletNetworkOperationFactoryError.invalidFee
        }
        return signedBytesFee
    }

    static func requireSufficientBalances(
        amount: Decimal,
        assetId: String,
        exactFee: Decimal,
        balances: [BalanceData]
    ) throws {
        let identifiers = balances.map(\.identifier)
        guard amount > 0,
              exactFee > 0,
              Set(identifiers).count == identifiers.count,
              balances.allSatisfy({ $0.balance.decimalValue >= 0 }) else {
            throw WalletNetworkOperationFactoryError.invalidContext
        }

        let balancesByAsset = Dictionary(uniqueKeysWithValues: balances.map {
            ($0.identifier, $0.balance.decimalValue)
        })
        var requiredByAsset: [String: Decimal] = [assetId: amount]
        requiredByAsset[WalletAssetId.xor.rawValue, default: .zero] += exactFee
        for requiredAssetId in requiredByAsset.keys.sorted() {
            guard let required = requiredByAsset[requiredAssetId],
                  required > 0,
                  let available = balancesByAsset[requiredAssetId],
                  available >= required else {
                throw WalletNetworkOperationFactoryError.insufficientBalance
            }
        }
    }
}

/// Ordinary outgoing transfers may use only the prepared, exact-fee API below.
/// The retained generic mutation API still serves non-transfer product flows,
/// but must fail closed if any caller tries to route an ordinary send through it.
enum Sora2LegacyTransferAdmission {
    static func requirePreparedPath(for type: TransactionType) throws {
        guard type != .outgoing else {
            throw WalletNetworkOperationFactoryError.invalidContext
        }
    }
}

/// Owns one exact, already-signed ordinary SORA2 transfer and the fee returned
/// for those same bytes. The payload remains one-shot and opaque to the UI.
public final class PreparedSora2TransferSubmission {
    public let fee: Decimal
    public let transactionHash: String

    let rawFee: String
    let preparedExtrinsic: PreparedExtrinsicSubmission

    init(
        fee: Decimal,
        rawFee: String,
        preparedExtrinsic: PreparedExtrinsicSubmission
    ) {
        self.fee = fee
        self.rawFee = rawFee
        transactionHash = preparedExtrinsic.hash
        self.preparedExtrinsic = preparedExtrinsic
    }

    public func discard() {
        preparedExtrinsic.discard()
    }

    deinit {
        discard()
    }
}

/// Owns one exact, already-signed liquidity extrinsic and its fee qualification.
/// The signed bytes are one-shot and remain opaque outside the network layer.
public final class PreparedLiquiditySubmission {
    public let fee: Decimal
    public let transactionHash: String

    let rawFee: String
    let preparedExtrinsic: PreparedExtrinsicSubmission

    init(
        fee: Decimal,
        rawFee: String,
        preparedExtrinsic: PreparedExtrinsicSubmission
    ) {
        self.fee = fee
        self.rawFee = rawFee
        transactionHash = preparedExtrinsic.hash
        self.preparedExtrinsic = preparedExtrinsic
    }

    public func discard() {
        preparedExtrinsic.discard()
    }

    deinit {
        discard()
    }
}

public protocol WalletNetworkOperationFactoryProtocol {
    func fetchBalanceOperation(_ assets: [String]) -> CompoundOperationWrapper<[BalanceData]?>

    func fetchTransactionHistoryOperation(_ filter: WalletHistoryRequest,
                                          pagination: Pagination)
        -> CompoundOperationWrapper<AssetTransactionPageData?>

    func transferMetadataOperation(_ info: TransferMetadataInfo) -> CompoundOperationWrapper<TransferMetaData?>
    func transferOperation(_ info: TransferInfo) -> CompoundOperationWrapper<Data>
    /// Estimates the ordinary transfer encoded by `info`, including its actual
    /// asset, destination, and amount. Sample/fixed transfer calls are invalid.
    func estimateTransferFee(for info: TransferInfo) async throws -> Decimal
    /// Builds and signs the exact transfer once and obtains the fee for those
    /// exact bytes after a final synchronous authorization check.
    func prepareTransferSubmission(
        for info: TransferInfo,
        preSigningValidation: @escaping () throws -> Void
    ) async throws -> PreparedSora2TransferSubmission
    /// Re-queries the exact signed bytes immediately before one-shot transport
    /// and rejects any fee drift from the reviewed/prepared raw fee.
    func submitPreparedTransfer(
        _ submission: PreparedSora2TransferSubmission,
        info: TransferInfo,
        preTransportValidation: @escaping () throws -> Void
    ) async throws -> Data
    /// Estimates the exact liquidity call encoded by `info`. Implementations
    /// must throw rather than return a zero or sample fee when qualification
    /// cannot be completed.
    func estimateLiquidityFee(for info: TransferInfo) async throws -> Decimal
    /// Builds and signs the exact liquidity call once, validates runtime 130,
    /// and obtains the fee for those same signed bytes. Cancellation or a
    /// revoked UI authorization must stop a queued signer before secret use.
    func prepareLiquiditySubmission(
        for info: TransferInfo,
        preSigningValidation: @escaping () throws -> Void
    ) async throws -> PreparedLiquiditySubmission
    /// Persists the exact pending call before transport and submits the
    /// one-shot signed bytes without rebuilding or signing again.
    func submitPreparedLiquidity(
        _ submission: PreparedLiquiditySubmission,
        info: TransferInfo,
        preTransportValidation: @escaping () throws -> Void
    ) async throws -> Data
    func searchOperation(_ searchString: String) -> CompoundOperationWrapper<[SearchData]?>
    func contactsOperation() -> CompoundOperationWrapper<[SearchData]?>

    func withdrawalMetadataOperation(_ info: WithdrawMetadataInfo)
        -> CompoundOperationWrapper<WithdrawMetaData?>

    func withdrawOperation(_ info: WithdrawInfo) -> CompoundOperationWrapper<Data>
}
