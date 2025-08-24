//
//  NavHandler.swift
//  HelperSwiftUIPOC
//
//  Created by Ashish Awasthi on 22/08/25.
//

import SwiftUI

enum ControllerNavigation  {
    case swizzleControllers
    case storyBoardController
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
