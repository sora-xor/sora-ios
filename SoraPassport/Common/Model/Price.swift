/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

struct Price {
    let assetId: WalletAssetId
    let lastValue: Decimal
    let change: Decimal
}
