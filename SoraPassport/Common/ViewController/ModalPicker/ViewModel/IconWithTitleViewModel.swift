/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit
import CommonWallet

struct IconWithTitleViewModel {
    let icon: UIImage?
    let title: String
}

struct LoadingIconWithTitleViewModel {
    let iconViewModel: WalletImageViewModelProtocol?
    let title: String
    let toggle: Bool
}
