//
//  ContentView.swift
//  ScreenProtectorSwiftUI
//
//  Created by Ashish Awasthi on 09/08/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            SecureSubViewsWrapper()
                .frame(width: 413, height: 600)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}

import SecureScreen

// Create a SwiftUI wrapper
struct SecureSubViewsWrapper: UIViewRepresentable {
    func makeUIView(context: Context) -> SecureSubViews {
        return SecureSubViews.loadFromNib()
    }

    func updateUIView(_ uiView: SecureSubViews, context: Context) {
        // Update the view if needed
    }
}

