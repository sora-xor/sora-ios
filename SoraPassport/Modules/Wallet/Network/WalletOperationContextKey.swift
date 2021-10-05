import Foundation

struct WalletOperationContextKey {
    struct Balance {
        static let soranet = "soranetBalanceContextKey"
        static let erc20 = "erc20BalanceContextKey"
    }

    struct SoranetTransfer {
        static let balance = "soranetTransferBalanceContextKey"
    }

    struct ERC20Transfer {
        static let balance = "erc20TransferBalanceContextKey"
    }

    struct SoranetWithdraw {
        static let balance = "soranetWithdrawBalanceContextKey"
        static let provider = "soranetWithdrawAccountIdContextKey"
    }

    struct ERC20Withdraw {
        static let balance = "erc20WithdrawBalanceContextKey"
    }

    struct Receiver {
        static let isMine = "isMyAddress"
    }
}
