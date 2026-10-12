import Foundation
import RobinHood
import SSFModels
import SSFUtils

public enum AccountManagerServiceError: Error {
    case unexpected
    case logoutNotCompleted
}

// sourcery: AutoMockable
public protocol AccountManageble {
    func getCurrentAccount() -> MetaAccountModel?
    func setCurrentAccount(
        account: MetaAccountModel,
        completionClosure: @escaping (Result<MetaAccountModel, Error>) -> Void
    )
    func getAllAccounts() async throws -> [MetaAccountModel]
    func updateEnabilibilty(for chainAssetId: String) async throws -> MetaAccountModel
    func updateFavourite(for chainId: String) async throws -> MetaAccountModel
    func update(enabledAssetIds: Set<String>) async throws -> MetaAccountModel
    func updateWalletName(with newName: String) async throws -> MetaAccountModel
    func logout() async throws
}

public final class AccountManagementService {
    private let operationQueue: OperationQueue = OperationManagerFacade.sharedDefaultQueue
    private let selectedWallet: PersistentValueSettings<MetaAccountModel>
    private let accountManagementWorker: AccountManagementWorkerProtocol

    public init(
        accountManagementWorker: AccountManagementWorkerProtocol,
        selectedWallet: PersistentValueSettings<MetaAccountModel>
    ) {
        self.selectedWallet = selectedWallet
        self.selectedWallet.setup()
        self.accountManagementWorker = accountManagementWorker
    }
}

extension AccountManagementService: AccountManageble {
    public func getCurrentAccount() -> MetaAccountModel? {
        selectedWallet.value
    }

    public func setCurrentAccount(
        account: MetaAccountModel,
        completionClosure: @escaping (Result<MetaAccountModel, Error>) -> Void
    ) {
        selectedWallet.performSave(value: account, completionClosure: completionClosure)
    }

    public func getAllAccounts() async throws -> [MetaAccountModel] {
        try await accountManagementWorker.fetchAll()
    }

    public func updateEnabilibilty(for chainAssetId: String) async throws -> MetaAccountModel {
        try await withCheckedThrowingContinuation { continuation in
            guard let wallet = selectedWallet.value else {
                continuation.resume(throwing: AccountManagerServiceError.unexpected)
                return
            }

            var enabledAssetIds = wallet.enabledAssetIds

            if enabledAssetIds.contains(chainAssetId) {
                enabledAssetIds.remove(chainAssetId)
            } else {
                enabledAssetIds.insert(chainAssetId)
            }

            let updatedAccount = wallet.replacing(newEnabledAssetIds: enabledAssetIds)

            selectedWallet.performSave(value: updatedAccount, completionClosure: { _ in
                continuation.resume(with: .success(updatedAccount))
            })
        }
    }

    public func updateFavourite(for chainId: String) async throws -> MetaAccountModel {
        try await withCheckedThrowingContinuation { continuation in
            guard let wallet = selectedWallet.value else {
                continuation.resume(throwing: AccountManagerServiceError.unexpected)
                return
            }

            var favouriteChainIds = wallet.favouriteChainIds

            if let index = favouriteChainIds.firstIndex(of: chainId) {
                favouriteChainIds.remove(at: index)
            } else {
                favouriteChainIds.append(chainId)
            }

            let updatedAccount = wallet.replacingFavoutites(favouriteChainIds)

            selectedWallet.performSave(value: updatedAccount, completionClosure: { _ in
                continuation.resume(with: .success(updatedAccount))
            })
        }
    }

    public func update(enabledAssetIds: Set<String>) async throws -> MetaAccountModel {
        try await withCheckedThrowingContinuation { continuation in
            guard let wallet = selectedWallet.value else {
                continuation.resume(throwing: AccountManagerServiceError.unexpected)
                return
            }

            let updatedAccount = wallet.replacing(newEnabledAssetIds: enabledAssetIds)

            selectedWallet.performSave(value: updatedAccount, completionClosure: { _ in
                continuation.resume(with: .success(updatedAccount))
            })
        }
    }

    public func updateWalletName(with newName: String) async throws -> MetaAccountModel {
        try await withCheckedThrowingContinuation { continuation in
            guard let wallet = selectedWallet.value else {
                continuation.resume(throwing: AccountManagerServiceError.unexpected)
                return
            }

            let updatedAccount = wallet.replacingName(newName)

            selectedWallet.performSave(value: updatedAccount, completionClosure: { _ in
                continuation.resume(with: .success(updatedAccount))
            })
        }
    }

    public func logout() async throws {
        accountManagementWorker.deleteAll(completion: {})
    }
}
