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

import Foundation
import RobinHood
import SoraKeystore
import SSFUtils
import BigInt
import sorawallet
import IrohaCrypto
import SSFStorageQueryKitFixed

final class FriendsInteractor {
    weak var presenter: FriendsInteractorOutputProtocol?
    private let engine: JSONRPCEngine
    private let config: ApplicationConfigProtocol
    private let operationManager: OperationManager
    private let operationFactory: ReferralsOperationFactoryProtocol
    private let feeProvider: FeeProviderProtocol
    private let rewardsOperation: (String) -> BaseOperation<ReferrerRewardsInfo>
    private let accountId: Data?
    private let address: String
    private var referralBalance = Balance(value: 0)
    private var referrer = ""
    private var subscriptionIds: [UInt16] = []
    private var generation = UUID()
    private var rewardRequest = UUID()

    private final class Load {
        var rewards: ReferrerRewardsInfo?
        var balance = Balance(value: 0)
        var referrer = ""
        var setFee: Decimal = .nan
        var bondFee: Decimal = .nan
        var unbondFee: Decimal = .nan
        var error: Swift.Error?
    }

    init(engine: JSONRPCEngine,
         address: String,
         config: ApplicationConfigProtocol,
         operationManager: OperationManager,
         keychain: KeystoreProtocol,
         operationFactory: ReferralsOperationFactoryProtocol,
         feeProvider: FeeProviderProtocol = FeeProvider(),
         rewardsOperation: @escaping (String) -> BaseOperation<ReferrerRewardsInfo> = { address in
             SubqueryReferralRewardsOperation<ReferrerRewardsInfo>(address: address, baseUrl: ConfigService.shared.config.subqueryURL)
         }) {
        self.engine = engine
        self.config = config
        self.operationManager = operationManager
        self.operationFactory = operationFactory
        self.feeProvider = feeProvider
        self.rewardsOperation = rewardsOperation
        self.address = address
        self.accountId = try? SS58AddressFactory().accountId(fromAddress: address, type: config.addressType)
    }

    deinit { unsubscribeReferrals() }
}

extension FriendsInteractor: FriendsInteractorInputProtocol {
    func setup() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.setup() }
            return
        }
        generation = UUID()
        rewardRequest = UUID()
        let current = generation
        unsubscribeReferrals()
        let group = DispatchGroup()
        let load = Load()
        group.enter()
        getRewards { result in
            defer { group.leave() }
            switch result {
            case .success(let rewards): load.rewards = rewards
            case .failure(let error): load.error = error
            }
        }
        group.enter()
        getReferrerBalances { result in
            defer { group.leave() }
            switch result {
            case .success(let balance): load.balance = balance
            case .failure(let error): load.error = error
            }
        }
        group.enter()
        getMyReferrer { result in
            defer { group.leave() }
            switch result {
            case .success(let referrer): load.referrer = referrer
            case .failure(let error): load.error = error
            }
        }
        group.enter()
        feeProvider.getFee(for: .referral) { fee in
            DispatchQueue.main.async { load.setFee = fee; group.leave() }
        }
        group.enter()
        feeProvider.getFee(for: InputRewardAmountType.bond) { fee in
            DispatchQueue.main.async { load.bondFee = fee; group.leave() }
        }
        group.enter()
        feeProvider.getFee(for: InputRewardAmountType.unbond) { fee in
            DispatchQueue.main.async { load.unbondFee = fee; group.leave() }
        }
        group.notify(queue: .main) { [weak self] in
            guard let self, self.generation == current else { return }
            guard let rewards = load.rewards, load.error == nil,
                  [load.setFee, load.bondFee, load.unbondFee].allSatisfy({ !$0.isNaN && $0 >= 0 }),
                  let balance = Decimal.fromSubstrateAmount(load.balance.value, precision: 18) else {
                self.presenter?.didFailLoading(error: load.error ?? BaseOperationError.unexpectedDependentResult)
                return
            }
            self.referralBalance = load.balance
            self.referrer = load.referrer
            self.presenter?.didReceive(rewards: rewards.rewards, setReferrerFee: load.setFee,
                                       bondFee: load.bondFee, unbondFee: load.unbondFee,
                                       referralBalance: balance, referrer: load.referrer)
            self.subscribeReferrerBalances(generation: current)
            self.subscribeMyReferrer(generation: current)
            self.subscribeReferral(generation: current)
        }
    }
}

private extension FriendsInteractor {
    /// Every read completes once on the main queue, including missing operations
    /// and malformed data. A failed read never becomes a successful empty state.
    func getRewards(completion: @escaping (Result<ReferrerRewardsInfo, Swift.Error>) -> Void) {
        let operation = rewardsOperation(address)
        operation.completionBlock = { [weak operation] in
            let result = Result { () throws -> ReferrerRewardsInfo in
                guard let operation else { throw BaseOperationError.unexpectedDependentResult }
                return try operation.extractResultData(throwing: BaseOperationError.unexpectedDependentResult)
            }
            DispatchQueue.main.async { completion(result) }
        }
        operationManager.enqueue(operations: [operation], in: .transient)
    }

    func getReferrerBalances(completion: @escaping (Result<Balance, Swift.Error>) -> Void) {
        guard let operation = operationFactory.createReferrerBalancesOperation() else {
            DispatchQueue.main.async { completion(.failure(BaseOperationError.unexpectedDependentResult)) }
            return
        }
        operation.completionBlock = { [weak operation] in
            let result = Result { () throws -> Balance in
                guard let operation else { throw BaseOperationError.unexpectedDependentResult }
                return try operation.extractResultData(throwing: BaseOperationError.unexpectedDependentResult).underlyingValue ?? Balance(value: 0)
            }
            DispatchQueue.main.async { completion(result) }
        }
        operationManager.enqueue(operations: [operation], in: .transient)
    }

    func getMyReferrer(completion: @escaping (Result<String, Swift.Error>) -> Void) {
        guard let operation = operationFactory.createReferrerOperation() else {
            DispatchQueue.main.async { completion(.failure(BaseOperationError.unexpectedDependentResult)) }
            return
        }
        let networkType = config.addressType
        operation.completionBlock = { [weak operation] in
            let result = Result { () throws -> String in
                guard let operation else { throw BaseOperationError.unexpectedDependentResult }
                guard let value = try operation.extractResultData(throwing: BaseOperationError.unexpectedDependentResult) else { return "" }
                let accountId = try Data(hexStringSSF: value)
                guard accountId.count == 32 else { throw BaseOperationError.unexpectedDependentResult }
                return try SS58AddressFactory().addressFromAccountId(data: accountId, type: networkType)
            }
            DispatchQueue.main.async { completion(result) }
        }
        operationManager.enqueue(operations: [operation], in: .transient)
    }

    func subscribeReferrerBalances(generation: UUID) {
        guard let accountId,
              let storageKey = try? StorageKeyFactory().referrerBalancesKeyForId(accountId).toHex(includePrefix: true) else { return }
        subscribe(key: storageKey, generation: generation) { [weak self] value in
            guard let self else { return }
            let balance: Balance
            if let value {
                guard let data = try? Data(hexStringSSF: value), data.count == 16,
                      let decoder = try? ScaleDecoder(data: data),
                      let decoded = try? Balance(scaleDecoder: decoder) else { return }
                balance = decoded
            } else { balance = Balance(value: 0) }
            guard balance.value != self.referralBalance.value,
                  let amount = Decimal.fromSubstrateAmount(balance.value, precision: 18) else { return }
            self.referralBalance = balance
            self.presenter?.updateReferral(balance: amount)
        }
    }

    func subscribeMyReferrer(generation: UUID) {
        guard let accountId,
              let storageKey = try? StorageKeyFactory().referrersKeyForId(accountId).toHex(includePrefix: true) else { return }
        subscribe(key: storageKey, generation: generation) { [weak self] value in
            guard let self else { return }
            let address: String
            if let value {
                guard let data = try? Data(hexStringSSF: value), data.count == 32,
                      let decoded = try? SS58AddressFactory().addressFromAccountId(data: data, type: self.config.addressType) else { return }
                address = decoded
            } else { address = "" }
            guard address != self.referrer else { return }
            self.referrer = address
            self.presenter?.updateReferrer(address: address)
        }
    }

    func subscribeReferral(generation: UUID) {
        guard let accountId,
              let storageKey = try? StorageKeyFactory().referrerBalancesKeyForId(accountId).toHex(includePrefix: true) else { return }
        subscribe(key: storageKey, generation: generation) { [weak self] _ in
            guard let self else { return }
            self.rewardRequest = UUID()
            let request = self.rewardRequest
            self.getRewards { [weak self] result in
                guard let self, self.generation == generation, self.rewardRequest == request else { return }
                switch result {
                case .success(let rewards): self.presenter?.updateReferral(rewards: rewards.rewards)
                case .failure(let error): self.presenter?.didFailLoading(error: error)
                }
            }
        }
    }

    func subscribe(key: String, generation: UUID, receive: @escaping (String?) -> Void) {
        do {
            let update: (JSONRPCSubscriptionUpdate<StorageUpdate>) -> Void = { [weak self] update in
                guard let change = update.params.result.changes?.first(where: { $0.first == key }), change.count == 2 else { return }
                let value = change[1]
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.generation == generation else { return }
                    receive(value)
                }
            }
            let id = try engine.subscribe(RPCMethod.storageSubscribe, params: [[key]], updateClosure: update,
                                          failureClosure: { error, _ in Logger.shared.error("Referral subscription failed: \(error)") })
            subscriptionIds.append(id)
        } catch {
            Logger.shared.error("Referral subscription unavailable: \(error)")
        }
    }

    func unsubscribeReferrals() {
        subscriptionIds.forEach { engine.cancelForIdentifier($0) }
        subscriptionIds.removeAll()
    }
}
