//
//  HubWebView.swift
//  WKWebViewLearning
//
//  Created by Ashish Awasthi on 30/09/26.
//

#if canImport(UIKit) && canImport(WebKit)
import SwiftUI
import UIKit
import WebKit
import Combine

struct HubWebViewAccessibilityIDs {
    static let dismissButton: String = "hubWebviewDismissButton"
    static let backwardButton: String = "hubWebviewBackwardButton"
    static let forwardButton: String = "hubWebviewForwardButton"
    static let reloadButton: String = "hubWebviewReloadButton"
    static let overflowButton: String = "hubWebviewOverflowButton"
    static let progressView: String = "hubWebviewProgressView"
    static let webView: String = "hubWebviewContent"
}

public struct HubWebViewStrings {
    public let reloadButtonTitle: String?
    public let loadingProgressTitle: String?
    public let openInBrowserTitle: String?
    public let cancelTitle: String?
    public let dismissButtonTitle: String?

    public init(reloadButtonTitle: String? = nil,
                loadingProgressTitle: String? = nil,
                openInBrowserTitle: String? = nil,
                cancelTitle: String? = nil,
                dismissButtonTitle: String? = nil) {
        self.reloadButtonTitle = reloadButtonTitle
        self.loadingProgressTitle = loadingProgressTitle
        self.openInBrowserTitle = openInBrowserTitle
        self.cancelTitle = cancelTitle
        self.dismissButtonTitle = dismissButtonTitle
    }
}

public enum HubWebViewActionLayout: Equatable {
    case overflowMenu
    case reloadButton
}

public struct HubWebViewStyle {
    public let progressTint: Color
    public let closeIconSystemName: String
    public let backIconSystemName: String
    public let forwardIconSystemName: String
    public let reloadIconSystemName: String
    public let overflowIconSystemName: String
    public let toolbarTint: Color?
    public let allowsBackForwardNavigationGestures: Bool
    public let actionLayout: HubWebViewActionLayout

    public init(progressTint: Color = .accentColor,
                closeIconSystemName: String = "xmark",
                backIconSystemName: String = "chevron.backward",
                forwardIconSystemName: String = "chevron.forward",
                reloadIconSystemName: String = "arrow.clockwise",
                overflowIconSystemName: String = "ellipsis",
                toolbarTint: Color? = nil,
                allowsBackForwardNavigationGestures: Bool = true,
                actionLayout: HubWebViewActionLayout = .overflowMenu) {
        self.progressTint = progressTint
        self.closeIconSystemName = closeIconSystemName
        self.backIconSystemName = backIconSystemName
        self.forwardIconSystemName = forwardIconSystemName
        self.reloadIconSystemName = reloadIconSystemName
        self.overflowIconSystemName = overflowIconSystemName
        self.toolbarTint = toolbarTint
        self.allowsBackForwardNavigationGestures = allowsBackForwardNavigationGestures
        self.actionLayout = actionLayout
    }

    public static let `default` = HubWebViewStyle()
}

public struct HubWebView: View {
    private let url: URL?
    private let title: String?
    private let strings: HubWebViewStrings
    private let style: HubWebViewStyle
    private let showsNavigationActions: Bool
    private let onDismissRequested: (() -> Void)?
    private let onDismissCompletion: (() -> Void)?
    private let onOpenInBrowser: ((URL, String) -> Void)?
    @State private var isShowingOverflowMenu = false

    @Environment(\.dismiss) private var dismiss
    @StateObject private var store: HubWebViewStore
    @StateObject private var dismissCallbacks = HubWebDismissCallbacks()

    public init(url: URL?,
                title: String?,
                strings: HubWebViewStrings,
                style: HubWebViewStyle = .default,
                showsNavigationActions: Bool = true,
                onDismissRequested: (() -> Void)? = nil,
                onDismissCompletion: (() -> Void)? = nil,
                onOpenInBrowser: ((URL, String) -> Void)? = nil) {
        self.url = url
        self.title = title
        self.strings = strings
        self.style = style
        self.showsNavigationActions = showsNavigationActions
        self.onDismissRequested = onDismissRequested
        self.onDismissCompletion = onDismissCompletion
        self.onOpenInBrowser = onOpenInBrowser
        _store = StateObject(wrappedValue: HubWebViewStore(
            initialURL: url,
            allowsBackForwardNavigationGestures: style.allowsBackForwardNavigationGestures
        ))
    }

    public var body: some View {
        VStack(spacing: 0) {
            if store.isLoading {
                ProgressView(value: store.estimatedProgress)
                    .tint(style.progressTint)
                    .accessibilityIdentifier(HubWebViewAccessibilityIDs.progressView)
                    .accessibilityLabel(strings.loadingProgressTitle ?? "Loading")
            }
            HubWKWebView(webView: store.webView)
                .accessibilityIdentifier(HubWebViewAccessibilityIDs.webView)
        }
        .navigationTitle(title ?? "")
        .onChange(of: url) { newValue in
            store.load(newValue)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarLeading) {
                Button {
                    close()
                } label: {
                    if let dismissTitle = strings.dismissButtonTitle {
                        Text(dismissTitle)
                    } else {
                        Image(systemName: style.closeIconSystemName)
                    }
                }
                .accessibilityIdentifier(HubWebViewAccessibilityIDs.dismissButton)

                if showsNavigationActions {
                    Button {
                        store.goBack()
                    } label: {
                        Image(systemName: style.backIconSystemName)
                    }
                    .accessibilityIdentifier(HubWebViewAccessibilityIDs.backwardButton)
                    .disabled(!store.canGoBack)
                }
            }
            if showsNavigationActions {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        store.goForward()
                    } label: {
                        Image(systemName: style.forwardIconSystemName)
                    }
                    .accessibilityIdentifier(HubWebViewAccessibilityIDs.forwardButton)
                    .disabled(!store.canGoForward)

                    if style.actionLayout == .reloadButton {
                        reloadButton
                    } else {
                        overflowButton
                    }
                }
            }
        }
        .tint(style.toolbarTint)
        .alert("", isPresented: $isShowingOverflowMenu) {
            if let reloadTitle = strings.reloadButtonTitle {
                Button(reloadTitle) {
                    store.reload()
                }
            }
            if onOpenInBrowser != nil,
               let url = store.webView.url ?? self.url,
               let openTitle = strings.openInBrowserTitle {
                Button(openTitle) {
                    onOpenInBrowser?(url, title ?? "")
                }
            }
            Button(strings.cancelTitle ?? "Cancel", role: .cancel) {}
        }
        .background(
            HubPresentationDelegateBridge(
                onDidDismiss: { dismissCallbacks.complete(with: onDismissCompletion) },
            )
            .frame(width: 0, height: 0)
        )
    }

    private func close() {
        onDismissRequested?()
        if onDismissRequested == nil {
            dismiss()
        }
        dismissCallbacks.complete(with: onDismissCompletion)
    }

    @ViewBuilder
    private var reloadButton: some View {
        Button {
            store.reload()
        } label: {
            Image(systemName: style.reloadIconSystemName)
        }
        .accessibilityLabel(strings.reloadButtonTitle ?? "Reload")
        .accessibilityIdentifier(HubWebViewAccessibilityIDs.reloadButton)
        .disabled(!store.canReload)
    }

    @ViewBuilder
    private var overflowButton: some View {
        Button {
            isShowingOverflowMenu = true
        } label: {
            Image(systemName: style.overflowIconSystemName)
        }
        .accessibilityIdentifier(HubWebViewAccessibilityIDs.overflowButton)
    }
}

private final class HubWebViewStore: NSObject, ObservableObject {
    @Published var estimatedProgress: Double = 0
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var canReload = false
    @Published var isLoading = false

    let webView: WKWebView
    private var observations: [NSKeyValueObservation] = []
    private var loadedURL: URL?

    init(initialURL: URL?, allowsBackForwardNavigationGestures: Bool) {
        let configuration = WKWebViewConfiguration()
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.allowsBackForwardNavigationGestures = allowsBackForwardNavigationGestures
        observeWebView()
        load(initialURL)
    }

    deinit {
        observations.forEach { $0.invalidate() }
    }

    func load(_ url: URL?) {
        guard let urlItem = url,
              loadedURL != urlItem else { return }
        loadedURL = urlItem
        webView.load(URLRequest(url: urlItem))
    }

    func reload() {
        webView.reload()
    }

    func goBack() {
        webView.goBack()
    }

    func goForward() {
        webView.goForward()
    }

    private func observeWebView() {
        observations = [
            webView.observe(\.estimatedProgress, options: [.initial, .new]) { [weak self] webView, _ in
                self?.publish {
                    self?.estimatedProgress = webView.estimatedProgress
                }
            },
            webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] webView, _ in
                self?.publish {
                    self?.canGoBack = webView.canGoBack
                }
            },
            webView.observe(\.canGoForward, options: [.initial, .new]) { [weak self] webView, _ in
                self?.publish {
                    self?.canGoForward = webView.canGoForward
                }
            },
            webView.observe(\.url, options: [.initial, .new]) { [weak self] webView, _ in
                self?.publish {
                    self?.canReload = webView.url != nil
                }
            },
            webView.observe(\.isLoading, options: [.initial, .new]) { [weak self] webView, _ in
                self?.publish {
                    self?.isLoading = webView.isLoading
                }
            }
        ]
    }

    private func publish(_ updates: @escaping () -> Void) {
        if Thread.isMainThread {
            updates()
        } else {
            DispatchQueue.main.async(execute: updates)
        }
    }
}

private struct HubWKWebView: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No-op: state is observed directly from WKWebView.
    }
}

private final class HubWebDismissCallbacks: ObservableObject {
    private var hasCompleted = false

    func complete(with callback: (() -> Void)?) {
        guard !hasCompleted else { return }
        hasCompleted = true
        callback?()
    }
}

private struct HubPresentationDelegateBridge: UIViewControllerRepresentable {
    let onDidDismiss: (() -> Void)?
    func makeCoordinator() -> Coordinator {
        Coordinator(onDidDismiss: onDidDismiss)
    }

    func makeUIViewController(context: Context) -> HubPresentationController {
        let controller = HubPresentationController()
        controller.coordinator = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: HubPresentationController, context: Context) {
        context.coordinator.onDidDismiss = onDidDismiss
        uiViewController.coordinator = context.coordinator
        uiViewController.applyDelegateIfPossible()
    }

    final class Coordinator: NSObject, UIAdaptivePresentationControllerDelegate {
        var onDidDismiss: (() -> Void)?
        init(onDidDismiss: (() -> Void)?) {
            self.onDidDismiss = onDidDismiss
        }

        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            onDidDismiss?()
        }
    }

    final class HubPresentationController: UIViewController {
        weak var coordinator: Coordinator?

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            applyDelegateIfPossible()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            applyDelegateIfPossible()
        }

        func applyDelegateIfPossible() {
            parent?.presentationController?.delegate = coordinator
        }
    }
}

#endif

public extension String {

    func firstSchemeURLSubstring() -> String? {
        let pattern = #"\S+://\S+"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: self, range: NSRange(startIndex..., in: self)),
              let matchRange = Range(match.range, in: self) else {
            return nil
        }
        return String(self[matchRange])
    }

    func containsCustomSchemeAndHTTPLink() -> Bool {
        guard let scheme = URL(string: self)?.scheme?.lowercased(),
              scheme != "http", scheme != "https" else {
            return false
        }
        let lowered = self.lowercased()
        return lowered.contains("http://") || lowered.contains("https://")
    }
}

public extension URL {

    func containsCustomSchemeAndHTTPLink() -> Bool {
        guard let scheme = self.scheme?.lowercased(),
              scheme != "http", scheme != "https" else {
            return false
        }
        let lowered = self.absoluteString.lowercased()
        return lowered.contains("http://") || lowered.contains("https://")
    }
}
