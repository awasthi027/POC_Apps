//
//  WKWebViewExtension.swift
//  Pods
//
//  Created by Ashish Awasthi on 14/08/25.
//
#if os(iOS)
import WebKit

extension WKWebView {

    func pasteAdminRestriction() {
        guard CoreHelperManager.shared.isPasteInsideAllowed,
              var completeStr = UIPasteboard.general.completeString else {
            if AppPasteboard.shared.isInternalPaste(),
               let textToPaste = AppPasteboard.shared.string {
                // Handle internal paste
                self.replaceSelectedText(with: textToPaste) { success in
                    if !success {
                    }
                }
            } else {
                // Block external paste
                self.replaceSelectedText(with: RestrictionMessage.disablePasteIn.message) { _ in
                }
            }
            return
        }
        self.replaceSelectedText(with: completeStr) { success in
            if !success {
            }
        }
    }

    func copyAndCutAdminRestriction() {
        // Get the selected text via JavaScript
        self.evaluateJavaScript("window.getSelection().toString();") { (result, error) in
            guard let text = result as? String, !text.isEmpty else { return }
            AppPasteboard.shared.performInternalCopy(text)
            if !CoreHelperManager.shared.isCopyOutAllowed  {
                UIPasteboard.general.items = [
                    ["public.text": RestrictionMessage.disablePasteOut.message]
                ]
            }
        }
    }

    func replaceSelectedText(with replacementText: String, completion: ((Bool) -> Void)? = nil) {
        let sanitizedText = replacementText
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")

        let js = """
            (function() {
                const selection = window.getSelection();
                if (!selection.rangeCount) return false;
                
                const range = selection.getRangeAt(0);
                range.deleteContents();
                
                // Create text node with the new content
                const newNode = document.createTextNode('\(sanitizedText)');
                range.insertNode(newNode);
                
                // Move selection to end of inserted text
                selection.removeAllRanges();
                const newRange = document.createRange();
                newRange.setStartAfter(newNode);
                newRange.setEndAfter(newNode);
                selection.addRange(newRange);
                
                return true;
            })();
            """

        evaluateJavaScript(js) { result, error in
            let success = (result as? Bool) ?? false
            completion?(success)

            if !success {
                print("Text replacement failed in WKWebView")
            }
        }
    }
}
#endif
