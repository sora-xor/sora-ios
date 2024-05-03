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
import SSFStorageQueryKit

final class FriendsInteractor {
    weak var presenter: FriendsInteractorOutputProtocol?

    private let engine: JSONRPCEngine
    private let config: ApplicationConfigProtocol
    private let operationManager: OperationManager
    private let keychain: KeystoreProtocol
    private let operationFactory: ReferralsOperationFactoryProtocol
    private lazy var addressFactory = SS58AddressFactory()
    private let accountId: Data?
    private let address: String

    private let group = DispatchGroup()
    private var setReferrerFee: Decimal = Decimal(0)
    private var bondFee: Decimal = Decimal(0)
    private var unbondFee: Decimal = Decimal(0)
    private var rewardData: ReferrerRewardsInfo?
    private var referralBalance: Balance = Balance.init(value: 0)
    private var referrer: String = ""
    private var subscriptionIds: [UInt16] = []
    private var feeProvider: FeeProviderProtocol

    init(engine: JSONRPCEngine,
         address: String,
         config: ApplicationConfigProtocol,
         operationManager: OperationManager,
         keychain: KeystoreProtocol,
         operationFactory: ReferralsOperationFactoryProtocol) {
        self.engine = engine
        self.config = config
        self.operationManager = operationManager
        self.keychain = keychain
        self.operationFactory = operationFactory
        self.feeProvider = FeeProvider()
        self.address = address
        self.accountId = try? SS58AddressFactory().accountId(fromAddress: address,
                                                             type: ApplicationConfig.shared.addressType)
    }

    deinit {
        unsubscribeReferrals()
    }
}

extension FriendsInteractor: FriendsInteractorInputProtocol {
    func setup() {
        group.enter()
        getRewards { [weak self] in
            self?.group.leave()
        }

        group.enter()
        getReferrerBalances { [weak self] in
            self?.group.leave()
        }

        group.enter()
        getMyReferrer { [weak self] in
            self?.group.leave()
        }

        group.enter()
        getExtrinsicFee { [weak self] in
            self?.getFee(with: .bond) { [weak self] in
                self?.getFee(with: .unbond) { [weak self] in
                    self?.group.leave()
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self, let rewardData = self.rewardData else { return }

            let referralBalance = Decimal.fromSubstrateAmount(self.referralBalance.value, precision: 18) ?? Decimal(0)

            self.presenter?.didReceive(rewards: rewardData.rewards,
                                       setReferrerFee: self.setReferrerFee,
                                       bondFee: self.bondFee,
                                       unbondFee: self.unbondFee,
                                       referralBalance: referralBalance,
                                       referrer: self.referrer)

            self.subscribeReferrerBalances()
            self.subscribeMyReferrer()
            self.subscribeReferral()
        }
    }
}

private extension FriendsInteractor {
    func getRewards(completion: @escaping () -> Void) {
        let referrer = address

        let networkOperation = SubqueryReferralRewardsOperation<ReferrerRewardsInfo>(address: referrer,
                                                                                     baseUrl: ConfigService.shared.config.subqueryURL)
        networkOperation.completionBlock = { [weak self] in
            do {
                self?.rewardData = try networkOperation.extractNoCancellableResultData()
            } catch {
                Logger.shared.error("Request unsuccessful")
            }

            completion()
        }

        operationManager.enqueue(operations: [networkOperation], in: .transient)
    }

    func getReferrerBalances(completion: @escaping () -> Void) {
        guard let operation = operationFactory.createReferrerBalancesOperation() else { return }

        operation.completionBlock = { [weak self] in
            do {
                if let data = try operation.extractResultData()?.underlyingValue {
                    self?.referralBalance = data
                }
            } catch {
                Logger.shared.error("Request unsuccessful")
            }

            completion()
        }

        operationManager.enqueue(operations: [operation], in: .transient)
    }

    func getMyReferrer(completion: @escaping () -> Void) {
        guard let operation = operationFactory.createReferrerOperation() else { return }

        operation.completionBlock = { [weak self] in
            do {
                if let data = try operation.extractResultData() {
                    guard let accountId = try? Data(hexStringSSF: data) else { return }
                    let networkType = ApplicationConfig.shared.addressType
                    guard let address = try? self?.addressFactory.addressFromAccountId(data: accountId, type: networkType) else {  return }

                    self?.referrer = address
                }
            } catch {
                Logger.shared.error("Request unsuccessful")
            }

            completion()
        }

        operationManager.enqueue(operations: [operation], in: .transient)
    }

    func getExtrinsicFee(completion: @escaping () -> Void) {
        feeProvider.getFee(for: .referral) { [weak self] resultFee in
            self?.setReferrerFee = resultFee
            completion()
        }
    }

    func getFee(with type: InputRewardAmountType, completion: @escaping () -> Void) {
        feeProvider.getFee(for: type) { [weak self] resultFee in
            if type == .bond {
                self?.bondFee = resultFee
                completion()
                return
            }
            self?.unbondFee = resultFee
            completion()
        }
    }

    func subscribeReferrerBalances() {
        do {
            guard let accountId = self.accountId else { return }

            guard let storageKey = try? StorageKeyFactory().referrerBalancesKeyForId(accountId).toHex(includePrefix: true) else {
                return
            }

            let updateClosure: (JSONRPCSubscriptionUpdate<StorageUpdate>) -> Void = { [weak self] update in
                guard let data = update.params.result.changes?.first?.last ?? "",
                let decoder = try? ScaleDecoder(data: Data(hexStringSSF: data)),
                let balance = try? Balance(scaleDecoder: decoder) else {
                    self?.presenter?.updateReferral(balance: Decimal(0))
                    return
                }

                guard let referralBalance = Decimal.fromSubstrateAmount(balance.value, precision: 18),
                      balance.value != self?.referralBalance.value else { return }

                self?.presenter?.updateReferral(balance: referralBalance)
            }

            let failureClosure: (Swift.Error, Bool) -> Void = { error, _ in
                print("referrerBalances failureClosure: \(error)")
            }

            let subscriptionId = try engine.subscribe(RPCMethod.storageSubscribe,
                                                      params: [[storageKey]],
                                                      updateClosure: updateClosure,
                                                      failureClosure: failureClosure)
            subscriptionIds.append(subscriptionId)
        } catch {
            print("Can't subscribe to storage:  \(error)")
        }
    }

    func subscribeMyReferrer() {
        do {
            guard let accountId = self.accountId else { return }

            guard let storageKey = try? StorageKeyFactory().referrersKeyForId(accountId).toHex(includePrefix: true) else {
                return
            }

            let updateClosure: (JSONRPCSubscriptionUpdate<StorageUpdate>) -> Void = { [weak self] update in

                guard let data = update.params.result.changes?.first?.last ?? "",
                      let accountId = try? Data(hexStringSSF: data) else { return }
                
                let networkType = ApplicationConfig.shared.addressType
                guard let address = try? self?.addressFactory.addressFromAccountId(data: accountId, type: networkType),
                      address != self?.referrer else {  return }

                DispatchQueue.main.async {
                    self?.presenter?.updateReferrer(address: address)
                }
            }

            let failureClosure: (Swift.Error, Bool) -> Void = { error, _ in
                print("referrer failureClosure: \(error)")
            }

            let subscriptionId = try engine.subscribe(RPCMethod.storageSubscribe,
                                                      params: [[storageKey]],
                                                      updateClosure: updateClosure,
                                                      failureClosure: failureClosure)
            subscriptionIds.append(subscriptionId)
        } catch {
            print("Can't subscribe to storage:  \(error)")
        }
    }

    func subscribeReferral() {
        do {
            guard let accountId = self.accountId else { return }

            guard let storageKey = try? StorageKeyFactory().referrerBalancesKeyForId(accountId).toHex(includePrefix: true) else {
                return
            }

            let updateClosure: (JSONRPCSubscriptionUpdate<StorageUpdate>) -> Void = { [weak self] update in

                guard update.params.result.changes?.first?.last != nil else { return }

                self?.getRewards(completion: { [weak self] in
                    DispatchQueue.main.async {
                        self?.presenter?.updateReferral(rewards: self?.rewardData?.rewards ?? [])
                    }
                })
            }

            let failureClosure: (Swift.Error, Bool) -> Void = { error, _ in
                print("referral failureClosure: \(error)")
            }

            let subscriptionId = try engine.subscribe(RPCMethod.storageSubscribe,
                                                      params: [[storageKey]],
                                                      updateClosure: updateClosure,
                                                      failureClosure: failureClosure)
            subscriptionIds.append(subscriptionId)
        } catch {
            print("Can't subscribe to storage:  \(error)")
        }
    }

    func unsubscribeReferrals() {
        subscriptionIds.forEach({
            engine.cancelForIdentifier($0)
        })
        subscriptionIds = []
    }
}
