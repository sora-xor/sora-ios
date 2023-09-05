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

import Foundation
import Reachability

protocol ReachabilityListenerDelegate: AnyObject {
    func didChangeReachability(by manager: ReachabilityManagerProtocol)
}

protocol ReachabilityManagerProtocol {
    var isReachable: Bool { get }

    func add(listener: ReachabilityListenerDelegate) throws
    func remove(listener: ReachabilityListenerDelegate)
}

fileprivate final class ReachabilityListenerWrapper {
    weak var listener: ReachabilityListenerDelegate?

    init(listener: ReachabilityListenerDelegate) {
        self.listener = listener
    }
}

final class ReachabilityManager {
    static let shared: ReachabilityManager? = ReachabilityManager()

    private var listeners: [ReachabilityListenerWrapper] = []
    private var reachability: Reachability

    private init?() {
        guard let newReachability = try? Reachability() else {
            return nil
        }

        reachability = newReachability

        reachability.whenReachable = { [weak self] (reachability) in
            if let strongSelf = self {
                self?.listeners.forEach { $0.listener?.didChangeReachability(by: strongSelf) }
            }
        }

        reachability.whenUnreachable = { [weak self] (reachability) in
            if let strongSelf = self {
                self?.listeners.forEach { $0.listener?.didChangeReachability(by: strongSelf) }
            }
        }
    }
}

extension ReachabilityManager: ReachabilityManagerProtocol {

    var isReachable: Bool {
        return reachability.connection != .unavailable
    }

    func add(listener: ReachabilityListenerDelegate) throws {
        if listeners.count == 0 {
            try reachability.startNotifier()
        }

        listeners = listeners.filter { $0.listener != nil }

        if !listeners.contains(where: { $0.listener === listener }) {
            let wrapper = ReachabilityListenerWrapper(listener: listener)
            listeners.append(wrapper)
        }
    }

    func remove(listener: ReachabilityListenerDelegate) {
        listeners = listeners.filter { $0.listener != nil && $0.listener !== listener }

        if listeners.count == 0 {
            reachability.stopNotifier()
        }
    }
}
