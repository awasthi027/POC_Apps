//
//  ProductDetailsView.swift
//  UITestPOC
//
//  Created by Ashish Awasthi on 17/10/23.
//

import SwiftUI

struct ProductDetailsView: View {

    var content: Product
    @State var showAlert: Bool = false
    @State var isUserClickOnClickMe: Bool = false
    var body: some View {

        VStack(spacing: 10){

            Text(self.isUserClickOnClickMe ? "User took action" : "")
            .accessibility(identifier: "userActionTextField")

            Text(content.title)
                .accessibility(identifier: "Product_Details")
            Button {
                self.showAlert = true
            } label: {
                Text("Click Me")
            }
            .accessibility(identifier: "clickMeButton")


        }
        .navigationTitle("Product Details")
        .alert("Important message", isPresented: self.$showAlert) {
            Button("OK", role: .cancel) {
                self.isUserClickOnClickMe = true
            }
            .accessibility(identifier: "okButton")
            Button("cancel") {
                self.isUserClickOnClickMe = false
            }
            .accessibility(identifier: "cancelButton")
        }
    }
}


