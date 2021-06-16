/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import UIKit

final class StakingInteractor {
    weak var presenter: StakingInteractorOutputProtocol!
}

extension StakingInteractor: StakingInteractorInputProtocol {

}
