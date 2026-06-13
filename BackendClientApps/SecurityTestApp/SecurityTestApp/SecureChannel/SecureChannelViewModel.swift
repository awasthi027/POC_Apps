//
//  SecureChannelViewModel.swift
//  SecurityTestApp
//
//  Created by Ashish Awasthi on 13/06/26.
//
import Foundation
import Combine

private struct ChannelStatusResponse: Decodable {
    let active: Bool?
    let status: String?
}

class SecureChannelViewModel: ObservableObject {
    @Published var handshakeStatus: String = "Secure channel not started"
    @Published var secureChannelStatus: String = "Channel activity not checked"

    @Published var activeSessionId: String = ""

    @Published var isSecureChannelComplete: Bool = false
    @Published var isSecureChannelActive: Bool = false
    @Published var isHandshakeInProgress: Bool = false
    @Published var isChannelStatusCheckInProgress: Bool = false

    lazy var articleListViewModel: ArticleListViewModel = {
        ArticleListViewModel(
            articleService: articleService,
            authProvider: { [weak self] in self?.signedRequestContext() }
        )
    }()

    lazy var articleCreateViewModel: ArticleCreateViewModel = {
        ArticleCreateViewModel(
            articleService: articleService,
            authProvider: { [weak self] in self?.signedRequestContext() },
            onCreateSuccess: { [weak self] in self?.articleListViewModel.loadArticles() }
        )
    }()

    private let client: EcdhClient
    private let requestExecutor: SignedRequestExecutor
    private let articleService: ArticleService

    init(
        environment: SecureNetworkEnvironment = .shared,
        signer: ProtectedRequestSigner = ProtectedRequestSigner()
    ) {
        self.client = EcdhClient(
            session: environment.session,
            baseURL: environment.baseURL,
            deviceId: environment.deviceId
        )
        self.requestExecutor = SignedRequestExecutor(environment: environment, signer: signer)
        self.articleService = ArticleService(requestExecutor: requestExecutor)
    }

    func runFullEcdhHandshake() {
        guard !isHandshakeInProgress else { return }

        isHandshakeInProgress = true
        isSecureChannelComplete = false
        isSecureChannelActive = false
        activeSessionId = ""
        secureChannelStatus = "Channel activity not checked"
        handshakeStatus = "Starting secure channel setup..."

        client.generateClientKeys()
        handshakeStatus = "Calling /ecdh/init..."

        client.callInit { [weak self] _, error in
            guard let self = self else { return }

            if let error = error {
                self.handshakeStatus = "/ecdh/init failed: \(error.localizedDescription)"
                self.isHandshakeInProgress = false
                return
            }

            self.handshakeStatus = "Computing client proof and calling /ecdh/confirm..."
            guard let clientProof = self.client.computeClientProof() else {
                self.handshakeStatus = "Failed to compute client proof"
                self.isHandshakeInProgress = false
                return
            }

            self.client.callConfirm(clientProof: clientProof) { [weak self] confirmResponse, error in
                guard let self = self else { return }
                self.isHandshakeInProgress = false

                if let error = error {
                    self.handshakeStatus = "/ecdh/confirm failed: \(error.localizedDescription)"
                    return
                }

                guard let confirmResponse = confirmResponse else {
                    self.handshakeStatus = "No response from /ecdh/confirm"
                    return
                }

                self.isSecureChannelComplete = true
                self.activeSessionId = confirmResponse.sessionId
                self.handshakeStatus = "Secure channel setup complete (session: \(confirmResponse.sessionId))"
            }
        }
    }

    func checkSecureChannelStatus() {
        guard !isChannelStatusCheckInProgress else { return }
        guard let auth = signedRequestContext() else {
            secureChannelStatus = "Setup secure channel first"
            isSecureChannelActive = false
            return
        }

        isChannelStatusCheckInProgress = true
        secureChannelStatus = "Checking /channel/status..."

        requestExecutor.execute(auth: auth, method: "GET", path: "/channel/status", bodyData: nil) { [weak self] result in
            guard let self = self else { return }
            self.isChannelStatusCheckInProgress = false

            switch result {
            case .failure(let error):
                self.isSecureChannelActive = false
                self.secureChannelStatus = "Status check failed: \(error.localizedDescription)"
            case .success(let value):
                let statusCode = value.response.statusCode
                let body = String(data: value.data, encoding: .utf8) ?? ""
                let decoded = try? JSONDecoder().decode(ChannelStatusResponse.self, from: value.data)

                if let active = decoded?.active {
                    self.isSecureChannelActive = active
                } else {
                    let normalized = body.lowercased()
                    self.isSecureChannelActive = statusCode == 200
                        && !normalized.contains("\"active\":false")
                        && !normalized.contains("inactive")
                }

                let activeText = self.isSecureChannelActive ? "active" : "inactive"
                self.secureChannelStatus = "Channel is \(activeText) (HTTP \(statusCode))"
            }
        }
    }

    func makeArticleDetailViewModel(articleId: Int) -> ArticleDetailViewModel {
        ArticleDetailViewModel(
            articleId: articleId,
            articleService: articleService,
            authProvider: { [weak self] in self?.signedRequestContext() }
        )
    }

    private func signedRequestContext() -> SignedRequestContext? {
        guard isSecureChannelComplete, !activeSessionId.isEmpty else {
            return nil
        }

        guard let hmacKey = client.currentHmacKey() else {
            return nil
        }

        return SignedRequestContext(sessionId: activeSessionId, hmacKey: hmacKey)
    }
}
