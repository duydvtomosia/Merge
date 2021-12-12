//
// Copyright (c) Vatsal Manot
//

import Combine
import Swift
import SwiftUIX

/// An button that represents a `Task`.
public struct TaskButton<Success, Error: Swift.Error, Label: View>: View {
    private let action: () -> AnyTask<Success, Error>?
    private let label: (TaskStatus<Success, Error>) -> Label
    
    @OptionalEnvironmentObject private var taskPipeline: TaskPipeline?
    @OptionalObservedObject private var currentTask: AnyTask<Success, Error>?
    
    @Environment(\._taskButtonStyle) private var buttonStyle
    @Environment(\.cancellables) private var cancellables
    @Environment(\.customTaskIdentifier) private var customTaskIdentifier
    @Environment(\.handleLocalizedError) private var handleLocalizedError
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.taskDisabled) private var taskDisabled
    @Environment(\.taskInterruptible) private var taskInterruptible
    @Environment(\.taskRestartable) private var taskRestartable
    
    @State private var taskRenewalSubscription: AnyCancellable?
    
    public var body: some View {
        Button(action: trigger) {
            buttonStyle._opaque_makeBody(
                configuration: TaskButtonConfiguration(
                    label: label(task?.status ?? .idle).eraseToAnyView(),
                    isDisabled: taskDisabled,
                    isInterruptible: taskInterruptible,
                    isRestartable: taskRestartable,
                    status: taskStatusDescription,
                    lastStatus: lastTaskStatusDescription
                )
            )
        }
        .disabled(
            false
                || !isEnabled
                || taskDisabled
                || (currentTask?.status == .finished && !taskRestartable)
        )
    }
    
    private var task: AnyTask<Success, Error>? {
        if let currentTask = currentTask {
            return currentTask
        } else if let customTaskIdentifier = customTaskIdentifier, let task = taskPipeline?[customTaskIdentifier: customTaskIdentifier] as? AnyTask<Success, Error> {
            return task
        } else {
            return nil
        }
    }
    
    private var taskStatusDescription: TaskStatusDescription {
        return task?.statusDescription
            ?? customTaskIdentifier.flatMap({ taskPipeline?.lastStatus(forCustomTaskIdentifier: $0) })
            ?? .idle
    }
    
    private var lastTaskStatusDescription: TaskStatusDescription? {
        customTaskIdentifier.flatMap({ taskPipeline?.lastStatus(forCustomTaskIdentifier: $0) })
    }
    
    private func trigger() {
        if !taskRestartable && currentTask != nil {
            return
        }
        
        acquireTaskIfNecessary()
    }
    
    private func subscribe(to task: AnyTask<Success, Error>) {
        currentTask = task

        task.objectWillChange.sink(
            in: taskPipeline?.cancellables ?? cancellables
        ) { status in
            self.buttonStyle.receive(status: .init(description: TaskStatusDescription(status)))
            
            if case let .error(error) = status {
                handleLocalizedError(error as? LocalizedError ?? GenericTaskButtonError(base: error))
            }
        }
        
        if task.status == .idle {
            task.start()
        }
    }
    
    private func acquireTaskIfNecessary() {
        if taskInterruptible {
            if let task = action() {
                return subscribe(to: task)
            }
        }
        
        if let customTaskIdentifier = customTaskIdentifier, let taskPipeline = taskPipeline, let task = taskPipeline[customTaskIdentifier: customTaskIdentifier] as? AnyTask<Success, Error> {
            currentTask = task
        } else {
            if let task = action() {
                subscribe(to: task)
            } else {
                currentTask = nil
            }
        }
    }
}

// MARK: - Initializers -

extension TaskButton {
    public init(
        action: @escaping () -> AnyTask<Success, Error>,
        @ViewBuilder label: @escaping (TaskStatus<Success, Error>) -> Label
    ) {
        self.action = { action() }
        self.label = label
    }
    
    public init(
        action: @escaping () -> AnyTask<Success, Error>,
        @ViewBuilder label: () -> Label
    ) {
        let _label = label()
        
        self.action = { action() }
        self.label = { _ in _label }
    }
}

extension TaskButton {
    public init<P: SingleOutputPublisher>(
        action: @escaping () -> P,
        @ViewBuilder label: @escaping (TaskStatus<Success, Error>) -> Label
    ) where P.Output == Success, P.Failure == Error {
        self.init(action: { action().convertToTask() }, label: label)
    }
    
    public init<P: SingleOutputPublisher>(
        action: @escaping () -> P,
        @ViewBuilder label: () -> Label
    ) where P.Output == Success, P.Failure == Error {
        self.init(action: { action().convertToTask() }, label: label)
    }
    
    public init<P: SingleOutputPublisher>(
        action: @escaping () throws -> P,
        @ViewBuilder label: () -> Label
    ) where P.Output == Success, Error == Swift.Error {
        self.init {
            do {
                return try action().mapError({ $0 as Swift.Error }).convertToTask()
            } catch {
                return AnyTask<Success, Error>.failure(error)
            }
        } label: {
            label()
        }
    }
}

extension TaskButton where Success == Void {
    public init<P: Publisher>(
        action: @escaping () -> P,
        @ViewBuilder label: @escaping (TaskStatus<Success, Error>) -> Label
    ) where P.Output == Success, P.Failure == Error {
        self.init(action: { action().reduceAndMapTo(()).convertToTask() }, label: label)
    }
    
    public init<P: Publisher>(
        action: @escaping () -> P,
        @ViewBuilder label: () -> Label
    ) where P.Output == Success, P.Failure == Error {
        self.init(action: { action().reduceAndMapTo(()).convertToTask() }, label: label)
    }
    
    public init<P: SingleOutputPublisher>(
        action: @escaping () -> P,
        @ViewBuilder label: @escaping (TaskStatus<Success, Error>) -> Label
    ) where P.Output == Success, P.Failure == Error {
        self.init(action: { action().reduceAndMapTo(()).convertToTask() }, label: label)
    }
    
    public init<P: SingleOutputPublisher>(
        action: @escaping () -> P,
        @ViewBuilder label: () -> Label
    ) where P.Output == Success, P.Failure == Error {
        self.init(action: { action().reduceAndMapTo(()).convertToTask() }, label: label)
    }
}


extension TaskButton where Label == Text {
    public init(
        _ titleKey: LocalizedStringKey,
        action: @escaping () -> AnyTask<Success, Error>
    ) {
        self.init(action: action) {
            Text(titleKey)
        }
    }
    
    public init<S: StringProtocol>(
        _ title: S,
        action: @escaping () -> AnyTask<Success, Error>
    ) {
        self.init(action: action) {
            Text(title)
        }
    }
    
    public init<S: StringProtocol, P: SingleOutputPublisher>(
        _ title: S,
        action: @escaping () throws -> P
    ) where P.Output == Success, Error == Swift.Error {
        self.init(action: action) {
            Text(title)
        }
    }
}

extension TaskButton where Success == Void, Error == Swift.Error {
    public init(
        action: @escaping () throws -> Void,
        @ViewBuilder label: @escaping (TaskStatus<Success, Error>) -> Label
    ) {
        self.init(
            action: { () -> AnySingleOutputPublisher<Void, Error> in
                do {
                    return Just(try action())
                        .setFailureType(to: Error.self)
                        .eraseToAnySingleOutputPublisher()
                } catch {
                    return Fail(error: error)
                        .eraseToAnySingleOutputPublisher()
                }
            },
            label: label
        )
    }
    
    public init(
        action: @escaping () throws -> Void,
        @ViewBuilder label: () -> Label
    ) {
        let label = label()
        
        self.init(action: action, label: { _ in label })
    }
}

// MARK: - Conformances -

extension TaskButton: ActionLabelView where Error == Swift.Error, Success == Void {
    public init(action: Action, label: () -> Label) {
        self.init(action: action.perform, label: label)
    }
}

// MARK: - Auxiliary Implementation -

struct GenericTaskButtonError: LocalizedError {
    let base: Swift.Error
}

extension EnvironmentValues {
    public var customTaskIdentifier: AnyHashable? {
        get {
            self[DefaultEnvironmentKey<AnyHashable>.self]
        } set {
            self[DefaultEnvironmentKey<AnyHashable>.self] = newValue
        }
    }
}

// MARK: - API -

extension View {
    public func customTaskIdentifier(_ name: AnyHashable) -> some View {
        environment(\.customTaskIdentifier, name)
    }
    
    public func customTaskIdentifier<H: Hashable>(_ name: H) -> some View {
        customTaskIdentifier(.init(name))
    }
}