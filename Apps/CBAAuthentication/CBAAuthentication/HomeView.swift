//
//  HomeView.swift
//  CBAAuthentication
//
//  Created by Ashish Awasthi on 22/07/26.
//

import SwiftUI

enum NavigationItem: Hashable {
    case wkWebViewBundle
    case wkWebViewKeyChain
    case nsURLSessionBundle
    case asSessionCertPicker
    case wkWebViewCTKAuthentication
    case wkWebViewCTKYubiKeyAuthentication
}

struct HomeView: View {
    private let cbaURL = URL(string: "https://client.badssl.com/")!
    @State private var selection: NavigationItem?
    @State private var storedIdentities: [KeychainCertificateManager.StoredIdentity] = []
    @State private var ctkWriteStatus = ""
    /// View model class object
    var viewModel: YubiKeyActivationViewModel = YubiKeyActivationViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Accept certificate challenge")
            VStack(spacing: 12) {
                Button("Install Bundle Certificate App Keychain") {
                    //"badssl.com-client"/"badssl.com"
                    _ = KeychainCertificateManager.shared.storeIdentity(fromBundleResource: "badssl.com-client",
                                                                        password: "badssl.com")
                    refreshStoredIdentities()
                }
                .font(.callout)
                Divider()
                Button("Install Bundle Certificate in CTK") {
                    let ok = CTKManager.shared
                        .publishBundledCertificateToCTK(resource: "badssl.com-client", password: "badssl.com",
                                                        userInteractionRequired: true)
                    ctkWriteStatus = (ok ? "Install call returned OK\n" : "Install call FAILED\n")
                }
                .font(.callout)
                Divider()
                Button("Get Yubikey Public Certificate and Install in CTK") {
                    self.startConnectionAndActivateYubiKeySet()
                }
                .font(.callout)
            }
            HStack {
                Button("Clear Keychain") {
                    _ = KeychainCertificateManager.shared.deleteIdentity()
                    refreshStoredIdentities()
                }
                .tint(.red)
                .font(.callout)
                Divider()
                Button("Clear CTK") {
                    let removed = CTKManager.shared.removeAllOurTokenConfigurations()
                    ctkWriteStatus = removed.isEmpty
                        ? "No app token configurations to remove"
                        : "Removed: \(removed.joined(separator: ", "))\n\n"
                            + CTKManager.shared.publishDiagnostics()
                }
                .tint(.red)
                .font(.callout)
                Divider()
                Button("Refresh") {
                    refreshStoredIdentities()
                }
                .font(.callout)
            }
            .frame(maxHeight: 40)

            if !ctkWriteStatus.isEmpty {
                Text(ctkWriteStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack {
                Button("Webview auth challenge with bundle cert") {
                    self.selection = .wkWebViewBundle
                }
                .font(.callout)
                Divider()
                Button("Webview auth challenge with app keychain cert") {
                    self.selection = .wkWebViewKeyChain
                }
                .font(.callout)
                Divider()
                Button("URLSession auth challenge with bundle cert") {
                    self.selection = .nsURLSessionBundle
                }
                .font(.callout)
                Divider()
                Button("ASWebAuthentication challenge app keychain cert") {
                    self.selection = .asSessionCertPicker
                }
                .foregroundStyle(.green)
                .font(.callout)
                Divider()
                Button("Safari, auth challenge  Device Keychain cert") {
                    UIApplication.shared.open(cbaURL)
                }
                .font(.callout)
                Divider()
                Button("Webview auth challenge  CTK cert") {
                    self.selection = .wkWebViewCTKAuthentication
                }
                .foregroundStyle(.blue)
                .font(.callout)
                Divider()
                Button("Webview auth challenge YubiKey cert via CTK") {
                    self.selection = .wkWebViewCTKYubiKeyAuthentication
                }
                .foregroundStyle(.blue)
                .font(.callout)
                Divider()
            }
            Spacer()
            Text("App Keychain identities")
                .font(.subheadline)
                .bold()

            if storedIdentities.isEmpty {
                Text("No client identity stored in app keychain")
                    .foregroundStyle(.secondary)
            } else {
                List(storedIdentities) { identity in
                    NavigationLink {
                        CertificateDetailsView(identity: identity)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(identity.commonName)
                            Text(identity.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .padding()
        .navigationDestination(item: $selection) { item in
            switch item {
            case .wkWebViewBundle:
                CBAWebView(url: cbaURL, certificateName: "badssl.com-client",
                           certificatePassword: "badssl.com")
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("CBA WebView")
                .navigationBarTitleDisplayMode(.inline)
            case .wkWebViewKeyChain:
                CBAWebView(url: cbaURL)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("CBA WebView")
                .navigationBarTitleDisplayMode(.inline)
            case .nsURLSessionBundle:
                NURLSessionView()
            case .asSessionCertPicker:
                ASSessionView()
            case .wkWebViewCTKAuthentication:
                WKCTKAuthenticationView()
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("CTK WebView")
                .navigationBarTitleDisplayMode(.inline)
            case .wkWebViewCTKYubiKeyAuthentication:
                WKCTKYubiKeyAuthView()
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("CTK YubiKey WebView")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .onAppear {
            refreshStoredIdentities()
        }
        .onDisappear() {
            self.viewModel.shutdownYubiKit()
        }
        .onReceive(NotificationCenter.default.publisher(for: .cbaOpenAppFromLocalNotification)) {_ in
            print("YubiKeyJob: Notification received.")
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 3.0) {
                guard let jobDetail = JobDataUtil.readFromSharedDefaults() else {
                    return
                }
                print("YubiKeyJob: Starting Job")
                let handler = YubiKeyHandler()
                handler.handleIncomingJobOperation(jobData: jobDetail)
            }
        }
    }

    private func refreshStoredIdentities() {
        storedIdentities = KeychainCertificateManager.shared.listStoredIdentities()
    }

    func startConnectionAndActivateYubiKeySet() {

        self.viewModel.startConnectionsAndGetAccessorySession { pivSession, error in

            self.viewModel.activateAccessoryCredential(pivSession: pivSession,
                                                       pivError: error) { isSuccess, error in
                self.processAccessoryConnectionResponse(isSuccess: isSuccess,
                                                        error: error)
            }
        }
    }
    
    func processAccessoryConnectionResponse(isSuccess: Bool,
                                            error: Error?) {
        if isSuccess {
            print("CredentialActivation: Activated")
            self.viewModel.shutdownYubiKit(isConnectionLost: true)
           // self.showCertificateSetList(isAccessoryCertsSetCreated: isSuccess)
        } else {
            if self.viewModel.isConnectionFailError(error: error) {
                self.viewModel.shutdownYubiKit(isConnectionLost: true)
                // Waiting to dismiss existing NFC Scan sheet and then present
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + YubiKeyConnectionViewModel.retryAccessoryScanTime) {
                    print("CredentialActivation: Resign called")
                    self.startConnectionAndActivateYubiKeySet()
                }
            } else {
                self.viewModel.shutdownYubiKit()
                //self.processErrorToDisplay(error: error)
            }
        }
    }
}

#Preview {
    NavigationStack { HomeView() }
}
