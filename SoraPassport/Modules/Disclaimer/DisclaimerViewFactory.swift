/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

final class DisclaimerViewFactory: DisclaimerViewFactoryProtocol {
    func createView() -> DisclaimerViewProtocol? {
        let view = DisclaimerViewController(nib: R.nib.disclaimerViewController)
        return view
    }
}
