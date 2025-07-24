//
//  ContextMenuOption.swift
//  XCTestExtension
//
//  Created by Ashish Awasthi on 24/07/25.
//

import Foundation

public enum ContextMenuOption {

    case selectall
    case select
    case copy
    case paste
    case cut

    var identifier: String {
        switch self {
        case .copy:         return "Copy"
        case .select:       return "Select"
        case .selectall:    return "Select All"
        case .paste:        return "Paste"
        case .cut:          return "Cut"
        }
    }

    static var tableIdentifier: String {
        return "ActivityListView"
    }
}


