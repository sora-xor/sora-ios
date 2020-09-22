import Foundation
import CommonWallet

typealias EthFeeParameters = [AmountDecimal]

extension EthFeeParameters {
    init(transferGas: AmountDecimal,
         mintGas: AmountDecimal,
         gasPrice: AmountDecimal,
         balance: AmountDecimal) {
        self = [transferGas, mintGas, gasPrice, balance]
    }

    var transferGas: AmountDecimal { self[0] }

    var mintGas: AmountDecimal { self[1] }

    var gasPrice: AmountDecimal { self[2] }

    var balance: AmountDecimal { self[3] }
}
