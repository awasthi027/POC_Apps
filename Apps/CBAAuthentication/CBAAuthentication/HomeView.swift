//
//  HomeView.swift
//  CBAAuthentication
//
//  Created by Ashish Awasthi on 22/07/26.
//

import SwiftUI

enum NavigationItem: Hashable {
    case wkWebViewBundle
    case wkWebViewAppKeyChain
    case nsURLSessionBundle
    case asSessionCertPicker
    case wkWebViewCTKAuthentication
    case wkWebViewCTKYubiKeyAuthentication
    case ctkTokenList
    var name: String {
        switch self {
        case .wkWebViewBundle: return "CBA via Bundle Certificate"
        case .wkWebViewAppKeyChain: return "CBA via App Keychain Certificate"
        case .nsURLSessionBundle: return "URL Session CBA via Bundle Certificate"
        case .asSessionCertPicker: return "ASWebAuthSession CBA via CTK Certificates"
        case .wkWebViewCTKAuthentication: return "CBA via CTK certificate"
        case .wkWebViewCTKYubiKeyAuthentication: return "CAB via YubiKey Certificate"
        case .ctkTokenList: return "CBA via Bundle Certificate"
        }
    }
}

struct HomeView: View {
    private let cbaURL = URL(string: "https://client.badssl.com/")!
    @State private var selection: NavigationItem?
    @State private var storedIdentities: [KeychainCertificateManager.StoredIdentity] = []
    @State private var ctkWriteStatus = ""
    /// View model class object
    var viewModel: YubiKeyActivationViewModel = YubiKeyActivationViewModel()
    var isHomeViewActive: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Accept certificate challenge")
            VStack(spacing: 12) {
                Button("Install Bundle Certificate App Keychain") {
                    //"badssl.com-client"/"badssl.com"
                    _ = KeychainCertificateManager.shared.storeIdentity(fromBundleResource: "badssl.com-client",
                                                                        password: "badssl.com")
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
                }
                .tint(.red)
                .font(.callout)
                Divider()
                Button("Clear CTK") {
                    let removed = CTKManager.shared.clearAllTokensAndPrivateKeys()
                    ctkWriteStatus = removed.isEmpty
                        ? "No app token configurations to remove (private keys cleared)"
                        : "Removed: \(removed.joined(separator: ", "))\n\n"
                            + CTKManager.shared.publishDiagnostics()
                }
                .tint(.red)
                .font(.callout)
                Divider()
                Button("CTK Certificate List") {
                    self.selection = .ctkTokenList
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
                Button(NavigationItem.wkWebViewBundle.name) {
                    self.selection = .wkWebViewBundle
                }
                .font(.callout)
                Divider()
                Button(NavigationItem.wkWebViewAppKeyChain.name) {
                    self.selection = .wkWebViewAppKeyChain
                }
                .font(.callout)
                Divider()
                Button(NavigationItem.nsURLSessionBundle.name) {
                    self.selection = .nsURLSessionBundle
                }
                .font(.callout)
                Divider()
                Button(NavigationItem.asSessionCertPicker.name) {
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
                Button(NavigationItem.wkWebViewCTKAuthentication.name) {
                    self.selection = .wkWebViewCTKAuthentication
                }
                .foregroundStyle(.blue)
                .font(.callout)
                Divider()
                Button(NavigationItem.wkWebViewCTKYubiKeyAuthentication.name) {
                    self.selection = .wkWebViewCTKYubiKeyAuthentication
                }
                .foregroundStyle(.blue)
                .font(.callout)
                Divider()
            }
            Spacer()
        }
        .padding()
        .navigationDestination(item: $selection) { item in
            switch item {
            case .wkWebViewBundle:
                CBAWKWebView(viewModel: CBAWKWebViewModel(cbaURL: cbaURL,
                                                          secIdentity: KeychainCertificateManager.shared.bundleCertificateSecIdentity()))
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(NavigationItem.wkWebViewBundle.name)
                .navigationBarTitleDisplayMode(.inline)
            case .wkWebViewAppKeyChain:
                CBAWKWebView(viewModel: CBAWKWebViewModel(cbaURL: cbaURL,
                                                          secIdentity: KeychainCertificateManager.shared.loadIdentity()))
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(NavigationItem.wkWebViewAppKeyChain.name)
                .navigationBarTitleDisplayMode(.inline)
            case .nsURLSessionBundle:
                SessionView()
            case .asSessionCertPicker:
                ASSessionView()
            case .wkWebViewCTKAuthentication:
                CBAWKWebView(viewModel: CBAWKWebViewModel(cbaURL: cbaURL,
                                                          secIdentity: nil))
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(NavigationItem.wkWebViewCTKAuthentication.name)
                .navigationBarTitleDisplayMode(.inline)
            case .wkWebViewCTKYubiKeyAuthentication:
                CBAWKWebView(viewModel: CBAWKWebViewModel(cbaURL: URL(string: "https://isdkweb03.ssdevrd.com:8443/ia")!,
                                                          secIdentity: nil))
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(NavigationItem.wkWebViewCTKYubiKeyAuthentication.name)
                .navigationBarTitleDisplayMode(.inline)
            case .ctkTokenList:
                CTKTokenListView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            print("YubiKeyJob: Check pending Job")
            guard let jobDetail = JobDataUtil.readFromSharedDefaults(),
                  jobDetail.state != .finish else {
                print("YubiKeyJob: No pending job or already finished.")
                return
            }
            print("YubiKeyJob: Starting Job")
            let handler = YubiKeyHandler()
            handler.handleIncomingJobOperation(jobData: jobDetail)
        }
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
