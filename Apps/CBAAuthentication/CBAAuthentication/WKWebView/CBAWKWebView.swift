//
//  WKWebViewCTKYubiKeyAuthenticationView.swift
//  CBAAuthentication
//
//  Created by Ashish Awasthi on 24/07/26.
//

import SwiftUI
import WebKit
import UIKit
// https://isdkweb03.ssdevrd.com:8443/ia

struct CBAWKWebView: View {
    let viewModel: CBAWKWebViewModel
    var body: some View {
        VStack {
            WKWebViewWrapperView(url: viewModel.cbaURL,
                                 secIdentity: viewModel.secIdentity)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        }
        .onReceive(NotificationCenter.default.publisher(for: .cbaOpenAppFromLocalNotification)) {_ in
            print("YubiKeyJob: Notification received.")
            guard let jobDetail = JobDataUtil.readFromSharedDefaults() else {
                return
            }
            print("YubiKeyJob: Starting Job")
            let handler = YubiKeyHandler()
            handler.handleIncomingJobOperation(jobData: jobDetail)
        }
    }
}

