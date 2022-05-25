/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

protocol NetworkAvailabilityLayerInteractorInputProtocol: class {
    func setup()
}

protocol NetworkAvailabilityLayerInteractorOutputProtocol: class {
    func didDecideUnreachableStatusPresentation()
    func didDecideReachableStatusPresentation()
}
