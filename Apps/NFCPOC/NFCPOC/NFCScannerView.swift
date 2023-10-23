//
//  ContentView.swift
//  NFCPOC
//
//  Created by Ashish Awasthi on 16/10/23.
//

/*

 https://hpkaushik121.medium.com/understanding-apdu-commands-emv-transaction-flow-part-2-d4e8df07eec

 */
import SwiftUI
import CoreNFC

struct NFCScannerView: View {

    @StateObject  var viewModel: NFCScannerViewModel = NFCScannerViewModel()
    //
    @State var isNeedToDisplayAlert: Bool = false

    var body: some View {

        VStack (spacing: 20) {
            List(self.viewModel.nfcConnectionManager.detectedMessages, id: \.length) { item in
                NavigationLink(value: item) {
                    Text(item.displayMessage)
                }
            }
            .listStyle(.plain)
            .padding(.horizontal, 20)
            
            Button {
                if !self.viewModel.nfcConnectionManager.isSupportingNFCScaning {
                    self.isNeedToDisplayAlert = true
                }
                self.viewModel.startNFCSession()
            } label: {
                Text("Scan Device and read tag")
            }

            Button {
                self.viewModel.startiOSTagPolling()
            } label: {
                Text("Scan Device By Polling and Read and Write data")
            }

            Button {
                self.viewModel.startObservingCardConnection()
            } label: {
                Text("Connect Smart Card")
            }

        }
        .padding()
        .navigationBarTitle("NFS Tag List", displayMode: .inline)
        .alert(isPresented: self.$isNeedToDisplayAlert) {
            Alert(title: Text("Scanning Not Supported"),
                  message: Text("This device doesn't support tag scanning."),
                  dismissButton: .default(Text("Got it!")))
        }
        .navigationDestination(for: NFCNDEFMessage.self) { content in
            NFCTagDetailsView(message: content)
        }
    }
}


#Preview {
    NFCScannerView()
}
