import Foundation
import Reachability

public protocol ReachabilityListenerDelegate: AnyObject {
    func didChangeReachability(by manager: ReachabilityManagerProtocol)
}

public protocol ReachabilityManagerProtocol {
    var isReachable: Bool { get }

    func add(listener: ReachabilityListenerDelegate) throws
    func remove(listener: ReachabilityListenerDelegate)
}

private final class ReachabilityListenerWrapper {
    weak var listener: ReachabilityListenerDelegate?

    init(listener: ReachabilityListenerDelegate) {
        self.listener = listener
    }
}

public final class ReachabilityManager {
    public static let shared: ReachabilityManager? = ReachabilityManager()

    private var listeners: [ReachabilityListenerWrapper] = []
    private let listenersLock = NSLock()
    private let notifierLock = NSLock()
    private var reachability: Reachability

    init?() {
        guard let newReachability = try? Reachability() else {
            return nil
        }

        reachability = newReachability

        reachability.whenReachable = { [weak self] _ in
            self?.notifyListeners()
        }

        reachability.whenUnreachable = { [weak self] _ in
            self?.notifyListeners()
        }
    }

    private func withListenersLock<T>(_ body: () throws -> T) rethrows -> T {
        listenersLock.lock()
        defer { listenersLock.unlock() }
        return try body()
    }

    private func addListenerIfNeeded(_ listener: ReachabilityListenerDelegate) -> Bool {
        withListenersLock {
            listeners = listeners.filter { $0.listener != nil }
            guard !listeners.contains(where: { $0.listener === listener }) else {
                return false
            }
            listeners.append(ReachabilityListenerWrapper(listener: listener))
            return true
        }
    }

    private func removeListener(_ listener: ReachabilityListenerDelegate) {
        withListenersLock {
            listeners = listeners.filter {
                $0.listener != nil && $0.listener !== listener
            }
        }
    }

    private func hasLiveListeners() -> Bool {
        withListenersLock {
            listeners = listeners.filter { $0.listener != nil }
            return !listeners.isEmpty
        }
    }

    private func liveListenersSnapshot() -> [ReachabilityListenerDelegate] {
        withListenersLock {
            listeners = listeners.filter { $0.listener != nil }
            return listeners.compactMap { $0.listener }
        }
    }

    func notifyListeners() {
        let liveListeners = liveListenersSnapshot()
        liveListeners.forEach { $0.didChangeReachability(by: self) }
    }
}

extension ReachabilityManager: ReachabilityManagerProtocol {
    public var isReachable: Bool {
        reachability.connection != .unavailable
    }

    public func add(listener: ReachabilityListenerDelegate) throws {
        let didAddListener = addListenerIfNeeded(listener)

        notifierLock.lock()
        defer { notifierLock.unlock() }
        guard hasLiveListeners() else {
            return
        }
        do {
            try reachability.startNotifier()
        } catch {
            if didAddListener {
                removeListener(listener)
            }
            throw error
        }
    }

    public func remove(listener: ReachabilityListenerDelegate) {
        removeListener(listener)

        notifierLock.lock()
        defer { notifierLock.unlock() }
        if !hasLiveListeners() {
            reachability.stopNotifier()
        }
    }
}
