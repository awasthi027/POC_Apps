//
//  ContentView.swift
//  CertsOpenSSL
//
//  Created by Ashish Awasthi on 29/01/25.
//

import SwiftUI

struct ContentView: View {
    @State var viewModel = ContentViewModel()

    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            HStack {
                Button {
                   self.viewModel.createP12Certificate(p12CertName: "Create My Own Certificate",
                                                        certPassword: "password",
                                                        subjectName: "Encryption, Signing, Authentication",
                                                        email: "myemail.awasthi@gmail.com",
                                                        fileName: "Ashish.p12")

                } label: {
                    Text("Create Certificate")
                        .foregroundColor(.white)
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    self.viewModel = ContentViewModel.certificateAndPasswordViewModel()
                } label: {
                    Text("Read Certificate")
                        .foregroundColor(.white)
                }
                .buttonStyle(.borderedProminent)
            }
            Text("\(self.viewModel.readCertificateDescription() ?? "")")
                .font(.footnote)
        }
        .padding()
        .onAppear() {
        }
    }
}

#Preview {
    ContentView()
}

