//
//  SwiftViewControllerWrapper.swift
//  HelperSwiftUIPOC
//
//  Created by Ashish Awasthi on 18/08/25.
//

import SwiftUI
import UIKit

struct SwiftViewControllerWrapper: UIViewControllerRepresentable {
    // Define a type alias for the UIViewController type
    typealias UIViewControllerType = SwiftViewController

    // 2. Implement makeUIViewController
    func makeUIViewController(context: Context) -> SwiftViewController {
        // Create and return an instance of your UIKit UIViewController
        return SwiftViewController.swiftViewController()!
    }

    // 3. Implement updateUIViewController (optional)
    func updateUIViewController(_ uiViewController: SwiftViewController, context: Context) {
        // Update the UIViewController when SwiftUI state changes
        // This method is called when data relevant to the view controller changes
    }
}
