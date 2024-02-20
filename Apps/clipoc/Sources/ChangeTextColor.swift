//
//  ChangeTextColor.swift
//
//
//  Created by Ashish Awasthi on 19/02/24.
//

import Foundation
import ArgumentParser

struct ChangeTextColor: ParsableCommand {

    static var configuration = CommandConfiguration(
        commandName: "changecolor",
        abstract: "CommandLineTool adds colour to text using Console Escape Sequences",
        version: "1.0.0")

    enum Colour: Int {
        case red    = 31
        case green  = 32
    }

    @Argument(help: "text to colour.")
    var text: String

    @Flag(inversion: .prefixedNo)
    var good = true

    mutating func run() throws {

        var colour = Colour.green.rawValue
        if !good {
            colour = Colour.red.rawValue
        }
        let colouredText = "\u{1B}[\(colour)m\(text)\u{1B}[0m"
        print(colouredText)
    }
}



