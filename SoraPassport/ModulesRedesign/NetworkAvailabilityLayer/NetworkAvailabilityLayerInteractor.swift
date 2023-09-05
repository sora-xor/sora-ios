// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: BSD-4-Clause

// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:

// Redistributions of source code must retain the above copyright notice, this list
// of conditions and the following disclaimer.
// Redistributions in binary form must reproduce the above copyright notice, this
// list of conditions and the following disclaimer in the documentation and/or other
// materials provided with the distribution.
//
// All advertising materials mentioning features or use of this software must display
// the following acknowledgement: This product includes software developed by Polka Biome
// Ltd., SORA, and Polkaswap.
//
// Neither the name of the Polka Biome Ltd. nor the names of its contributors may be used
// to endorse or promote products derived from this software without specific prior written permission.

// THIS SOFTWARE IS PROVIDED BY Polka Biome Ltd. AS IS AND ANY EXPRESS OR IMPLIED WARRANTIES,
// INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL Polka Biome Ltd. BE LIABLE FOR ANY
// DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
// USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import UIKit

final class NetworkAvailabilityLayerInteractor: NSObject {
    private struct Constants {
        static let reachabilityDelay: TimeInterval = 2.5
    }

    var presenter: NetworkAvailabilityLayerInteractorOutputProtocol!

    let reachabilityManager: ReachabilityManagerProtocol

    var logger: LoggerProtocol?

    private var pendingReachabilityStatus: Bool?

    init(reachabilityManager: ReachabilityManagerProtocol) {
        self.reachabilityManager = reachabilityManager
    }

    deinit {
        cancelReachabilityChange()
    }

    @objc private func notifyReachabilityChange() {
        guard let pendingStatus = pendingReachabilityStatus else {
            return
        }

        pendingReachabilityStatus = nil

        if pendingStatus {
            presenter.didDecideReachableStatusPresentation()
        } else {
            presenter.didDecideUnreachableStatusPresentation()
        }
    }

    private func setNeedsChangeReachability() {
        logger?.debug("Did change reachability to \(reachabilityManager.isReachable)")

        if let pendingValue = pendingReachabilityStatus {
            if pendingValue != reachabilityManager.isReachable {
                cancelReachabilityChange()
                pendingReachabilityStatus = nil
            }
        } else {
            pendingReachabilityStatus = reachabilityManager.isReachable
            scheduleReachabilityChange()
        }
    }

    private func cancelReachabilityChange() {
        NSObject.cancelPreviousPerformRequests(withTarget: self,
                                               selector: #selector(notifyReachabilityChange),
                                               object: nil)
    }

    private func scheduleReachabilityChange() {
        perform(#selector(notifyReachabilityChange), with: nil, afterDelay: Constants.reachabilityDelay)
    }
}

extension NetworkAvailabilityLayerInteractor: NetworkAvailabilityLayerInteractorInputProtocol {
    func setup() {
        do {
            if !reachabilityManager.isReachable {
                setNeedsChangeReachability()
            }

            try reachabilityManager.add(listener: self)
        } catch {
            logger?.error("Can't add reachability listener due to error \(error)")
        }
    }
}

extension NetworkAvailabilityLayerInteractor: ReachabilityListenerDelegate {
    func didChangeReachability(by manager: ReachabilityManagerProtocol) {
        setNeedsChangeReachability()
    }
}
