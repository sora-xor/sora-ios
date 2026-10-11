import Foundation
import Starscream

extension WebSocketEngine: JSONRPCEngine {
    public var pendingEngineRequests: [JSONRPCRequest] {
        pendingRequests
    }

    public func callMethod<P: Codable, T: Decodable>(
        _ method: String,
        params: P?,
        options: JSONRPCOptions,
        completion closure: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let request = try prepareRequest(
            method: method,
            params: params,
            options: options,
            completion: closure
        )

        updateConnectionForRequest(request)

        return request.requestId
    }

    public func subscribe<P: Codable, T: Decodable>(
        _ method: String,
        params: P?,
        updateClosure: @escaping (T) -> Void,
        failureClosure: @escaping (Error, Bool) -> Void
    ) throws -> UInt16 {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let completion: ((Result<String, Error>) -> Void)? = nil

        let request = try prepareRequest(
            method: method,
            params: params,
            options: JSONRPCOptions(resendOnReconnect: true),
            completion: completion
        )

        let subscription = JSONRPCSubscription(
            requestId: request.requestId,
            requestData: request.data,
            requestOptions: request.options,
            updateClosure: updateClosure,
            failureClosure: failureClosure
        )

        addSubscription(subscription)

        updateConnectionForRequest(request)

        return request.requestId
    }

    public func cancelForIdentifier(_ identifier: UInt16) {
        mutex.lock()

        cancelRequestForLocalId(identifier)

        mutex.unlock()
    }

    public func reconnect(url: URL) {
        // Let go of the old socket for good: stop listening to it and cancel
        // its TCP connection, also when it is still connecting.
        let previous = self.connection
        previous.delegate = nil
        previous.forceDisconnect()

        self.url = url
        let request = URLRequest(url: url, timeoutInterval: 10)
        // The new node gets a transport and a handshake of its own. The
        // Starscream engine keeps one TCP connection, the handshake key and
        // the "upgraded" flag. When it was reused for another node, events of
        // the old connection (a refusal that arrives late, a second answer to
        // the upgrade request) were taken for the new one, and the switch to
        // a working node failed several times over with "accept header
        // doesn't match" or "notAnUpgrade" before it succeeded.
        let engine = WSEngine(transport: TCPTransport(), certPinner: FoundationSecurity())

        let connection = WebSocket(request: request, engine: engine)
        self.connection = connection

        connection.callbackQueue = Self.sharedProcessingQueue
        connection.delegate = self
    }
}
