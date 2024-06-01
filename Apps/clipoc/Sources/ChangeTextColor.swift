//
//  ChangeTextColor.swift
//
//
//  Created by Ashish Awasthi on 19/02/24.
//
// https://rderik.com/blog/understanding-the-swift-argument-parser-and-working-with-stdin/

import Foundation
import ArgumentParser

struct ChangeTextColor: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "changecolor",
        abstract: "Colorico adds colour to text using Console Escape Sequences",
        version: "1.0.0"
    )

    enum Colour: Int {
        case red    = 31
        case green  = 32
    }

    @Argument(help: "text to colour.")
    var text: String

    @Flag(inversion: .prefixedNo)
    var good = true

    @Option(name: [.customShort("o"), .long], help: "name of output file(the command only writes to current directory)")
    var outputFile: String?


    func run() throws {
        var colour = Colour.green.rawValue
        if !good {
            colour = Colour.red.rawValue
        }
        let colouredText = "\u{1B}[\(colour)m\(text)\u{1B}[0m"
        if let outputFile = outputFile {
            let path = FileManager.default.currentDirectoryPath

            //Lets prevent any directory traversal
            let filename = URL(fileURLWithPath: outputFile).lastPathComponent
            let fullFilename = URL(fileURLWithPath: path).appendingPathComponent(filename)
            try colouredText.write(to: fullFilename, atomically: true, encoding: String.Encoding.utf8)
        } else {
            print(colouredText)
        }

    }
}



