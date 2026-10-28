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
import SoraFoundation
import SoraKeystore
import IrohaCrypto
import SSFUtils

final class WebSocketService: WebSocketServiceProtocol {
    // There is no process-wide instance any more. Startup used one socket,
    // opened to the saved `lastSuccessfulUrl` (or to an arbitrary bundled node
    // on a fresh install) and kept on that URL for the life of the process, so
    // a dead saved node stopped the app on the splash. The asset list is now
    // loaded over the chain registry's connection, which fails over between
    // nodes (see `StartupNetworkCoordinator`).

    enum State {
        case throttled
        case active
        case inactive
    }

    var connection: JSONRPCEngine? { engine }

    let applicationHandler: ApplicationHandlerProtocol
    private let engineFactory: WebSocketEngineFactoryProtocol

    private(set) var settings: WebSocketServiceSettings
    private(set) var engine: WebSocketEngine?

    private(set) var subscriptions: [WebSocketSubscribing]?

    private(set) var isThrottled: Bool = true
    private(set) var isActive: Bool = true

    var networkStatusPresenter: NetworkAvailabilityLayerInteractorOutputProtocol?
    private var stateListeners: [WeakWrapper] = []

    init(
        settings: WebSocketServiceSettings,
        applicationHandler: ApplicationHandlerProtocol,
        engineFactory: WebSocketEngineFactoryProtocol = WebSocketEngineFactory()
    ) {
        self.settings = settings
        self.applicationHandler = applicationHandler
        self.engineFactory = engineFactory
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
        stateListeners.removeAll { $0.target == nil }
        guard !stateListeners.contains(where: { $0.target === listener }) else { return }
        stateListeners.append(WeakWrapper(target: listener))
    }

    func removeStateListener(_ listener: WebSocketServiceStateListener) {
        stateListeners = stateListeners.filter { $0.target != nil && $0.target !== listener }
    }

    private func clearConnection() {
        engine?.delegate = nil
        engine?.disconnectIfNeeded()
        engine = nil

        subscriptions = nil
    }
    private func setupConnection() {
        let engine = engineFactory.createEngine(for: settings.url, autoconnect: isActive)
        engine.delegate = self
        self.engine = engine
        Logger.shared.info("start socket connected: \(settings.url)")
    }
}

extension WebSocketService: ApplicationHandlerDelegate {
    func didReceiveDidBecomeActive(notification _: Notification) {
        guard !isActive else { return }
        isActive = true
        if !isThrottled { engine?.connectIfNeeded() }
    }

    func didReceiveDidEnterBackground(notification _: Notification) {
        guard isActive else { return }
        isActive = false
        if !isThrottled { engine?.disconnectIfNeeded() }
    }
}

extension WebSocketService: WebSocketEngineDelegate {
    func webSocketDidChangeState(
        engine: WebSocketEngine,
        from _: WebSocketEngine.State,
        to newState: WebSocketEngine.State
    ) {
        guard self.engine === engine, !isThrottled else { return }
        switch newState {
        case let .connecting(attempt):
            if attempt > 1 {
                scheduleNetworkUnreachable(engine: engine)

                stateListeners.forEach { listenerWeakWrapper in
                    (listenerWeakWrapper.target as? WebSocketServiceStateListener)?.websocketNetworkDown(url: settings.url)
                }
            }
        case .connected:
            scheduleNetworkReachable(engine: engine)

        case .notConnected, .waitingReconnection, .notReachable:
            break
        }
    }

    private func scheduleNetworkReachable(engine: WebSocketEngine) {
        DispatchQueue.main.async { [weak self, weak engine] in
            guard let self, let engine, self.engine === engine, !self.isThrottled else { return }
            self.networkStatusPresenter?.didDecideReachableStatusPresentation()
        }
    }

    private func scheduleNetworkUnreachable(engine: WebSocketEngine) {
        DispatchQueue.main.async { [weak self, weak engine] in
            guard let self, let engine, self.engine === engine, !self.isThrottled else { return }
            self.networkStatusPresenter?.didDecideUnreachableStatusPresentation()
        }
    }
}
