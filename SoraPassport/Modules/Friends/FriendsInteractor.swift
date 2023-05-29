import Foundation
import RobinHood
import SoraKeystore
import FearlessUtils
import BigInt
import XNetworking
import IrohaCrypto

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
            self?.group.leave()
        }

        group.enter()
        getFee(with: .bond) { [weak self] in
            self?.group.leave()
        }

        group.enter()
        getFee(with: .unbond) { [weak self] in
            self?.group.leave()
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
                    guard let accountId = try? Data(hexString: data) else { return }
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
                let decoder = try? ScaleDecoder(data: Data(hexString: data)),
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
                      let accountId = try? Data(hexString: data) else { return }
                
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
