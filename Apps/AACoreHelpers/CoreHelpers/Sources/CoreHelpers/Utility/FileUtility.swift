//
//  FileUtility.swift
//  CoreHelpers
//
//  Created by Ashish Awasthi on 22/08/25.
//
import Foundation
import UIKit

class FileUtility {

    static let shared = FileUtility()
    private init() {}

    // MARK: - PDF File Path
    func temporaryDirectory(fileName: String) -> URL? {
        let fileManager = FileManager.default

        let tempURL = fileManager.temporaryDirectory
        if fileManager.fileExists(atPath: tempURL.path) == false {
            try? fileManager.createDirectory(at: tempURL, withIntermediateDirectories: true, attributes: nil)
        }
        return tempURL.appendingPathComponent(fileName)
    }

    // MARK: - Check if PDF Exists
    func pdfExists(fileName: String) -> Bool {
        guard let fileURL = temporaryDirectory(fileName: fileName) else { return false }
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    func writePDF(fileName: String,
                  text: String) -> Bool {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = renderer.pdfData { context in
            // Start a new page
            context.beginPage()

            // Prepare text attributes
            let textAttributes = [
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: 12),
                NSAttributedString.Key.foregroundColor: UIColor.black
            ]

            // Create attributed string
            let attributedText = NSAttributedString(string: text, attributes: textAttributes)

            // Calculate text size
            let maxSize = CGSize(width: pageWidth - 40, height: pageHeight - 40)
            let textRect = attributedText.boundingRect(
                with: maxSize,
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil
            )

            // Draw text
            attributedText.draw(in: CGRect(x: 20, y: 20, width: textRect.width, height: textRect.height))
        }

        return savePDF(data: data,
                       filename: fileName)
    }

    func createFormattedPDF(title: String, content: String, filename: String) -> Bool? {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        let data = renderer.pdfData { context in
            context.beginPage()

            // Draw title
            let titleAttributes = [
                NSAttributedString.Key.font: UIFont.boldSystemFont(ofSize: 18),
                NSAttributedString.Key.foregroundColor: UIColor.darkGray
            ]
            let titleText = NSAttributedString(string: title, attributes: titleAttributes)
            titleText.draw(at: CGPoint(x: 20, y: 20))

            // Draw content
            let contentAttributes = [
                NSAttributedString.Key.font: UIFont.systemFont(ofSize: 12),
                NSAttributedString.Key.foregroundColor: UIColor.black
            ]
            let contentText = NSAttributedString(string: content, attributes: contentAttributes)

            let contentRect = CGRect(x: 20, y: 50, width: pageWidth - 40, height: pageHeight - 70)
            contentText.draw(in: contentRect)
        }

        return savePDF(data: data,
                       filename: filename)
    }

    private func savePDF(data: Data,
                         filename: String) -> Bool {
        guard let fileURL = self.temporaryDirectory(fileName: filename) else { return false }

        do {
            try data.write(to: fileURL)
            return true
        } catch {
            print("Error saving PDF: \(error)")
            return false
        }
    }

    // MARK: - Read PDF File (returns Data)
    func readPDF(fileName: String) -> Data? {
        guard let fileURL = temporaryDirectory(fileName: fileName) else { return nil }
        return try? Data(contentsOf: fileURL)
    }

    func deletePDF(fileName: String) -> Bool {
        
        guard let fileURL = temporaryDirectory(fileName: fileName) else { return false }
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: fileURL.absoluteString) {
            do {
                try fileManager.removeItem(at: fileURL)
                return true
            } catch let err {
                print("Failed to delete empty file at \(fileURL) with error: \(err)")
                return false
            }
        }
        return false
    }
}
