import BigInt
import Foundation
import SSFModels
import SSFUtils

struct XTokensTransferCall: Codable {
    let currencyId: CurrencyId
    @StringCodable var amount: BigUInt
    let dest: XcmVersionedMultiLocation
    let destWeightLimit: XcmWeightLimit?
}
