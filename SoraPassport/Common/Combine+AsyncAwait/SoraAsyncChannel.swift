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
import Combine

public enum SoraAsyncChannelErrors: Error {
    case concurrentAccess
    case outputToFinished
}

public final class SoraAsyncChannel<Output, Failure: Error>: Publisher, @unchecked Sendable {

    fileprivate typealias Conduit = AsyncSubscription<Output, Failure>

    private typealias Continuation = CheckedContinuation<Void, Error>
    private typealias Completion = Subscribers.Completion<Failure>

    private enum State {
        case idle
        case pending(Continuation, Output)
        case sending(Continuation)
        case waitForBackpressure(Continuation)
        case finished(Completion)
        case cancelled
    }

    private enum Event {
        case checkDemand
        case send(Continuation, Output)
        case sendComplete
        case cancel
        case finish(Completion)
    }

    private enum Action {
        case recheckDemand
        case resume(Continuation)
        case fail(Continuation, Error)
        case throwError(Error)
        case send(Output, Set<Conduit>)
        case finish(Completion, Set<Conduit>)
    }

    private let lock = NSRecursiveLock()

    private var subscriptions = Set<Conduit>()

    private var state = State.idle

    public init() {}
    public func send(_ value: Output) async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                try? handle(event: .send(continuation, value))
            }
        } onCancel: {
            try? handle(event: .cancel)
        }
    }

    public func send(completion: Subscribers.Completion<Failure>) throws {
        try handle(event: .finish(completion))
    }

    public func receive<S>(subscriber: S) where S: Subscriber, Failure == S.Failure, Output == S.Input {
        let state = lock.access { self.state }

        switch state {
        case let .finished(.failure(error)):
            subscriber.receive(completion: .failure(error))

        case .finished, .cancelled:
            subscriber.receive(completion: .finished)
            return

        default:
            break
        }

        let conduit = AsyncSubscription(subscriber: subscriber, channel: self)

        lock.access {
            subscriptions.insert(conduit)
        }

        subscriber.receive(subscription: conduit)
    }

    fileprivate func requestValue() {
        try? handle(event: .checkDemand)
    }

    fileprivate func subscriptionCancelled() {
        lock.access {
            subscriptions = subscriptions.filter({ !$0.isClosed })
        }

        try? handle(event: .checkDemand)
    }

    private var haveDemand: Bool {
        !subscriptions.isEmpty && subscriptions.allSatisfy { $0.haveDemand }
    }

    private func finishAction(with completion: Completion) -> Action {
        defer { subscriptions.removeAll() }
        return .finish(completion, subscriptions)
    }

    private func handle(event: Event) throws {
        let actions = process(event: event)

        for action in actions {
            switch action {
            case .recheckDemand:
                try handle(event: .checkDemand)

            case let .fail(continuation, error):
                continuation.resume(throwing: error)

            case let .send(output, subscriptions):
                for subscription in subscriptions {
                    subscription.send(input: output)
                }
                try handle(event: .sendComplete)

            case let .resume(continuation):
                continuation.resume()

            case let .finish(completion, subscriptions):
                for subscription in subscriptions {
                    subscription.send(completion: completion)
                }

            case let .throwError(error):
                throw error
            }
        }
    }

    private func process(event: Event) -> [Action] {
        defer { lock.unlock() }

        lock.lock()

        switch state {
        case .idle:
            switch event {
            case .checkDemand, .sendComplete:
                break

            case let .send(continuation, output):
                state = .pending(continuation, output)

                return [.recheckDemand]

            case .cancel:
                state = .cancelled

                return [finishAction(with: .finished)]

            case let .finish(completion):
                state = .finished(completion)

                return [finishAction(with: completion)]
            }

        case let .pending(continuation, output):
            switch event {
            case .checkDemand:
                if haveDemand {
                    state = .sending(continuation)
                    return [.send(output, subscriptions)]
                }

            case .sendComplete:
                break

            case let .send(newContinuation, _):
                return [.fail(newContinuation, SoraAsyncChannelErrors.concurrentAccess)]

            case .cancel:
                state = .cancelled

                return [finishAction(with: .finished), .fail(continuation, CancellationError())]

            case .finish:
                return [.throwError(SoraAsyncChannelErrors.concurrentAccess)]
            }

        case let .sending(continuation):
            switch event {
            case .checkDemand:
                break

            case .sendComplete:
                if haveDemand {
                    state = .idle

                    return [.resume(continuation)]
                } else {
                    state = .waitForBackpressure(continuation)
                }

            case let .send(newContinuation, _):
                return [.fail(newContinuation, SoraAsyncChannelErrors.concurrentAccess)]

            case .cancel:
                state = .cancelled

                return [finishAction(with: .finished), .fail(continuation, CancellationError())]

            case .finish:
                return [.throwError(SoraAsyncChannelErrors.concurrentAccess)]
            }

        case let .waitForBackpressure(continuation):
            switch event {
            case .checkDemand:
                if haveDemand {
                    state = .idle
                    return [.resume(continuation)]
                }

            case .sendComplete:
                break

            case let .send(newContinuation, _):
                return [.fail(newContinuation, SoraAsyncChannelErrors.concurrentAccess)]

            case .cancel:
                state = .cancelled

                return [finishAction(with: .finished), .fail(continuation, CancellationError())]

            case .finish:
                return [.throwError(SoraAsyncChannelErrors.concurrentAccess)]
            }

        case .cancelled:
            switch event {
            case .checkDemand, .sendComplete, .cancel, .finish:
                return [finishAction(with: .finished)]

            case let .send(continuation, _):
                return [.fail(continuation, CancellationError())]
            }

        case let .finished(completion):
            switch event {
            case .checkDemand, .sendComplete, .cancel:
                return [finishAction(with: completion)]

            case let .send(continuation, _):
                return [finishAction(with: completion), .fail(continuation, SoraAsyncChannelErrors.outputToFinished)]

            case .finish:
                return [finishAction(with: completion), .throwError(SoraAsyncChannelErrors.outputToFinished)]
            }
        }

        return []
    }
}

private class AsyncSubscription<Output, Failure: Error>: Subscription, Hashable {

    private enum State {
        case idle
        case haveDemand(Subscribers.Demand)
        case finished
    }

    private enum Event {
        case send(Output)
        case finish(Subscribers.Completion<Failure>)
        case receive(Subscribers.Demand)
        case cancel
    }

    private enum Action {
        case requestValue
        case sendValue(Output)
        case sendCompletion(Subscribers.Completion<Failure>)
        case notifyCancelled
    }
    
    private let sendValue: (Output) -> Subscribers.Demand
    private let sendCompletion: (Subscribers.Completion<Failure>) -> Void
    private weak var channel: SoraAsyncChannel<Output, Failure>?
    private var state = State.idle
    private let lock = NSLock()

    var haveDemand: Bool {
        defer { lock.unlock() }

        lock.lock()

        switch state {
        case .haveDemand:
            return true

        case .idle, .finished:
            return false
        }
    }

    var isClosed: Bool {
        defer { lock.unlock() }

        lock.lock()

        switch state {
        case .haveDemand, .idle:
            return false

        case .finished:
            return true
        }
    }

    init<S>(subscriber: S, channel: SoraAsyncChannel<Output, Failure>) where S: Subscriber, Failure == S.Failure, Output == S.Input {
        self.sendValue = { subscriber.receive($0) }
        self.sendCompletion = { subscriber.receive(completion: $0) }
        self.channel = channel
    }

    func send(input: Output) {
        handle(event: .send(input))
    }

    func send(completion: Subscribers.Completion<Failure>) {
        handle(event: .finish(completion))
    }

    func request(_ demand: Subscribers.Demand) {
        handle(event: .receive(demand))
    }

    func cancel() {
        handle(event: .cancel)
    }

    static func == (lhs: AsyncSubscription<Output, Failure>, rhs: AsyncSubscription<Output, Failure>) -> Bool {
        lhs === rhs
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }

    private func handle(event: Event) {
        let actions = process(event: event)

        for action in actions {
            switch action {
            case .requestValue:
                channel?.requestValue()

            case let .sendValue(output):
                let demand = sendValue(output)

                if demand != .none {
                    handle(event: .receive(demand))
                }

            case .notifyCancelled:
                channel?.subscriptionCancelled()

            case let .sendCompletion(completion):
                sendCompletion(completion)
            }
        }
    }

    private func process(event: Event) -> [Action] {
        defer { lock.unlock() }

        lock.lock()

        switch state {
        case .idle:
            switch event {
            case .send:
                break

            case let .receive(demand):
                state = .haveDemand(demand)

                return [.requestValue]

            case .cancel:
                state = .finished

                return [.notifyCancelled]

            case let .finish(completion):
                state = .finished

                return [.sendCompletion(completion), .notifyCancelled]
            }

        case let .haveDemand(demand):
            switch event {
            case let .send(output):
                let newDemand = demand - .max(1)

                if newDemand == .none {
                    state = .idle

                    return [.sendValue(output)]
                } else {
                    state = .haveDemand(newDemand)

                    return [.sendValue(output), .requestValue]
                }

            case let .receive(newDemand):
                state = .haveDemand(demand + newDemand)

            case .cancel:
                state = .finished

                return [.notifyCancelled]

            case let .finish(completion):
                state = .finished

                return [.sendCompletion(completion), .notifyCancelled]
            }

        case .finished:
            return [.notifyCancelled]
        }

        return []
    }
}

private extension NSRecursiveLock {

    @discardableResult
    func access<T>(_ executionBlock: () -> T) -> T {
        defer { unlock() }

        lock()

        return executionBlock()
    }
}
