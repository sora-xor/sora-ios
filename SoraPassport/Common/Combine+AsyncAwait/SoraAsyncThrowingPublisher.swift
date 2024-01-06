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

public struct SoraAsyncThrowingPublisher<P: Publisher>: AsyncSequence, @unchecked Sendable {

    public typealias Element = P.Output

    public typealias AsyncIterator = SoraAsyncThrowingPublisher<P>.Iterator

    public struct Iterator: AsyncIteratorProtocol, Sendable {

        public typealias Element = P.Output

        private let innerHandler: InnerClass<P>

        init(publisher: P) {
            innerHandler = InnerClass(publisher: publisher)
        }

        public mutating func next() async throws -> Element? {
            try await innerHandler.next()
        }
    }

    private let publisher: P

    public init(_ publisher: P) {
        self.publisher = publisher
    }

    public func makeAsyncIterator() -> AsyncIterator {
        Iterator(publisher: publisher)
    }
}

public struct SoraAsyncPublisher<P: Publisher>: AsyncSequence, @unchecked Sendable where P.Failure == Never {

    public typealias Element = P.Output

    public typealias AsyncIterator = SoraAsyncPublisher<P>.Iterator

    public struct Iterator: AsyncIteratorProtocol, Sendable {

        public typealias Element = P.Output

        private let innerHandler: InnerClass<P>

        init(publisher: P) {
            innerHandler = InnerClass(publisher: publisher)
        }

        public mutating func next() async -> Element? {
            try? await innerHandler.next()
        }
    }

    private let publisher: P

    public init(_ publisher: P) {
        self.publisher = publisher
    }

    public func makeAsyncIterator() -> AsyncIterator {
        Iterator(publisher: publisher)
    }
}

fileprivate final class InnerClass<P: Publisher>: @unchecked Sendable {

    let innerSubscriber: InnerSubscriber<P>

    init(publisher: P) {
        innerSubscriber = InnerSubscriber(publisher: publisher)
    }

    deinit {
        innerSubscriber.finish()
    }

    func next() async throws -> P.Output? {
        try await innerSubscriber.next()
    }
}

fileprivate final class InnerSubscriber<P: Publisher>: Subscriber, @unchecked Sendable {

    public typealias Input = P.Output

    public typealias Failure = P.Failure

    private typealias CompletionClosure = (Result<Input?, Error>) -> Void

    private enum State {
        case idle
        case waitingForSubscription(having: CompletionClosure)
        case waitingForConsume(having: Subscription)
        case waitingForInput(from: Subscription, to: CompletionClosure)
        case finishing(with: Subscribers.Completion<Failure>)
        case canceled
        case completed
    }

    private enum Event {
        case consume(CompletionClosure)
        case didReceiveCancel
        case didReceiveCompletion(Subscribers.Completion<Failure>)
        case didReceiveInput(Input)
        case didReceiveSubscription(Subscription)
    }

    private enum Action {
        case send(Input, to: CompletionClosure)
        case request(Subscription)
        case finish(CompletionClosure, with: Subscribers.Completion<Failure>)
        case cancel(Subscription)
        case none
    }

    private var currentState: State = .idle

    private let lock = NSLock()

    init(publisher: P) {
        publisher.subscribe(self)
    }

    func next() async throws -> Input? {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingCancellableContinuation { completion in
                handle(event: .consume(completion))

                return nil
            }
        } onCancel: {
            handle(event: .didReceiveCancel)
        }
    }

    func finish() {
        handle(event: .didReceiveCancel)
    }

    func receive(subscription: Subscription) {
        handle(event: .didReceiveSubscription(subscription))
    }

    func receive(_ input: Input) -> Subscribers.Demand {
        handle(event: .didReceiveInput(input))

        return .none
    }

    func receive(completion: Subscribers.Completion<Failure>) {
        handle(event: .didReceiveCompletion(completion))
    }

    private func process(event: Event) -> Action {
        defer { lock.unlock() }
        lock.lock()

        switch currentState {
        case .idle:
            switch event {
            case let .consume(completionClosure):
                currentState = .waitingForSubscription(having: completionClosure)

            case let .didReceiveSubscription(subscription):
                currentState = .waitingForConsume(having: subscription)

            case .didReceiveCancel:
                currentState = .canceled

            case let .didReceiveCompletion(completion):
                currentState = .finishing(with: completion)

            default:
                break
            }

        case let .waitingForSubscription(having: completionClosure):
            switch event {
            case let .didReceiveSubscription(subscription):
                currentState = .waitingForInput(from: subscription, to: completionClosure)
                return .request(subscription)

            case .didReceiveCancel:
                currentState = .canceled

            case let .didReceiveCompletion(completion):
                currentState = .completed
                return .finish(completionClosure, with: completion)

            default:
                break
            }

        case let .waitingForInput(from: subscription, to: completionClosure):
            switch event {
            case let .didReceiveInput(input):
                currentState = .waitingForConsume(having: subscription)
                return .send(input, to: completionClosure)

            case let .didReceiveCompletion(completion):
                currentState = .completed
                return .finish(completionClosure, with: completion)

            case .didReceiveCancel:
                currentState = .canceled
                return .cancel(subscription)

            default:
                break
            }

        case let .waitingForConsume(having: subscription):
            switch event {
            case let .consume(completionClosure):
                currentState = .waitingForInput(from: subscription, to: completionClosure)
                return .request(subscription)

            case let .didReceiveCompletion(completion):
                currentState = .finishing(with: completion)

            case .didReceiveCancel:
                currentState = .canceled
                return .cancel(subscription)

            default:
                break
            }

        case let .finishing(with: completion):
            switch event {
            case let .consume(completionClosure):
                currentState = .completed
                return .finish(completionClosure, with: completion)

            case .didReceiveCancel:
                currentState = .canceled

            default:
                break
            }

        case .canceled:
            switch event {
            case let .didReceiveSubscription(subscription):
                return .cancel(subscription)

            default:
                break
            }

        case .completed:
            break
        }

        return .none
    }

    private func handle(event: Event) {
        let action = process(event: event)

        switch action {
        case let .send(element, to: completionClosure):
            completionClosure(.success(element))

        case let .request(subscription):
            subscription.request(.max(1))

        case let .finish(completionClosure, with: completion):
            switch completion {
            case .finished:
                completionClosure(.success(nil))

            case let .failure(error):
                completionClosure(.failure(error))
            }

        case let .cancel(subscription):
            subscription.cancel()

        case .none:
            break
        }
    }
}

extension Publisher {
    public var asyncValues: SoraAsyncThrowingPublisher<Self> {
        SoraAsyncThrowingPublisher(self)
    }
}

extension Publisher where Self.Failure == Never {
    public var asyncValues: SoraAsyncPublisher<Self> {
        SoraAsyncPublisher(self)
    }
}
