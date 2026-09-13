//
//  ContentView.swift
//  MacOSConcepts
//
//  Created by Ashish Awasthi on 27/08/26.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var result = "No image parsed yet"

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo")
                .imageScale(.large)
                .foregroundStyle(.tint)

            Text(result)

            Button("Choose Image & Parse via XPC") {
                pickAndParseImage()
            }
        }
        .padding()
        .frame(minWidth: 320, minHeight: 160)
    }

    private func pickAndParseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK,
              let url = panel.url,
              let data = try? Data(contentsOf: url) else { return }

        result = "Parsing…"
        ImageParserXPCDemo.parseImage(
            data,
            onCrash: {
                result = "Parser service crashed — app kept running"
            },
            completion: { width, height in
                DispatchQueue.main.async {
                    result = width > 0 ? "Parsed: \(width) x \(height) px" : "Could not parse image"
                }
            }
        )
    }
}

#Preview {
    ContentView()
}
