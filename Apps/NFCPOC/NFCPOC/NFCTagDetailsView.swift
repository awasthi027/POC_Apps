//
//  NFCTagDetailsView.swift
//  NFCPOC
//
//  Created by Ashish Awasthi on 19/10/23.
//

import SwiftUI
import CoreNFC

struct NFCTagDetailsView: View {
    var message: NFCNDEFMessage = .init(records: [])
    @StateObject var viewModel: NFCTagDetailsViewModel = NFCTagDetailsViewModel()
    let writeManager = WriteConnectionManager()
    var body: some View {

        List(self.viewModel.reconds, id: \.payload.count) { item in
            Text(item.displayMessage)
        }
        .listStyle(.plain)
        .padding(.horizontal, 20)
        .onAppear {
            self.viewModel.message = self.message
            self.viewModel.publishRecords()
            self.writeManager.message = self.message
        }
    }
}

#Preview {
    NFCTagDetailsView()
}

