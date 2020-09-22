import Foundation
import BigInt

struct ERC20TransferInfo {
    let tokenAddress: Data
    let destinationAddress: Data
    let amount: BigUInt
}
