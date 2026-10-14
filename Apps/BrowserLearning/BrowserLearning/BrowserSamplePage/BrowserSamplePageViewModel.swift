//
//  BrowserSamplePageViewModel.swift
//  ai-concept-learning
//
//  Loads a static local HTML page that already contains sample browser links.
//

import Combine
import Foundation

protocol BrowserSampleTemplateServiceProtocol {
    func loadPage() throws -> String
}

final class BundleBrowserSampleTemplateDataSource: BrowserSampleTemplateServiceProtocol {

    enum TemplateError: Error {
        case missingPage
        case unreadablePage
    }

    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func loadPage() throws -> String {
        guard let pageURL = bundle.url(
            forResource: "UrlList",
            withExtension: "html"
        ) else {
            throw TemplateError.missingPage
        }
        guard let html = try? String(contentsOf: pageURL, encoding: .utf8) else {
            throw TemplateError.unreadablePage
        }
        return html
    }
}

@MainActor
final class BrowserSamplePageViewModel: ObservableObject {

    @Published var htmlContent: String = ""
    @Published var errorMessage: String?

    private let templateService: BrowserSampleTemplateServiceProtocol
    private let opener: URLOpening

    init(
        templateService: BrowserSampleTemplateServiceProtocol? = nil,
        opener: URLOpening
    ) {
        self.templateService = templateService ?? BundleBrowserSampleTemplateDataSource()
        self.opener = opener
    }

    func loadPage() {
        do {
            htmlContent = try templateService.loadPage()
        } catch {
            errorMessage = "Unable to load browser sample links."
        }
    }

    func openTargetURL(_ url: URL) async {
        guard opener.canOpen(url) else {
            errorMessage = "This browser link cannot be opened."
            return
        }
        let didOpen = await opener.open(url)
        if !didOpen {
            errorMessage = "Could not open the selected browser link."
        }
    }
}
