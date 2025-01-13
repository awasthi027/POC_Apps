//
//  MyOwnMicroMacros.swift
//  MyOwnMicro
//
//  Created by Ashish Awasthi on 11/01/25.
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct BuildDateMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) -> ExprSyntax {
        let date = ISO8601DateFormatter().string(from: .now)
        return "\"\(raw: date)\""
    }
}

@main
struct MyMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        BuildDateMacro.self
    ]
}
