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

struct LoadingIconWithTitleViewModel: Equatable {
    static func == (lhs: LoadingIconWithTitleViewModel, rhs: LoadingIconWithTitleViewModel) -> Bool {
        lhs.title == rhs.title && lhs.subtitle == rhs.subtitle
    }

    let iconViewModel: WalletImageViewModelProtocol?
    let title: String
    let subtitle: String?
    let toggle: Bool
}
