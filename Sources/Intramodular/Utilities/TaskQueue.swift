//
// Copyright (c) Vatsal Manot
//

import Combine
import Swallow

public final class TaskQueue: Sendable {
    public enum Policy: Sendable {
        case cancelPreviousAction
        case waitOnPreviousAction
    }
    
    private let queue: _Queue
    
    public init(policy: Policy = .waitOnPreviousAction) {
        self.queue = .init(policy: policy)
    }
    
    /// Spawns a task to add an action to perform.
    ///
    /// This method can be called from a synchronous context.
    ///
    /// - Parameters:
    ///   - action: An async function to execute.
    public func add<T: Sendable>(
        _ action: @Sendable @escaping () async throws -> T
    ) {
        Task {
            await queue.add(action)
        }
    }
    
    /// Performs an action right after the previous action has been finished.
    ///
    /// - Parameters:
    ///   - action: An async function to execute. The function may throw and return a value.
    /// - Throws: The error thrown by `action`. Especially throws `CancellationError` if the parent task has been cancelled.
    /// - Returns: The return value of `action`
    public func perform<T: Sendable>(
        operation: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        if queue.policy == .cancelPreviousAction {
            TODO.unimplemented
        }
        
        guard TaskQueue.queueID != queue.id else {
            return try await operation()
        }

        let semaphore = AsyncSemaphore()
        
        let resultBox = ReferenceBox<Result<T, Error>?>(nil)
        
        await semaphore.wait()
        
        add {
            do {
                resultBox.wrappedValue = try await .success(operation())
            } catch {
                resultBox.wrappedValue = .failure(error)
            }
            
            await semaphore.signal()
        }
        
        return try await semaphore.withCriticalScope {
            return try resultBox.wrappedValue!.get()
        }
    }
}

extension TaskQueue {
    private actor _Queue: Sendable {
        let id: AnyHashable = UUID()
        
        let policy: Policy
        var previousTask: OpaqueTask? = nil
        
        init(policy: Policy) {
            self.policy = policy
        }
        
        func add<T: Sendable>(
            _ action: @Sendable @escaping () async throws -> T
        ) -> Task<T, Error> {
            guard TaskQueue.queueID != id else {
                fatalError()
            }

            let policy = self.policy
            let previousTask = self.previousTask
            
            let newTask = Task { () async throws -> T in
                if let previousTask = previousTask {
                    if policy == .cancelPreviousAction {
                        previousTask.cancel()
                    }
                    
                    _ = try? await previousTask.value
                }
                
                try Task.checkCancellation()
                                
                return try await TaskQueue.$queueID.withValue(id) {
                    try await action()
                }
            }
            
            self.previousTask = OpaqueTask(erasing: newTask)
            
            return newTask
        }
    }
}

extension TaskQueue {
    @TaskLocal
    private static var queueID: AnyHashable?
}