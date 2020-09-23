/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation

enum PollableState {
    case initial
    case setuping
    case setup
    case ready
}

protocol Pollable: class {
    var state: PollableState { get }
    var delegate: PollableDelegate? { get set }

    func setup()
    func poll()
    func cancel()
}

protocol PollableDelegate: class {
    func pollableDidChangeState(_ pollable: Pollable, from oldState: PollableState)
}
