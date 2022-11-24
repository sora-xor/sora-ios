/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: Apache 2.0
*/

import Foundation
import SoraFoundation
import SoraKeystore
import IrohaCrypto
import FearlessUtils

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
        default:
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
