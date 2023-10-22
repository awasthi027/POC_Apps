//
//  ContentViewViewModel.swift
//  NFCPOC
//
//  Created by Ashish Awasthi on 22/10/23.
//

import Foundation


class ContentViewViewModel: NSObject, ObservableObject {
    
    // MARK: NFC Tag Reader
    var nfcConnectionManager: NFCConnectionManager = NFCConnectionManager()

    func startNFCSession() {
        nfcConnectionManager.startNFCSession()
    }
    
    //MARK: NFC Polling scanning....
    var iOStagConnectionManager = NFCISO14443ConnectionManager()
    func startiOSTagPolling() {
        self.iOStagConnectionManager.delegate = self
       self.iOStagConnectionManager.startSession()
    }

    //MARK: Smart Card
    var smartCardConnectionManager: SmartCardConnectionManager = SmartCardConnectionManager()
    func startObservingCardConnection() {
        smartCardConnectionManager.delegate = self
        self.smartCardConnectionManager.startConnection()
    }
}

//MARK: Polling scanning....
extension ContentViewViewModel: NFCPollingConnectionCallBack {

    func didConnectNFC(manager: NFCISO14443ConnectionManager,
                       connectionState: NFCConnectionState, error: String) {
        debugPrint("NFCCommand:- ConnectionSuccess")
        manager.selectApplication { serialNumber, error in
            debugPrint("NFCCommand:- Serial Call back")
            debugPrint("NFCCommand:- Serial Number: \(serialNumber), error: \(String(describing: error))")
            manager.invalidateNFCSession()
        }
    }
}

//MARK: Smart Card
extension ContentViewViewModel: SmartCardConnectionManagerCallBack {

    func didConnectSmartCard(connection: SmartCardConnectionManager) {
        debugPrint("SmartCardCommand:- ConnectionSuccess")
        connection.selectApplication { serialNumber, error in
            debugPrint("SmartCardCommand:- Serial Call back")
            debugPrint("SmartCardCommand:- Serial Number: \(serialNumber), error: \(String(describing: error))")
            connection.stopConnection()
        }
    }

    func didDisconnectSmartCard(connection: SmartCardConnectionManager, error: Error?) {

    }

    func didFailConnectingSmartCard(error: Error) {

    }
}
