/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

enum WalletNetworkFacadeError: Error {
    case brokenAmountValue
    case emptyBalance
    case ethFeeMissingOrBroken
    case withdrawProviderMissing
    case transferMetadataMissing
    case withdrawMetadataMissing
    case missingTransferData
}
