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
import SoraFoundation
import SoraKeystore
import IrohaCrypto
import SSFUtils

final class WebSocketService: WebSocketServiceProtocol {
    //Should be used only once, at startup
    static let shared: WebSocketService = {
        let lastUrl: URL
        if let url = SettingsManager.shared.lastSuccessfulUrl {
            lastUrl = url
        } else {
            lastUrl = ApplicationConfig.shared.defaultChainNodes.first!.url
        }

        let settings = WebSocketServiceSettings(
            url: lastUrl,
            addressType: ApplicationConfig.shared.addressType,
            address: nil
        )
        let storageFacade = SubstrateDataStorageFacade.shared
        return WebSocketService(
            settings: settings,
            applicationHandler: ApplicationHandler()
        )
    }()

    enum State {
        case throttled
        case active
        case inactive
    }

    var connection: JSONRPCEngine? { engine }

    let applicationHandler: ApplicationHandlerProtocol

    private(set) var settings: WebSocketServiceSettings
    private(set) var engine: WebSocketEngine?

    private(set) var subscriptions: [WebSocketSubscribing]?

    private(set) var isThrottled: Bool = true
    private(set) var isActive: Bool = true

    var networkStatusPresenter: NetworkAvailabilityLayerInteractorOutputProtocol?
    private var stateListeners: [WeakWrapper] = []

    init(
        settings: WebSocketServiceSettings,
        applicationHandler: ApplicationHandlerProtocol
    ) {
        self.settings = settings
        self.applicationHandler = applicationHandler
    }

    func setup() {
        guard isThrottled else {
            return
        }

        isThrottled = false

        applicationHandler.delegate = self

        setupConnection()
    }

    func throttle() {
        guard !isThrottled else {
            return
        }

        isThrottled = true

        clearConnection()
    }

    func update(settings: WebSocketServiceSettings) {
        guard self.settings != settings else {
            return
        }

        self.settings = settings

        if !isThrottled {
            clearConnection()
            setupConnection()
        }
    }

    func addStateListener(_ listener: WebSocketServiceStateListener) {
        stateListeners.append(WeakWrapper(target: listener))
    }

    func removeStateListener(_ listener: WebSocketServiceStateListener) {
        stateListeners = stateListeners.filter { $0 !== listener }
    }

    private func clearConnection() {
        engine?.delegate = nil
        engine?.disconnectIfNeeded()
        engine = nil

        subscriptions = nil
    }
    private func setupConnection() {
        let engine = WebSocketEngineFactory().createEngine(for: settings.url, autoconnect: isActive)
        engine.delegate = self
        self.engine = engine
        Logger.shared.info("start socket connected: \(settings.url)")
    }
}

extension WebSocketService: ApplicationHandlerDelegate {
    func didReceiveDidBecomeActive(notification _: Notification) {
        if !isThrottled, !isActive {
            isActive = true

            engine?.connectIfNeeded()
        }
    }

    func didReceiveDidEnterBackground(notification _: Notification) {
        if !isThrottled, isActive {
            isActive = false

            engine?.disconnectIfNeeded()
        }
    }
}

extension WebSocketService: WebSocketEngineDelegate {
    func webSocketDidChangeState(
        engine _: WebSocketEngine,
        from _: WebSocketEngine.State,
        to newState: WebSocketEngine.State
    ) {
        switch newState {
        case let .connecting(attempt):
            if attempt > 1 {
                scheduleNetworkUnreachable()

                stateListeners.forEach { listenerWeakWrapper in
                    (listenerWeakWrapper.target as? WebSocketServiceStateListener)?.websocketNetworkDown(url: settings.url)
                }
            }
        case .connected:
            scheduleNetworkReachable()

        case .notConnected, .waitingReconnection, .notReachable:
            break
        }
    }

    private func scheduleNetworkReachable() {
        DispatchQueue.main.async {
            self.networkStatusPresenter?.didDecideReachableStatusPresentation()
        }
    }

    private func scheduleNetworkUnreachable() {
        DispatchQueue.main.async {
            self.networkStatusPresenter?.didDecideUnreachableStatusPresentation()
        }
    }
}
