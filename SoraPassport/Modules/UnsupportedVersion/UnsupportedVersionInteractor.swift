/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

final class UnsupportedVersionInteractor {
    weak var presenter: UnsupportedVersionInteractorOutputProtocol!
}

extension UnsupportedVersionInteractor: UnsupportedVersionInteractorInputProtocol {}
