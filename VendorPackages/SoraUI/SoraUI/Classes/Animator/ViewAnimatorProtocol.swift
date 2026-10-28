/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache-2.0
*/

import UIKit

public protocol ViewAnimatorProtocol {
    var duration: TimeInterval { get }

    func animate(view: UIView, completionBlock: ((Bool) -> Void)?)
}
