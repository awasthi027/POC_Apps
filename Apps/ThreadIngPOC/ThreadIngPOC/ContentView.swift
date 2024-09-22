//
//  ContentView.swift
//  ThreadIngPOC
//
//  Created by Ashish Awasthi on 16/09/24.
//

import SwiftUI

struct AlertContext {
    var isActive: Bool
    var title: String
    var message: String
}

extension View {
    func alert(context: Binding<AlertContext?>) -> some View {
        alert(isPresented: Binding<Bool>(
            get: { context.wrappedValue != nil },
            set: { if !$0 { context.wrappedValue = nil } }
        )) {
            Alert(
                title: Text(context.wrappedValue?.title ?? ""),
                message: Text(context.wrappedValue?.message ?? ""),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

struct ContentView: View {

    @State private var alertQueue: [AlertContext] = []
    @State private var currentAlert: AlertContext?

    var body: some View {
        VStack {
            Button("Show Alert 1") {
            }
            Button("Show Alert 2") {
            }
        }
        .alert(context: Binding<AlertContext?>(
            get: { currentAlert },
            set: { _ in showNextAlert() }
        ))
        .onAppear() {

        }
    }

    private func showNextAlert() {
        if currentAlert == nil, !alertQueue.isEmpty {
            currentAlert = alertQueue.removeFirst()
        } else {
            currentAlert = nil
        }
    }
}
#Preview {
    ContentView()
}
