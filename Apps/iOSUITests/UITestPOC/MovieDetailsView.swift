//
//  MovieDetailsView.swift
//  UITestPOC
//
//  Created by Ashish Awasthi on 17/10/23.
//

import SwiftUI

struct MovieDetailsView: View {

    var content: ListModel
    @State var showAlert: Bool = false

    var body: some View {

        VStack {
            Text(content.text)
                .accessibility(identifier: "FEED_Details")
            Button {
                showAlert = true
            } label: {
                Text("Click me")
            }
            .accessibility(identifier: "ALERT_BUTTON")
        }
        .navigationTitle("Movie Details")
        .alert("Important message", isPresented: self.$showAlert) {
            Button("OK", role: .cancel) {
            }
            .accessibility(identifier: "OK_Text")
        }
    }
}
