//
//  NavHandler.swift
//  BLEClient
//
//  Created by Ashish Awasthi on 02/09/25.
//

import SwiftUI

enum ControllerNavigation  {
    case chatView
}


struct NavHandler<Content>: View where Content: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        if #available(iOS 16, *) {
            NavigationStack(root: content)
        } else {
            NavigationView(content: content)
        }
    }
}
