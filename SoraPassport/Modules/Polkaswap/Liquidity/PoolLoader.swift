/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

protocol PoolLoaderProtocol {
    var state: PoolState { get }
    var poolDetails: PoolDetails? { get }
    var delegate: PoolLoaderDelegate? { get set }

    func setInitialPool(_ poolDetails: PoolDetails)
    func getPoolState()
    func didLoadPoolDetails(_ poolDetails: PoolDetails?, baseAsset: String, targetAsset: String)
    func didCheckIsPairExists(_ isExist: Bool, baseAsset: String, targetAsset: String)
}

protocol PoolLoaderDelegate: AnyObject {
    func loadPoolDetails(baseAsset: String, targetAsset: String)
    //TODO: base asset
    func checkIsPairExists(baseAsset: String, targetAsset: String)
    func didGetPoolState(_: PoolState, poolDetails: PoolDetails?)
}

enum PoolState {
    case unknown
    case addToExistingPool
    case addToExistingPoolFirstTime
    case createNewPair
}

class PoolLoader: PoolLoaderProtocol {
    var baseAsset: AssetInfo
    var toAsset: AssetInfo
    var activePoolsList: [PoolDetails]
    var state: PoolState = .unknown
    var poolDetails: PoolDetails?
    weak var delegate: PoolLoaderDelegate?

    init(baseAsset: AssetInfo, toAsset: AssetInfo, activePoolsList: [PoolDetails], poolDetails: PoolDetails? = nil) {
        self.baseAsset = baseAsset
        self.toAsset = toAsset
        self.activePoolsList = activePoolsList
        self.poolDetails = poolDetails
    }

    func setInitialPool(_ poolDetails: PoolDetails) {
        updateAndNotify(state: .addToExistingPool, poolDetails: poolDetails)
    }

    func getPoolState() {
        checkIfUserHasLiquidityInPool()
    }

    private func checkIfUserHasLiquidityInPool() {
        poolDetails = userPoolDetails(baseAsset: baseAsset.identifier, targetAsset: toAsset.identifier)
        if poolDetails != nil {
            updateAndNotify(state: .addToExistingPool, poolDetails: poolDetails)
        } else {
            getPoolDetails()
        }
    }

    private func userPoolDetails(baseAsset: String, targetAsset: String) -> PoolDetails? {
        activePoolsList.first(where: { $0.baseAsset == baseAsset && $0.targetAsset == targetAsset })
    }

    private func getPoolDetails() {
        delegate?.loadPoolDetails(baseAsset: baseAsset.identifier, targetAsset: toAsset.identifier)
    }

    func didLoadPoolDetails(_ poolDetails: PoolDetails?, baseAsset: String, targetAsset: String) {
        guard baseAsset == self.baseAsset.identifier, targetAsset == toAsset.identifier else {
            updateAndNotify(state: .unknown, poolDetails: nil)
            return
        }

        if poolDetails != nil {
            updateAndNotify(state: .addToExistingPool, poolDetails: poolDetails)
        } else {
            checkIfPairExists()
        }
    }

    private func checkIfPairExists() {
        delegate?.checkIsPairExists(baseAsset: baseAsset.identifier, targetAsset: toAsset.identifier)
    }

    func didCheckIsPairExists(_ isExist: Bool, baseAsset: String, targetAsset: String) {
        guard baseAsset == self.baseAsset.identifier, targetAsset == toAsset.identifier else {
            updateAndNotify(state: .unknown, poolDetails: nil)
            return
        }

        if isExist {
            updateAndNotify(state: .addToExistingPoolFirstTime, poolDetails: nil)
        } else {
            updateAndNotify(state: .createNewPair, poolDetails: nil)
        }
    }

    private func updateAndNotify(state: PoolState, poolDetails: PoolDetails?) {
        self.state = state
        self.poolDetails = poolDetails
        delegate?.didGetPoolState(state, poolDetails: poolDetails)
    }
}
