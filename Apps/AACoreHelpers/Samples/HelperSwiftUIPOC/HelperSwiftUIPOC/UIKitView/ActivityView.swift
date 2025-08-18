//
//  ActivityView.swift
//  HelperSwiftUIPOC
//
//  Created by Ashish Awasthi on 18/08/25.
//

import SwiftUI
import UIKit

struct ActivityView: UIViewControllerRepresentable {
    
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    var excludedActivityTypes: [UIActivity.ActivityType]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // Nothing to update
    }
}

struct ActivityViewModifier: ViewModifier {
    @Binding var isPresented: Bool
    var activityItems: [Any]
    var excludedActivityTypes: [UIActivity.ActivityType]? = nil

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                ActivityView(
                    activityItems: activityItems,
                    excludedActivityTypes: excludedActivityTypes
                )
                // This helps with iPad presentation
                .edgesIgnoringSafeArea(.all)
            }
    }
}

extension View {
    func shareSheet(
        isPresented: Binding<Bool>,
        activityItems: [Any],
        excludedActivityTypes: [UIActivity.ActivityType]? = nil
    ) -> some View {
        self.modifier(ActivityViewModifier(
            isPresented: isPresented,
            activityItems: activityItems,
            excludedActivityTypes: excludedActivityTypes
        ))
    }
}
