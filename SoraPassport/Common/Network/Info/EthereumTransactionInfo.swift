import Foundation
import BigInt

struct EthereumTransactionInfo {
    let txData: Data
    let gasPrice: BigUInt
    let gasLimit: BigUInt
    let nonce: BigUInt
}
