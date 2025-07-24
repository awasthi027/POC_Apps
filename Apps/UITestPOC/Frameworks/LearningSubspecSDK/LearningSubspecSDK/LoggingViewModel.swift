//
//  AutomationLogs.swift
//  UITestPOC
//
//  Created by Ashish Awasthi on 23/07/25.
//


import SwiftUI

public struct CheckInPoints {
    public static let loginSuccess: String = "Login Success"
    public static let userLoggedOut: String = "User Logged Out"
}

protocol AutomationLogsProtocol {
    var separator: String { get }
    var accessibilityIdentifier: String { get }
    func clearLogs()
}

public class LoggingViewModel: ObservableObject {
    public static let shared = LoggingViewModel()

    @Published private(set) var logMessages: String = ""
   
    // MARK: - CheckpointLoggerType
    public func log(_ msg: String) {
        logAutomationMessage(message: msg)
    }

    func log(_ format: String, _ args: Any...) {
        let arguments = args as? [CVarArg]
        guard let cVarArgs = arguments else {
            print("automation logs is not in correct format")
            return
        }
        let msg = String(format: format, arguments: cVarArgs)
        logAutomationMessage(message: msg)
    }

    // MARK: - AutomationLoggingView
    func logAutomationMessage(message: String) {
        DispatchQueue.main.async {
            self.logMessages += message + self.separator
        }
    }
}

extension LoggingViewModel: AutomationLogsProtocol {
    
    public var separator: String {
        "\n"
    }

    public var accessibilityIdentifier: String {
        "vmw.sdk.automationLogs"
    }
    
    public func clearLogs() {
        logMessages = ""
    }
}
