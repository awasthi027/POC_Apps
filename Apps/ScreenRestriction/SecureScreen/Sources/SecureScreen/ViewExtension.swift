//
//  ViewExtension.swift
//  ScreenProtector
//
//  Created by Ashish Awasthi on 07/08/25.
//

import UIKit

internal extension UIView {

    /// Checks whether the view's background color is fully opaque (alpha = 1.0)
    /// - Returns: `true` if background is opaque, `false` if:
    ///   - Background color is nil
    ///   - Background color is .clear
    ///   - Background color has alpha < 1.0 (semi-transparent)
    func isBackgroundOpaque() -> Bool {
        // Early return for nil or clear background
        guard let bgColor = self.backgroundColor, bgColor != .clear else {
            print("Background color of view to be secured is nil or clear")
            return false
        }

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var white: CGFloat = 0
        var alpha: CGFloat = 0

        // Check RGB color space first
        if bgColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha),
           alpha < 1.0 {
            print("Background color of view to be secured is semi-transparent RGB color")
            return false
        }
        // If not RGB, check grayscale color space
        else if bgColor.getWhite(&white, alpha: &alpha),
                alpha < 1.0 {
            print("Background color of view to be secured is semi-transparent Grayscale color")
            return false
        }
        print("Background color of view to be secured is opaque")
        return true
    }
}

public extension UIView {
    //pins the view to superView edges for the given type
    func pin(_ type: NSLayoutConstraint.Attribute) {
        translatesAutoresizingMaskIntoConstraints = false
        let constraint = NSLayoutConstraint(item: self, attribute: type,
                                            relatedBy: .equal,
                                            toItem: superview, attribute: type,
                                            multiplier: 1, constant: 0)

        constraint.priority = UILayoutPriority.init(999)
        constraint.isActive = true
    }

    //pins the view to all four edges of the superView
    func pinEdges() {
        pin(.top)
        pin(.bottom)
        pin(.leading)
        pin(.trailing)
    }
}

extension UIView {
    public static func loadFromNib(nibName: String? = nil) -> Self {
        let name = nibName ?? String(describing: self)
        let bundle = Bundle(for: Self.self)
        guard let view = bundle.loadNibNamed(name, owner: nil, options: nil)?.first as? Self else {
            fatalError("Could not load view from nib file.")
        }
        return view
    }
}
