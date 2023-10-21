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

struct ContentView: View {
    @StateObject var viewModel: NFCConnectionManager  = NFCConnectionManager()
    //
    @State var isNeedToDisplayAlert: Bool = false
  
   
    var body: some View {
        VStack {
            List(self.viewModel.detectedMessages, id: \.length) { item in
                NavigationLink(value: item) {
                    Text(item.displayMessage)
                }
            }
            .listStyle(.plain)
            .padding(.horizontal, 20)
//            Button {
//                if !self.viewModel.isSupportingNFCScaning {
//                    self.isNeedToDisplayAlert = true
//                }
//                self.viewModel.startNFCSession()
//            } label: {
//                Text("Scan Device")
//            }

            Button {
                self.viewModel.startiOSTagPolling()
            } label: {
                Text("SCAN iOS Tag polling")
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
    ContentView()
}
