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
import SoraKeystore

protocol InvitationLinkObserver: AnyObject {
    func didUpdateInvitationLink(from oldLink: InvitationDeepLink?)
}

protocol InvitationLinkServiceProtocol: DeepLinkServiceProtocol {
    var link: InvitationDeepLink? { get }

    func add(observer: InvitationLinkObserver)

    func remove(observer: InvitationLinkObserver)

    func save(code: String)

    func clear()
}

final class InvitationLinkService {
    private struct ObserverWrapper {
        weak var observer: InvitationLinkObserver?
    }

    private var observers: [ObserverWrapper] = []

    private(set) var link: InvitationDeepLink?

    private(set) var settings: SettingsManagerProtocol

    var logger: LoggerProtocol?

    init(settings: SettingsManagerProtocol) {
        self.settings = settings

    }

}

extension InvitationLinkService: InvitationLinkServiceProtocol {
    func handle(url: URL) -> Bool {
        do {
            let enviromentPattern: String = RemoteEnviroment.allCases.compactMap { enviroment in
                guard !enviroment.rawValue.isEmpty else {
                    return nil
                }

                return "(\(enviroment.rawValue))"
            }
                .joined(separator: "|")

            let pattern = "^(\\/(\(enviromentPattern)))?\\/join\\/\(String.invitationCodePattern)$"
            let regularExpression = try NSRegularExpression(pattern: pattern)

            let path = url.path
            let range = NSRange(location: 0, length: (path as NSString).length)

            logger?.debug("Trying to match \(pattern) against \(path) in range \(range)")

            if regularExpression.firstMatch(in: path, range: range) == nil {
                logger?.debug("No matching found")
                return false
            }

            let code = url.lastPathComponent

            logger?.debug("Code found \(code)")

            save(code: code)

            return true
        } catch {
            logger?.error("Unexpected error \(error)")
            return false
        }
    }

    func save(code: String) {
        let oldLink = link
        link = InvitationDeepLink(code: code)

        self.observers.forEach { wrapper in
            if let observer = wrapper.observer {
                observer.didUpdateInvitationLink(from: oldLink)
            }
        }
    }

    func add(observer: InvitationLinkObserver) {
        observers = observers.filter { $0.observer !== nil}

        if observers.contains(where: { $0.observer === observer }) {
            return
        }

        let wrapper = ObserverWrapper(observer: observer)
        observers.append(wrapper)
    }

    func remove(observer: InvitationLinkObserver) {
        observers = observers.filter { $0.observer !== nil && observer !== observer}
    }

    func clear() {
        link = nil
    }
}
