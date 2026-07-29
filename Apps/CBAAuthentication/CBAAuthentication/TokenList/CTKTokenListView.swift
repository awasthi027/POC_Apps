//
//  TokenListView.swift
//  CBAAuthentication
//
//  Created by Ashish Awasthi on 29/07/26.
//

import SwiftUI

struct CTKTokenListView: View {

    @StateObject var viewModel: CTKTokenListViewModel = CTKTokenListViewModel()

    var body: some View {
        VStack {
            if viewModel.certificates.isEmpty {
                Text("No client identity stored in app keychain")
                    .foregroundStyle(.secondary)
            } else {
                List(viewModel.certificates, id:\.serialNumber) { certificate in
                    NavigationLink {
                        CBAWKWebView(viewModel: CBAWKWebViewModel(cbaURL: URL(string: "https://isdkweb03.ssdevrd.com:8443/ia")!,
                                                                  secIdentity: self.viewModel.secIdentity(certificate: certificate)))
                            .ignoresSafeArea(edges: .bottom)
                            .navigationTitle("CTK YubiKey WebView")
                            .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            if let commonName = certificate.commonName {
                                Text(commonName)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }.onAppear() {
            self.viewModel.fetchCertificates() {

            }
        }
    }
}
