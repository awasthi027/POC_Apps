//
//  ContentView.swift
//  DIP
//
//  Created by Ashish Awasthi on 18/01/25.
//

import SwiftUI

struct ContentView: View {

    let viewModel = ContentViewModel()
    @State var textMessage: String = ""

    var body: some View {
        VStack {

            Button {
                textMessage = self.viewModel.bookFlight()
            } label: {
                Text("Book Flight")
            }
            
            Button {
                textMessage = self.viewModel.bookInsurance()
            } label: {
                Text("Book Insurance")
            }

            Button {
                textMessage = self.viewModel.bookFlightAndInsurance()
            } label: {
                Text("Book flight and Insurance")
            }

            Button {
                textMessage = self.viewModel.bookInsuranceAndFlight()
            } label: {
                Text("Book Insurance and Flight")
            }

            Text("\(self.textMessage)")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
