//
//  ContentView.swift
//  CTKCertificates
//
//  Created by Ashish Awasthi on 23/07/26.
//

import SwiftUI

struct ContentView: View {

    @StateObject var viewModel = CertificateListingViewModel()
    @State private var didLoad = true

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.certificates.isEmpty {
                    ContentUnavailableView(
                        "No Token Certificates",
                        systemImage: "lock.shield",
                        description: Text("No certificates published by a CryptoTokenKit persistent token were found.\n\nCTK token extensions do not load in the Simulator — test on a real device.")
                    )
                } else {
                    List(viewModel.certificates, id: \.id) { cert in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(cert.commonName ?? "Unknown")
                                .font(.headline)
                            if let serial = cert.serialNumber {
                                Text("Serial: \(serial)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Token Certificates")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Refresh", systemImage: "arrow.clockwise") {
                        reload()
                    }
                }
            }
        }
        .onAppear {
            if !didLoad {
                didLoad = true
                reload()
            }
        }
    }

    private func reload() {
        viewModel.getAllIdentities(identityType: .all) {
            CTKCertificateReader.readFromPersistentTokens()
        }
    }
}

#Preview {
    ContentView()
}
