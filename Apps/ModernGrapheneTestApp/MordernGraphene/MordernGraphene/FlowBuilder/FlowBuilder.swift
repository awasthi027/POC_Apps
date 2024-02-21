//
//  FlowBuilder.swift
//  MordernGraphene
//
//  Created by Ashish Awasthi on 02/02/24.
//

//import Foundation
//
///// The fundamental currency of @Flow expressions. FlowResult is a RawRepresentable over `Bool`
///// This definition imparts an inescapable "pass/fail" semantic over all @Flow expressions.
///// All implementations of FlowResult are required to return a non-null instance in response to .init(rawValue: false)
///// N.B. Graphene will _never_ initialize a `FlowResult` with a `true` raw value.
//public protocol FlowResult: RawRepresentable where RawValue == Bool {}
//
////func noTraceFlow<R: FlowResult>(function: StaticString = #function, @Flow _ content: () -> R) -> R {
////    GrapheneFlow.noTraceFunction = function
////    return content()
////}
