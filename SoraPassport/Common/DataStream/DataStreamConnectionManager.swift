import Foundation
import SoraKeystore
import SoraCrypto
import SoraFoundation
import IKEventSource
import RobinHood

enum StreamServiceType: String {
    case stream
}

final class DataStreamConnectionManager {
    private enum EventType: String {
        case event = "{\"type\": \"event\"}"
        case outOfSync = "{\"type\": \"OUT_OF_SYNC\"}"
    }

    let eventHandler: DataStreamHandling
    let serviceUnit: ServiceUnit
    let applicationListener: ApplicationHandlerProtocol
    let networkStatusListener: ReachabilityManagerProtocol
    let requestSigner: DARequestSignerProtocol
    let logger: LoggerProtocol

    private(set) var settings: SettingsManagerProtocol

    private var sseConnection: EventSourceProtocol?

    deinit {
        disconnect()
    }

    init(eventHandler: DataStreamHandling,
         serviceUnit: ServiceUnit,
         settings: SettingsManagerProtocol,
         applicationListener: ApplicationHandlerProtocol,
         networkStatusListener: ReachabilityManagerProtocol,
         requestSigner: DARequestSignerProtocol,
         logger: LoggerProtocol) throws {

        self.eventHandler = eventHandler
        self.serviceUnit = serviceUnit
        self.settings = settings
        self.applicationListener = applicationListener
        self.networkStatusListener = networkStatusListener
        self.requestSigner = requestSigner
        self.logger = logger

        setupNetworkStatusListener()
        setupApplicationListener()

        try connect()
    }

    private func connect() throws {
        let token: String

        if let currentToken = settings.streamToken {
            token = currentToken
        } else {
            token = UUID().uuidString
            settings.streamToken = token
        }

        guard
            let urlTemplate = serviceUnit.service(for: StreamServiceType.stream.rawValue)?.serviceEndpoint,
            let url = try? SoraFoundation.EndpointBuilder(urlTemplate: urlTemplate).buildParameterURL(token) else {
                throw NetworkUnitError.brokenServiceEndpoint
        }

        let unsignedRequest = DAHttpRequest(uri: url,
                                            method: HttpMethod.get.rawValue,
                                            body: nil)

        let signedRequest = try requestSigner.sign(urlRequest: URLRequest(daRequest: unsignedRequest))

        let connection = EventSource(url: url,
                                     headers: signedRequest.allHTTPHeaderFields ?? [:])

        connection.onOpen { [weak self] in
            self?.handleOnOpen()
        }

        connection.onComplete { [weak self] (status: Int?, shouldReconnect: Bool?, error: NSError?) in
            self?.handleOnComplete(status: status, shouldReconnect: shouldReconnect, error: error)
        }

        let eventHandler = { [weak self] (identifier: String?, event: String?, data: String?) -> Void in
            self?.handleEventWithId(identifier, data: data)
        }

        connection.addEventListener(EventType.event.rawValue, handler: eventHandler)

        let syncHandler = { [weak self] (identifier: String?, event: String?, data: String?) -> Void in
            self?.handleOutOfSync()
        }

        connection.addEventListener(EventType.outOfSync.rawValue, handler: syncHandler)

        let lastEventId = settings.lastStreamEventId

        logger.debug("Start connecting with last event id: \(String(describing: lastEventId)) \(token)")

        connection.connect(lastEventId: lastEventId)

        sseConnection = connection
    }

    private func reconnect() throws {
        disconnect()
        try connect()
    }

    private func disconnect() {
        sseConnection?.disconnect()
        sseConnection = nil
    }

    private func setupApplicationListener() {
        applicationListener.delegate = self
    }

    private func setupNetworkStatusListener() {
        do {
            try networkStatusListener.add(listener: self)
        } catch {
            logger.error("Can't add network status listener: \(error)")
        }
    }

    // MARK: Handlers

    private func handleOnOpen() {
        logger.debug("Successfully connected via sse")
    }

    private func handleOnComplete(status: Int?, shouldReconnect: Bool?, error: NSError?) {
        let statusString = String(describing: status)
        let shouldReconnectString = String(describing: shouldReconnect)
        let errorString = String(describing: error)
        let message = """
            Disconnected:
                status: \(statusString);
                recconect: \(shouldReconnectString);
                error: \(errorString);
        """

        logger.warning(message)

        if shouldReconnect == true {
            do {
                try reconnect()
            } catch {
                logger.error("Unexpected sse connection error \(error)")
            }
        } else {
            disconnect()
        }
    }

    private func handleEventWithId(_ identifier: String?, data: String?) {
        if let eventData = data?.data(using: .utf8) {
            logger.debug("sse event: \(String(describing: data))")
            eventHandler.didReceive(remoteEvent: eventData)
        }

        settings.lastStreamEventId = identifier
    }

    private func handleOutOfSync() {
        settings.lastStreamEventId = nil

        eventHandler.didReceiveSyncRequest()
    }
}

extension DataStreamConnectionManager: ApplicationHandlerDelegate {
    func didReceiveWillResignActive(notification: Notification) {
        disconnect()
    }

    func didReceiveDidBecomeActive(notification: Notification) {
        do {
            try reconnect()
        } catch {
            logger.error("Can't reconnect after became active: \(error)")
        }
    }
}

extension DataStreamConnectionManager: ReachabilityListenerDelegate {
    func didChangeReachability(by manager: ReachabilityManagerProtocol) {
        if manager.isReachable, sseConnection == nil {
            do {
                try reconnect()
            } catch {
                logger.error("Can't reconnect after receiver network connection: \(error)")
            }
        }
    }
}
