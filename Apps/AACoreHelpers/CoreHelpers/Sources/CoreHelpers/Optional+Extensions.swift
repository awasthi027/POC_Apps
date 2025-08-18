//
//  File.swift
//  CoreHelpers
//
//  Created by Ashish Awasthi on 12/08/25.
//


import Foundation

infix operator ??=
public extension Optional {
    static func ??= (left: inout Optional, right: Optional) {
        left = right ?? left
    }

    static func ??= (left: inout Wrapped, right: Optional) {
        left = right ?? left
    }

    func pair<NewWrapped>(with new: Optional<NewWrapped>) -> Optional<(Wrapped, NewWrapped)> {
        self.flatMap { wrapped in
            new.flatMap { newWrapped in
                (wrapped, newWrapped)
            }
        }
    }

    struct Nil: Swift.Error, CustomStringConvertible {

        let file: String
        let line: Int
        let column: Int
        let function: String

        public var description: String {
            """
            \n
            \t<file>    : \(URL(fileURLWithPath: file).lastPathComponent)
            \t<line>    : \(self.line)
            \t<colunm>  : \(self.column)
            \t<function>: \(self.function)
            \n
            """
        }
    }

    typealias Result = Swift.Result<Wrapped, Error>

    func unwrap(or throwError: @autoclosure () -> Error) throws -> Wrapped {
        switch self {
            case .some(let wrapped): return wrapped
            case .none: throw throwError()
        }
    }

    func unwrap(or throwError: @autoclosure () -> Error) -> Result {
        .init {
            try self.unwrap(or: throwError())
        }
    }

    func unwrap(
        file: String = #file,
        line: Int = #line,
        column: Int = #column,
        function: String = #function
    ) throws -> Wrapped {
        try self.unwrap(or: Self.Nil(file: file, line: line, column: column, function: function))
    }

    func unwrap(
        file: String = #file,
        line: Int = #line,
        column: Int = #column,
        function: String = #function
    ) -> Result {
        self.unwrap(or: Self.Nil(file: file, line: line, column: column, function: function))
    }

    @discardableResult
    func onPresent(
        file: String = #file,
        line: Int = #line,
        column: Int = #column,
        function: String = #function,
        onQueue queue: DispatchQueue? = nil,
        _ onPresent: @escaping (Wrapped) -> Swift.Void,
        onNil: @escaping (Error) -> Swift.Void
    ) -> Self {
        let result: Result = self.unwrap(
            file: file,
            line: line,
            column: column,
            function: function
        )

        let execute: () -> Swift.Void
        switch result {
            case .failure(let error):
                execute = { onNil(error) }
            case .success(let wrapped):
                execute = { onPresent(wrapped) }
        }

        queue.mapOnNil(execute) {
            $0.async(execute: execute)
        }

        return self
    }

    @discardableResult
    func onPresent(
        file: String = #file,
        line: Int = #line,
        column: Int = #column,
        function: String = #function,
        queue: DispatchQueue? = nil,
        _ onPresent: @escaping (Wrapped) -> Swift.Void
    ) -> Self {
        self.onPresent(
            file: file,
            line: line,
            column: column,
            function: function,
            onQueue: queue,
            onPresent
        ) { error in
//            log(warning: "Object of \(type(of: Wrapped.self)) becomes nil unexpectedly: \(error)")
        }
    }

    @discardableResult
    func onNil(
        file: String = #file,
        line: Int = #line,
        column: Int = #column,
        function: String = #function,
        onQueue queue: DispatchQueue? = nil,
        _ onNil: @escaping (Error) -> Swift.Void,
        onPresent: @escaping (Wrapped) -> Swift.Void = { _ in /* Do nothing by default */ }
    ) -> Self {
        self.onPresent(
            file: file,
            line: line,
            column: column,
            function: function,
            onQueue: queue,
            onPresent,
            onNil: onNil
        )
    }

    @discardableResult
    func mapOnNil<New>(
        _ onNil: () throws -> New,
        onPresent: (Wrapped) throws -> New
    ) rethrows -> New {
        try self.map(onPresent) ?? onNil()
    }

    @discardableResult
    func mapOnNil<New>(
        _ onNil: @autoclosure () throws -> New,
        onPresent: (Wrapped) throws -> New
    ) rethrows -> New {
        try self.mapOnNil(onNil, onPresent: onPresent)
    }

}
