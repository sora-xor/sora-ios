import Foundation

enum PoolsOperationServiceError: Error {
    case unexpectedError
}

struct PooledAssetInfo {
    let id: String
    let precision: Int16
}

struct SupplyLiquidityInfo {
    let dexId: String
    let baseAsset: PooledAssetInfo
    let targetAsset: PooledAssetInfo
    let baseAssetAmount: Decimal
    let targetAssetAmount: Decimal
    let slippage: Decimal
    
    var amountMinA: Decimal {
        baseAssetAmount * (Decimal(1) - slippage / 100)
    }
    
    var amountMinB: Decimal {
        targetAssetAmount * (Decimal(1) - slippage / 100)
    }
}

struct RemoveLiquidityInfo {
    let dexId: String
    let baseAsset: PooledAssetInfo
    let targetAsset: PooledAssetInfo
    let baseAssetAmount: Decimal
    let targetAssetAmount: Decimal
    let baseAssetReserves: Decimal
    let totalIssuances: Decimal
    let slippage: Decimal
    
    var amountMinA: Decimal {
        baseAssetAmount - baseAssetAmount / Decimal(100) * slippage
    }
    
    var amountMinB: Decimal {
        targetAssetAmount - targetAssetAmount / Decimal(100) * slippage
    }
    
    var assetDesired: Decimal {
        baseAssetAmount / baseAssetReserves * totalIssuances
    }
}

enum PoolOperation {
    case substrateSupplyLiquidity(SupplyLiquidityInfo)
    case substrateRemoveLiquidity(RemoveLiquidityInfo)
}

protocol PoolsOperationService {
    func submit(liquidityOperation: PoolOperation) async throws -> String
    func estimateFee(liquidityOperation: PoolOperation) async throws -> String
}

final class PolkaswapPoolOperationService {
    
    private let extrisicService: ExtrinsicServiceProtocol
    private let signingWrapper: SigningWrapperProtocol
    private let poolService: PoolsService
    private let extrinsicBuilder: PoolsExtrinsicBuilder
    
    init(
        extrinsicBuilder: PoolsExtrinsicBuilder,
        extrisicService: ExtrinsicServiceProtocol,
        signingWrapper: SigningWrapperProtocol,
        poolService: PoolsService
    ) {
        self.extrinsicBuilder = extrinsicBuilder
        self.extrisicService = extrisicService
        self.signingWrapper = signingWrapper
        self.poolService = poolService
    }
}

extension PolkaswapPoolOperationService: PoolsOperationService {
    func submit(liquidityOperation: PoolOperation) async throws -> String {
        switch liquidityOperation {
        case .substrateSupplyLiquidity(let model):
            return try await submitSupplyLiquidity(model: model)
        case .substrateRemoveLiquidity(let model):
            return try await submitRemoveLiquidity(model: model)
        }
    }
    
    func estimateFee(liquidityOperation: PoolOperation) async throws -> String {
        switch liquidityOperation {
        case .substrateSupplyLiquidity(let model):
            return try await estimateFeeSupplyLiquidity(model: model)
        case .substrateRemoveLiquidity(let model):
            return try await estimateFeeRemoveLiquidity(model: model)
        }
    }
    
    func submitSupplyLiquidity(model: SupplyLiquidityInfo) async throws -> String {
        let pairs = try await poolService.getAllPairs()

        let closure = try extrinsicBuilder.depositLiqudityExtrinsic(
            pairs: pairs,
            model: model
        )
        
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self else {
                continuation.resume(throwing: PoolsOperationServiceError.unexpectedError)
                return
            }

            self.extrisicService.submit(
                closure,
                signer: self.signingWrapper,
                watch: false,
                runningIn: .global(),
                completion: { result, extrinsicHash, extrinsic in
                    switch result {
                    case .success(let hash):
                        continuation.resume(returning: hash)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            )
        }
    }
    
    func submitRemoveLiquidity(model: RemoveLiquidityInfo) async throws -> String {
        let closure = try extrinsicBuilder.removeLiqudityExtrinsic(model: model)
        
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self else {
                continuation.resume(throwing: PoolsOperationServiceError.unexpectedError)
                return
            }

            self.extrisicService.submit(
                closure,
                signer: self.signingWrapper,
                watch: false,
                runningIn: .global(),
                completion: { result, extrinsicHash, extrinsic in
                    switch result {
                    case .success(let hash):
                        continuation.resume(returning: hash)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            )
        }
    }
    
    func estimateFeeSupplyLiquidity(model: SupplyLiquidityInfo) async throws -> String {
        let pairs = try await poolService.getAllPairs()

        let closure = try extrinsicBuilder.depositLiqudityExtrinsic(
            pairs: pairs,
            model: model
        )
        
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self else {
                continuation.resume(throwing: PoolsOperationServiceError.unexpectedError)
                return
            }

            self.extrisicService.estimateFee(
                closure,
                runningIn: .global(),
                completion: { result in
                    switch result {
                    case .success(let fee):
                        continuation.resume(returning: fee)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            )
        }
    }
    
    func estimateFeeRemoveLiquidity(model: RemoveLiquidityInfo) async throws -> String {
        let closure = try extrinsicBuilder.removeLiqudityExtrinsic(model: model)
        
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self else {
                continuation.resume(throwing: PoolsOperationServiceError.unexpectedError)
                return
            }

            self.extrisicService.estimateFee(
                closure,
                runningIn: .global(),
                completion: { result in
                    switch result {
                    case .success(let fee):
                        continuation.resume(returning: fee)
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            )
        }
    }
}
