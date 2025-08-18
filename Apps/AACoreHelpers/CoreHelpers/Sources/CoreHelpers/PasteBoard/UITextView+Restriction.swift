//
//  UITextView+Restriction.swift
//  Pods
//
//  Created by Ashish Awasthi on 14/08/25.
//

#if os(iOS)
import UIKit

extension UITextView {
    
    func pasteAdminRestriction() {
        guard CoreHelperManager.shared.isPasteInsideAllowed,
        let completeStr = UIPasteboard.general.completeString else {
            if AppPasteboard.shared.isInternalPaste() {
                // Allow internal paste
                if let text = AppPasteboard.shared.string {
                    self.replace(self.selectedTextRange ?? UITextRange(), withText: text)
                }
            } else {
                // Block external paste
                self.text = RestrictionMessage.disablePasteIn.message
            }
            return
        }
        self.replace(self.selectedTextRange ?? UITextRange(), withText: completeStr)
    }

    func copyAndCutAdminRestriction() {
        if let selectedRange = self.selectedTextRange,
           let selectedText = self.text(in: selectedRange) {
            AppPasteboard.shared.performInternalCopy(selectedText)
            if !CoreHelperManager.shared.isCopyOutAllowed  {
                UIPasteboard.general.items = [
                    ["public.text": RestrictionMessage.disablePasteOut.message]
                ]
            }
        }
    }
}

#endif
