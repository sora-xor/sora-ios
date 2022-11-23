/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

extension UIViewController {
    var topModalViewController: UIViewController {
        var presentingController = self

        while let nextPresentingController = presentingController.presentedViewController {
            presentingController = nextPresentingController
        }

        return presentingController
    }
}
