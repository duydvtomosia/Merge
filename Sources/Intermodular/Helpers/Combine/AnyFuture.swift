//
// Copyright (c) Vatsal Manot
//

import Combine
import Swift

/// A single-output publisher that performs type erasure by wrapping another single-output publisher.
public struct AnyFuture<Output, Failure: Error>: SingleOutputPublisher {
    public let base: AnyPublisher<Output, Failure>
    
    public func receive<S: Subscriber>(subscriber: S) where Failure == S.Failure, Output == S.Input {
        base.receive(subscriber: subscriber)
    }
}

// MARK: - API -

extension AnyFuture {
    public init<P: Publisher>(_unsafe publisher: P) where P.Output == Output, P.Failure == Failure {
        self.base = publisher.eraseToAnyPublisher()
    }
    
    public init<P: SingleOutputPublisher>(_ publisher: P) where P.Output == Output, P.Failure == Failure {
        self.base = publisher.eraseToAnyPublisher()
    }
}

extension Publisher {
    public func _unsafe_eraseToAnyFuture() -> AnyFuture<Output, Failure> {
        .init(_unsafe: self)
    }
}

extension SingleOutputPublisher {
    public func eraseToAnyFuture() -> AnyFuture<Output, Failure> {
        .init(self)
    }
}
