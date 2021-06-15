import Foundation

struct TokenBalancesData {
    let soranet: Decimal
    let ethereum: Decimal
}

extension TokenBalancesData {
    init(balanceContext: [String: String]) {
        if let balanceString = balanceContext[WalletOperationContextKey.Balance.soranet],
           let balance = Decimal(string: balanceString) {
            soranet = balance
        } else {
            soranet = 0
        }

        if let balanceString = balanceContext[WalletOperationContextKey.Balance.erc20],
           let balance = Decimal(string: balanceString) {
            ethereum = balance
        } else {
            ethereum = 0
        }
    }

    init(sendingContext: [String: String]) {
        var soranet: Decimal = 0
        var ethereum: Decimal = 0

        if let balanceString = sendingContext[WalletOperationContextKey.SoranetTransfer.balance],
           let balance = Decimal(string: balanceString) {
            soranet += balance
        }

        if let balanceString = sendingContext[WalletOperationContextKey.SoranetWithdraw.balance],
           let balance = Decimal(string: balanceString) {
            soranet += balance
        }

        if let balanceString = sendingContext[WalletOperationContextKey.ERC20Transfer.balance],
           let balance = Decimal(string: balanceString) {
            ethereum += balance
        }

        if let balanceString = sendingContext[WalletOperationContextKey.ERC20Withdraw.balance],
           let balance = Decimal(string: balanceString) {
            ethereum += balance
        }

        self.soranet = soranet
        self.ethereum = ethereum
    }
}
