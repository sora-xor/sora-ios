import Foundation

public class SCStream<Value>: Sendable {

    public var stream: AsyncStream<Value> {
        let (stream, continuation) = AsyncStream<Value>.streamWithContinuation()
        continuation.yield(wrappedValue)
        continuations.append(continuation)
        return stream
    }

    public var wrappedValue: Value {
        didSet {
            _ = continuations.map { $0.yield(wrappedValue) }
        }
    }

    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    public func finishAll() {
        _ = continuations.map { $0.finish() }
    }

    deinit {
        finishAll()
    }

    private var continuations: [AsyncStream<Value>.Continuation] = []
}

extension AsyncStream {
    public static func streamWithContinuation() -> (stream: AsyncStream, continuation: AsyncStream.Continuation) {
        var continuation: AsyncStream.Continuation!
        let stream = self.init { innerContinuation in
            continuation = innerContinuation
        }
        // TODO: AsyncStream.makeStream
        return (stream, continuation)
    }
}

extension AsyncStream {
    public func map<Transformed>(_ transform: @escaping (Self.Element) -> Transformed) -> AsyncStream<Transformed> {
        return AsyncStream<Transformed> { continuation in
            Task {
                for await element in self {
                    continuation.yield(transform(element))
                }
                continuation.finish()
            }
        }
    }

    public func map<Transformed>(_ transform: @escaping (Self.Element) async -> Transformed) -> AsyncStream<Transformed> {
        return AsyncStream<Transformed> { continuation in
            Task {
                for await element in self {
                    continuation.yield(await transform(element))
                }
                continuation.finish()
            }
        }
    }
}
