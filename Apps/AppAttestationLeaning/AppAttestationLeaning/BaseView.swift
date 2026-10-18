//
//  BaseView.swift
//  AppAttestationLeaning
//
//  Created by Ashish Awasthi on 17/10/26.
//

import SwiftUI

struct BaseView: View {
    @ObservedObject var viewModel: AppAttestationViewModel

    var body: some View {
        NavigationStack {
            Form {
                
                Section("Register App Attestation Key") {
                    Button("Register Attestation") {
                        viewModel.send(.registerTapped)
                    }
                    .disabled(viewModel.isBusy)
                }
                
                Section("Protected Echo Call") {
                    
                    
                    Button("Send Protected Echo") {
                        viewModel.send(.protectedEchoTapped)
                    }
                    .disabled(viewModel.isBusy)
                }
                
                Section("Protected Profile Call") {
                    Button("Get Protected Profile") {
                        viewModel.send(.protectedProfileTapped)
                    }
                    .disabled(viewModel.isBusy)
                }

                Section("Request") {
                    Text(viewModel.lastRequest)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                }
                
                Section("Response") {
                    Text(viewModel.lastResponse)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                }
                Button("Print Log") {
                   print("viewModel.lastResponse:\n \(viewModel.lastResponse)")
                }
            }
            .navigationTitle("App Attestation")
            .overlay {
                if viewModel.isBusy {
                    ProgressView().controlSize(.large)
                }
            }
        }
    }
}

#Preview {
    BaseView(viewModel: AppContainer.makeDefault().viewModel)
}
