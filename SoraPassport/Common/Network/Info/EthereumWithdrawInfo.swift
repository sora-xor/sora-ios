import Foundation
import BigInt

struct EthereumWithdrawInfo {
    let txHash: Data
    let amount: BigUInt
    let proof: [EthereumSignature]
    let destination: String
}
