//
// Copyright (c) Vatsal Manot
//

import Combine
import Swift

public struct TaskSuccessPublisher<Upstream: TaskProtocol>: Publisher {
    public typealias Output = Upstream.Success
    public typealias Failure = Upstream.Failure
    
    private let upstream: Upstream
    
    public init(upstream: Upstream) {
        self.upstream = upstream
    }
    
    public func receive<S: Subscriber>(
        subscriber: S
    ) where S.Input == Output, S.Failure == Failure {
        upstream
            .compactMap({ $0.successValue })
            .receive(subscriber: subscriber)
    }
}

// MARK: - API -

extension TaskProtocol {
    public var successPublisher: TaskSuccessPublisher<Self> {
        TaskSuccessPublisher(upstream: self)
    }
}
