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

    private let syncQueue = DispatchQueue(label: "com.sora.websocket.sync", attributes: .concurrent)

    private var settingsStorage: WebSocketServiceSettings
    private var engineStorage: WebSocketEngine?
    private var subscriptionsStorage: [WebSocketSubscribing]?
    private var isThrottledFlag: Bool = true
    private var isActiveFlag: Bool = true
    private var stateListenersStorage: [WeakWrapper] = []

    var settings: WebSocketServiceSettings {
        get { syncQueue.sync { settingsStorage } }
        set { syncQueue.async(flags: .barrier) { self.settingsStorage = newValue } }
    }

    var engine: WebSocketEngine? {
        get { syncQueue.sync { engineStorage } }
        set { syncQueue.async(flags: .barrier) { self.engineStorage = newValue } }
    }

    var subscriptions: [WebSocketSubscribing]? {
        get { syncQueue.sync { subscriptionsStorage } }
        set { syncQueue.async(flags: .barrier) { self.subscriptionsStorage = newValue } }
    }

    var isThrottled: Bool {
        get { syncQueue.sync { isThrottledFlag } }
        set { syncQueue.async(flags: .barrier) { self.isThrottledFlag = newValue } }
    }

    var isActive: Bool {
        get { syncQueue.sync { isActiveFlag } }
        set { syncQueue.async(flags: .barrier) { self.isActiveFlag = newValue } }
    }

    var stateListeners: [WeakWrapper] {
        get { syncQueue.sync { stateListenersStorage } }
        set { syncQueue.async(flags: .barrier) { self.stateListenersStorage = newValue } }
    }

    var networkStatusPresenter: NetworkAvailabilityLayerInteractorOutputProtocol?

    init(
        settings: WebSocketServiceSettings,
        applicationHandler: ApplicationHandlerProtocol
    ) {
        self.settingsStorage = settings
        self.applicationHandler = applicationHandler
    }

    func setup() {
        guard isThrottled else {
            return
        }

        isThrottled = false
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
        syncQueue.async(flags: .barrier) {
            // cleanup deallocated listeners to avoid accumulation
            self.stateListenersStorage.removeAll { $0.target == nil }
            self.stateListenersStorage.append(WeakWrapper(target: listener))
        }
    }

    func removeStateListener(_ listener: WebSocketServiceStateListener) {
        syncQueue.async(flags: .barrier) {
            self.stateListenersStorage.removeAll { $0.target == nil || ($0.target as AnyObject) === listener }
        }
    }

    private func clearConnection() {
        engine?.delegate = nil
        engine?.disconnectIfNeeded()
        engine = nil
        subscriptions = nil
    }

    private func setupConnection() {
        let newEngine = WebSocketEngineFactory().createEngine(for: settings.url, autoconnect: isActive)
        newEngine.delegate = self
        engine = newEngine
        Logger.shared.info("start socket connected: \(settings.url)")
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
                notifyListenersNetworkDown()
            }
        case .connected:
            scheduleNetworkReachable()
        case .notConnected, .waitingReconnection, .notReachable:
            scheduleNetworkUnreachable()
            notifyListenersNetworkDown()
        }
    }

    private func notifyListenersNetworkDown() {
        let listeners = stateListeners
        let url = settings.url

        for wrapper in listeners {
            (wrapper.target as? WebSocketServiceStateListener)?.websocketNetworkDown(url: url)
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
