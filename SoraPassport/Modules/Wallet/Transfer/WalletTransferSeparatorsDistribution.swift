/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import CommonWallet
import SoraUI

struct WalletTransferSeparatorsDistribution: OperationDefinitionSeparatorsDistributionProtocol {
    var assetBorderType: BorderType { [.bottom] }

    var receiverBorderType: BorderType { [.bottom] }

    var amountWithFeeBorderType: BorderType { [.bottom] }

    var amountWithoutFeeBorderType: BorderType { [.bottom] }

    var firstFeeBorderType: BorderType { [.bottom] }

    var middleFeeBorderType: BorderType { [.bottom] }

    var lastFeeBorderType: BorderType { [] }

    var singleFeeBorderType: BorderType { [] }

    var descriptionBorderType: BorderType { [.bottom] }
}
