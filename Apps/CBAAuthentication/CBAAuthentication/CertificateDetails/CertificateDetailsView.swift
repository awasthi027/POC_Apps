//
//  CertificateDetailsView.swift
//  CBAAuthentication
//
//  Created by Ashish Awasthi on 28/07/26.
//

import SwiftUI

/// Displays the parsed details of a client certificate: name, issuer, expiry date,
/// supported operation types, email, subject, and more.
struct CertificateDetailsView: View {
    @StateObject private var viewModel: CertificateDetailsViewModel

    init(viewModel: CertificateDetailsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    /// Convenience initializer to build the view model from a stored identity.
    init(identity: KeychainCertificateManager.StoredIdentity) {
        _viewModel = StateObject(wrappedValue: CertificateDetailsViewModel(
            certificate: identity.certificate,
            fallbackName: identity.commonName,
            label: identity.label
        ))
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Image(systemName: viewModel.isExpired ? "xmark.seal.fill" : "checkmark.seal.fill")
                        .font(.title)
                        .foregroundStyle(viewModel.isExpired ? .red : .green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.commonName)
                            .font(.headline)
                        Text(viewModel.isExpired ? "Expired" : "Valid")
                            .font(.caption)
                            .foregroundStyle(viewModel.isExpired ? .red : .green)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Certificate Details") {
                ForEach(viewModel.items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(item.value)
                            .font(.body)
                            .textSelection(.enabled)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Certificate")
        .navigationBarTitleDisplayMode(.inline)
    }
}
