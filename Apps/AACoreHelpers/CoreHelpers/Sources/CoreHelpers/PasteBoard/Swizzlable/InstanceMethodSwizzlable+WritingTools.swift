//
//  InstanceMethodSwizzlable+WritingTools.swift
//  AWCorePlatformHelpers
//
//  Created by Ashish Awasthi on 06/08/25.
//  Copyright © 2025 omnissa. All rights reserved.
//

import Foundation

#if os(iOS)
import UIKit
@objc
internal protocol WritingToolsActionMethodSwizzlingProvider {
    @objc var writingToolsBehavior: NSNumber { get  }
    @available(iOS 18.0, *)
    func chsdkSwizzledWritingToolsBehavior() -> UIWritingToolsBehavior
}

internal protocol WritingToolsMethodSwizzlable: InstanceMethodSwizzlable {
    static func swizzleWritingToolsMethod()
}

extension WritingToolsMethodSwizzlable where Self: WritingToolsActionMethodSwizzlingProvider {
    
    static func swizzleWritingToolsMethod() {
        if #available(iOS 18.0, *) {
            self.swizzleInstanceMethod(from: #selector(getter: WritingToolsActionMethodSwizzlingProvider.writingToolsBehavior),
                                       to: #selector(WritingToolsActionMethodSwizzlingProvider.chsdkSwizzledWritingToolsBehavior))
        }
    }
}

extension UIResponder: WritingToolsActionMethodSwizzlingProvider {

    @objc var writingToolsBehavior: NSNumber {
        get {
            guard !CoreHelperManager.shared.isWritingToolsAllowed else {
                return 0
            }
            return value(forKey: "writingToolsBehavior") as? NSNumber ?? 0
        }
    }

    @available(iOS 18.0, *)
    @objc
    func chsdkSwizzledWritingToolsBehavior() -> UIWritingToolsBehavior {
        guard CoreHelperManager.shared.isWritingToolsAllowed else {
            return .none
        }
        return .default
    }
}

#endif
