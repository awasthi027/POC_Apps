//
//  LearningSDKManager.swift
//  LearningSubspecSDK
//
//  Created by Ashish Awasthi on 04/07/25.
//
import Foundation
import UIKit



public protocol SDKStateProtocol {
    func sdkInitComplete()
}

public final class LearningSDKManager {

    public static let shared = LearningSDKManager()

    private init() {
    }

    public func startSDK() {

    }

    public func loginUser(userName: String,
                          password: String) {
        print("UserName: \(userName), Password: \(password)")
        UserDefaults.isUserLogin = true
#if AutomationSupports
        LoggingViewModel.shared.log(CheckInPoints.loginSuccess)
#endif
    }

    public var userIsLogin: Bool {
        UserDefaults.isUserLogin
    }

    public func logoutUser() {
        UserDefaults.isUserLogin = false
#if AutomationSupports
        LoggingViewModel.shared.log(CheckInPoints.userLoggedOut)
#endif
    }
}
