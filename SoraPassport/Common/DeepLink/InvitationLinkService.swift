// This file is part of the SORA network and Polkaswap app.

// Copyright (c) 2022, 2023, Polka Biome Ltd. All rights reserved.
// SPDX-License-Identifier: Apache-2.0

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

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
