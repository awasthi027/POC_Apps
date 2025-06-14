//
//  ContentView.swift
//  SwiftToObjectiveCToCPlusPlus
//
//  Created by Ashish Awasthi on 13/04/25.
//

import SwiftUI

struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel = HomeViewModel()
    @State private var firstInput: String = ""
    @State private var secondInput: String = ""
  
    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 15) {
                TextField("First Name", text: self.$firstInput)
                    .padding()
                    .border(Color.gray, width: 1) // Optional border for visibility
                TextField("Last Name", text: self.$secondInput)
                    .padding()
                    .border(Color.gray, width: 1) // Optional border for visibility
                
                Button("Combind Name") {
                    viewModel.combinedName(firstName: self.firstInput,
                                                                  lastName: self.secondInput)
                }

                Button("Add Numbers") {
                    if let first = Int32(self.firstInput),
                       let second = Int32(secondInput) {

                        self.viewModel.addNumber(a: first,
                                                               b: second)

                    }
                }
                Button("Make Get Request") {
                    self.viewModel.makeGetRequest(url: "https://dummyjson.com/products") { response in
                    }
                }
            }
            Spacer()
            Text("FullName: \(self.viewModel.result)")
        }
        .padding()
        .onAppear() {

        }
    }
}

#Preview {
    HomeView()
}
