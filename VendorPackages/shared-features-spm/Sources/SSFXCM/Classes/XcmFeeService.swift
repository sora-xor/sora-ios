import BigInt
import Foundation
import RobinHood
import SSFModels
import SSFNetwork

// sourcery: AutoMockable
public protocol XcmDestinationFeeFetching {
    func estimateFee(
        destinationChainId: String,
        token: String
    ) async -> Result<DestXcmFee, Error>
    func estimateWeight(
        for chainId: String
    ) async throws -> BigUInt
}

public final class XcmDestinationFeeFetcher: XcmDestinationFeeFetching {
    private let sourceUrl: URL
    private let networkOperationFactory: NetworkOperationFactoryProtocol
    private let operationQueue: OperationQueue
    private let useCache: Bool
    private var fees: [XcmFee]?

    private let defaultWeight: BigUInt = 500_000_000_000

    public init(
        sourceUrl: URL,
        networkOperationFactory: NetworkOperationFactoryProtocol,
        operationQueue: OperationQueue,
        useCache: Bool = true
    ) {
        self.sourceUrl = sourceUrl
        self.networkOperationFactory = networkOperationFactory
        self.operationQueue = operationQueue
        self.useCache = useCache
    }

    public func estimateFee(
        destinationChainId: String,
        token: String
    ) async -> Result<DestXcmFee, Error> {
        let remoteData = await fetchRemoteData()
        let fee = fetchFee(
            from: remoteData,
            destinationChainId: destinationChainId,
            token: token
        )
        return fee
    }

    public func estimateWeight(
        for chainId: String
    ) async throws -> BigUInt {
        let remoteData = await fetchRemoteData()
        switch remoteData {
        case let .success(list):
            guard let xcmFee = list.first(where: {
                $0.chainId == chainId
            }) else {
                return defaultWeight
            }
            return xcmFee.weight
        case let .failure(failure):
            throw failure
        case .none:
            throw XcmError.missingRemoteFeeResult
        }
    }

    // MARK: - Private methods

    private func fetchFee(
        from remoteData: Result<[XcmFee], Error>?,
        destinationChainId: String,
        token: String
    ) -> Result<DestXcmFee, Error> {
        switch remoteData {
        case let .success(feeList):
            guard let xcmFee = feeList.first(where: { $0.chainId == destinationChainId }),
                  let destXcmFee = xcmFee.destXcmFee.first(where: {
                      if $0.symbol.lowercased() == token.lowercased() {
                          return true
                      } else if token.lowercased().hasPrefix("xc") {
                          let modifySymbol = String(token.dropFirst(2)).lowercased()
                          return $0.symbol.lowercased() == modifySymbol.lowercased()
                      }
                      return false
                  }) else
            {
                return .failure(XcmError.noFee(chainId: destinationChainId))
            }

            return .success(destXcmFee)
        case let .failure(error):
            return .failure(error)
        case .none:
            return .failure(XcmError.missingRemoteFeeResult)
        }
    }

    private func fetchRemoteData() async -> Result<[XcmFee], Error>? {
        if let fees = fees, useCache {
            return .success(fees)
        }

        let networkOperation: BaseOperation<[XcmFee]> = networkOperationFactory
            .fetchData(from: sourceUrl)
        operationQueue.addOperation(networkOperation)

        return await withCheckedContinuation { continuation in
            networkOperation.completionBlock = {
                let result = networkOperation.result
                continuation.resume(returning: result)
            }
        }
    }
}
