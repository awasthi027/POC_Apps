//
//  ContentView.swift
//  CertsOpenSSL
//
//  Created by Ashish Awasthi on 29/01/25.
//

import SwiftUI

struct ContentView: View {
    @State var viewModel = ContentViewModel.contentViewModelAttributesAndPublicKey()
    @State var certificatePath: String = "/Users/ashisha2/Library/Developer/CoreSimulator/Devices/D314CD95-0F63-49C1-837F-3BDECB2017AA/data/Containers/Data/Application/672D917F-C8D6-41B8-8D47-5B9DD59D7ED6/tmp/Ashish.p12"
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
//            HStack {
//                Button {
//                    self.certificatePath = self.viewModel.createP12Certificate(p12CertName: "Sample Cert Name",
//                                                        certPassword: "password",
//                                                        subjectName: "Encryption, Signing, Authentication",
//                                                        fileName: "Ashish.p12")
//
//                } label: {
//                    Text("Create Certificate")
//                        .foregroundColor(.white)
//                        .font(.headline)
//                }
//                .buttonStyle(.borderedProminent)
//
//                Button {
////                    self.viewModel = ContentViewModel.certificateAndPasswordViewModel(certPath:self.certificatePath,
////                                                                                      password: "password")
//                    self.viewModel.readCertificateSubjectName()
//                } label: {
//                    Text("Read Certificate")
//                        .foregroundColor(.white)
//                        .font(.headline)
//                }
//                .buttonStyle(.borderedProminent)
//            }
            Text("\(self.viewModel.readCertificateDescription())")
        }
        .padding()
        .onAppear() {

        }
    }
}

#Preview {
    ContentView()
}

