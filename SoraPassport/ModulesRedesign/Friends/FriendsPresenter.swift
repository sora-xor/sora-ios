import Foundation
import SoraKeystore
import SoraFoundation
import SoraUI
import BigInt
import XNetworking
import FearlessUtils
import CommonWallet

extension FriendsPresenter {
    enum InvitationActionType: Int {
        case startInvite
        case enterLink
    }
}

final class FriendsPresenter {
    weak var view: FriendsViewProtocol?
    var wireframe: FriendsWireframeProtocol!
    var interactor: FriendsInteractorInputProtocol!

    private var isExpaned: Bool = false
    private var rewards: [ReferrerReward] = []
    private let settings: SettingsManagerProtocol
    private var setReferrerFee = Decimal(0)
    private var bondFee = Decimal(0)
    private var unbondFee = Decimal(0)
    private var referralBalance = Decimal(0)
    private var referrer = ""
    private var totalRewardRow = 0
    private let selectedAccount: AccountItem
    private let feeAsset: AssetInfo

    init(settings: SettingsManagerProtocol,
         keychain: KeystoreProtocol,
         selectedAccount: AccountItem,
         feeAsset: AssetInfo) {
        self.settings = settings
        self.selectedAccount = selectedAccount
        self.feeAsset = feeAsset
    }
}

// MARK: - Presenter Protocol

extension FriendsPresenter: FriendsPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func didSelectAction(_ action: FriendsPresenter.InvitationActionType) {
        guard let viewController = view?.controller else { return }

        switch action {
        case .startInvite:
            showInputRewardAmount(with: .bond)

        case .enterLink:
            guard referrer.isEmpty else {
                wireframe.showReferrerScreen(from: viewController, referrer: referrer)
                return
            }
            wireframe.showLinkInputViewController(from: viewController, delegate: self)
        }
    }
}

// MARK: - Interactor Output Protocol

extension FriendsPresenter: FriendsInteractorOutputProtocol {
    func updateReferrer(address: String) {
        self.referrer = address
        updateScreen()
    }

    func updateReferral(balance: Decimal) {
        self.referralBalance = balance
        updateScreen()
    }

    func updateReferral(rewards: [ReferrerReward]) {
        self.rewards = rewards
        updateScreen()
    }

    func didReceive(rewards: [ReferrerReward],
                    setReferrerFee: Decimal,
                    bondFee: Decimal,
                    unbondFee: Decimal,
                    referralBalance: Decimal,
                    referrer: String) {
        self.rewards = rewards
        self.setReferrerFee = setReferrerFee
        self.bondFee = bondFee
        self.unbondFee = unbondFee
        self.referralBalance = referralBalance
        self.referrer = referrer

        updateScreen()
    }
}

extension FriendsPresenter: InputLinkPresenterOutput {
    func setupReferrer(_ referrer: String) {
        self.referrer = referrer
        updateScreen()
    }

    func showAlert(withSuccess isSuccess: Bool) {
        DispatchQueue.main.async {

            let title = isSuccess ? R.string.localizable.walletTransactionSubmitted(preferredLanguages: .currentLocale) :
            R.string.localizable.walletTransactionRejected(preferredLanguages: .currentLocale)

            let image = isSuccess ? R.image.success() : R.image.iconClose()

            self.view?.showAlert(with: title, image: image)
        }
    }
    
    func showTransactionDetails(from controller: UIViewController?,
                                result: Result<String, Swift.Error>,
                                peerAddress: String,
                                completion: (() -> Void)?) {
        var status: TransactionBase.Status = .pending
        var txHash = ""
        
        switch result {
        case .success(let hash):
            txHash = hash
        case .failure:
            status = .failed
        }
        
        let base = TransactionBase(txHash: txHash,
                                   blockHash: "",
                                   fee: Amount(value: 0),
                                   status: status,
                                   timestamp: "\(Date().timeIntervalSince1970)")
 
        let transaction = SetReferrerTransaction(base: base,
                                                 who: peerAddress,
                                                 isMyReferrer: true,
                                                 tokenId: WalletAssetId.xor.rawValue)

        EventCenter.shared.notify(with: NewTransactionCreatedEvent(item: transaction))
        wireframe.showActivityDetails(from: controller, model: transaction, completion: completion)
    }
    
    func moveForward(controller: UIViewController?) {
        wireframe.setViewControllers(from: controller,
                                     currentController: view?.controller,
                                     referrer: referrer)
    }
}

extension FriendsPresenter: InputRewardAmountPresenterOutput {
    func showTransactionDetails(from controller: UIViewController?,
                                result: Result<String, Swift.Error>,
                                fee: Decimal,
                                amount: Decimal,
                                type: ReferralBondTransaction.ReferralTransactionType,
                                completion: (() -> Void)?) {
        var status: TransactionBase.Status = .pending
        var txHash = ""
        
        switch result {
        case .success(let hash):
            txHash = hash
        case .failure:
            status = .failed
        }
        
        let base = TransactionBase(txHash: txHash,
                                   blockHash: "",
                                   fee: Amount(value: fee),
                                   status: status,
                                   timestamp: "\(Date().timeIntervalSince1970)")
 
        let transaction = ReferralBondTransaction(base: base,
                                                  amount: Amount(value: amount),
                                                  tokenId: WalletAssetId.xor.rawValue,
                                                  type: type)

        EventCenter.shared.notify(with: NewTransactionCreatedEvent(item: transaction))
        wireframe.showActivityDetails(from: controller, model: transaction, completion: completion)
    }
}

extension FriendsPresenter: TotalRewardsCellDelegate {
    func expandButtonTapped() {
        isExpaned = !isExpaned

        let items = createItems()
        let indexs: [Int] = Array(totalRewardRow...(totalRewardRow + rewards.count))
        view?.reloadScreen(with: items, updatedIndexs: indexs, isExpanding: isExpaned)
    }
}

extension FriendsPresenter: ReferrerCellDelegate {
    func enterLinkButtonTapped() {
        guard let view = view?.controller else { return }
        wireframe.showLinkInputViewController(from: view, delegate: self)
    }
}

extension FriendsPresenter: AvailableInvitationsCellDelegate {
    func shareButtonTapped(with text: String) {
        showActivityViewController(with: text)
    }

    func changeBoundedAmount(to type: InputRewardAmountType) {
        showInputRewardAmount(with: type)
    }
}

private extension FriendsPresenter {
    func createItems() -> [CellViewModel] {

        let totalReward = rewards.reduce(Decimal(0)) { totalReward, reward in
            let decimalReward = Decimal.fromSubstrateAmount(BigUInt(stringLiteral: reward.amount), precision: 18) ?? Decimal(0)
            return totalReward + decimalReward
        }

        var items: [CellViewModel] = []

        let invitationCount = (referralBalance / setReferrerFee).rounded(mode: .down)
        items.append(AvailableInvitationsViewModel(accountAddress: selectedAccount.address,
                                                   invitationCount: invitationCount,
                                                   bondedAmount: referralBalance,
                                                   delegate: self))

        items.append(ReferrerViewModel(address: referrer, delegate: self))

        items.append(TotalRewardsViewModel(invetationCount: rewards.count,
                                           totalRewardsAmount: totalReward,
                                           assetSymbol: feeAsset.symbol,
                                           delegate: self))
        totalRewardRow = items.count

        if isExpaned {
            items.append(RewardSeparatorViewModel())

            for reward in rewards {
                let amount =  Decimal.fromSubstrateAmount(BigUInt(stringLiteral: reward.amount), precision: 18) ?? Decimal(0)
                items.append(RewardRawViewModel(title: reward.referral, amount: amount, assetSymbol: feeAsset.symbol))
            }
        }

        items.append(RewardFooterViewModel())

        return items
    }

    func updateScreen() {
        if referralBalance < setReferrerFee {
            DispatchQueue.main.async {
                self.view?.startInvitingScreen(with: self.referrer)
            }
            return
        }

        let items = createItems()

        DispatchQueue.main.async {
            self.view?.setup(with: items)
        }
    }

    func showInputRewardAmount(with type: InputRewardAmountType) {
        guard let view = view?.controller else { return }
        wireframe.showInputRewardAmountViewController(from: view,
                                                      fee: type == .bond ? bondFee : unbondFee,
                                                      bondedAmount: referralBalance,
                                                      type: type,
                                                      delegate: self)
    }

    func showActivityViewController(with shareText: String) {
        guard let view = view?.controller else { return }
        wireframe.showActivityViewController(from: view, shareText: shareText)
    }
}

// MARK: - Localizable

extension FriendsPresenter: Localizable {

    var locale: Locale {
        return localizationManager?.selectedLocale ?? Locale.current
    }

    var languages: [String] {
        return localizationManager?.preferredLocalizations ?? []
    }
}
