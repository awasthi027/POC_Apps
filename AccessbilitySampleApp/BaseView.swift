//
//  ContentView.swift
//  AccessbilitySampleApp
//
//  Created by Ashish Awasthi on 16/05/23.
//

import SwiftUI

struct BaseView: View {

    var body: some View {
        
        MyNavigation {
            ZStack {
                BGView()
                VStack(spacing: 10) {
                    
                    NavigationLink {
                        LoginView()
                    } label: {
                        VisionLabel(title: "Login", image: "globe", alignment: .center)
                    }

                    NavigationLink {
                        LoginView()
                    } label: {
                        VisionLabel(title: "Sign up", image: "globe", alignment: .center)
                    }
                }
            }
        }

    }
    
}


//MARK: UILayout view
extension BaseView {

    func buttonView(title: String,
                    didTouchUpInside: @escaping()-> Void) -> some View {
        Button {
            didTouchUpInside()
        } label: {
            Text(title)
                .foregroundColor(.white)
        }
    }
}
struct BaseView_Previews: PreviewProvider {
    static var previews: some View {
        BaseView()
    }
}

struct MyNavigation<Content>: View where Content: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        if #available(iOS 16, *) {
            NavigationStack(root: content)
        } else {
            NavigationView(content: content)
        }
    }
}
