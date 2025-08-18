//
//  UIPasteboard+Extension.swift
//  Pods
//
//  Created by Ashish Awasthi on 14/08/25.
//

import Foundation

#if os(iOS)
import MobileCoreServices
import UIKit

extension UIPasteboard {
    
    var completeString: String? {
        var allMessage: String = ""
        var items: [String] = self.strings ?? []
        items = self.sortPasteItems(items: items)
        allMessage = items.reduce("", {$0 + $1})
        return allMessage.isEmpty ? nil : allMessage
    }

    /// Sort items in ascending order if a valid date is present in all items.
    /// - Parameter items: [String]
    /// - Returns: items: [String]
    func sortPasteItems(items: [String]) -> [String] {
        if items.allSatisfy({ $0.dateFromCopyItem != nil }) {
            return items.sorted (by: { $0.dateFromCopyItem!  <  $1.dateFromCopyItem! })
        }
        return items
    }
}

#endif


extension String {

    var dateFromCopyItem: Date? {
        guard let dateString = self.dateStringFromCopyItem else {
            return nil
        }
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let matches = detector?.matches(in: dateString, options: [],
                                        range: NSRange(location: 0,
                                                       length: dateString.utf16.count))
        guard let match = matches?.first,
              let date = match.date else {
            return nil
        }
        return date
    }

    var dateStringFromCopyItem: String? {
        // Define the regular expression pattern to match content inside []
        if let range = self.range(of: "\\[([^\\]]+)\\]", options: .regularExpression) {
            let matchedString = String(self[range])
            // Remove the brackets to get only the content inside
            return String(matchedString.dropFirst().dropLast())
        }
        return nil
    }
}


extension UIImage {
    static func htmlStringFor(imageData: Data, type: String) -> String {
        let prefix = "<img alt=\"Embedded Image\" src=\"data:image/"
        let firstHalf = prefix + type + ";"
        let base64String = imageData.base64EncodedString()
        let secondHalf = "base64," + base64String + "\"/>"
        return firstHalf + secondHalf
    }
}

