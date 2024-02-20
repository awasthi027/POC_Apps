//
//  File.swift
//  
//
//  Created by Ashish Awasthi on 20/02/24.
//

import Foundation
import ArgumentParser

struct CLIPOC: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "CommandLineTool adds colour to text using Console Escape Sequences",
        version: "1.0.0",
        subcommands: [ChangeTextColor.self, CreateNotes.self])

    init() { }
}
