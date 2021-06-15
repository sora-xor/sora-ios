import Foundation

enum WalletNetworkFacadeError: Error {
    case brokenAmountValue
    case emptyBalance
    case ethFeeMissingOrBroken
    case withdrawProviderMissing
    case transferMetadataMissing
    case withdrawMetadataMissing
    case missingTransferData
    case ethBridgeDisabled
}
