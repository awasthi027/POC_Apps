//
//  SmartCardConnection.swift
//  NFCPOC
//
//  Created by Ashish Awasthi on 22/10/23.
//

import Foundation
import CryptoTokenKit

enum SmartCardConnectionState: Int {
    /// The session is closed. No commands can be sent to the key.
    case closed
    /// The session is opened and ready to use. The application can send commands to the key.
    case open
}


protocol SmartCardConnectionManagerCallBack: NSObjectProtocol {
    func didConnectSmartCard(connection: SmartCardConnectionManager)
    func didDisconnectSmartCard(connection: SmartCardConnectionManager, error: Error?)
    func didFailConnectingSmartCard(error: Error)
}

let slotObserverNames = "slotNames"

class SmartCardConnectionManager: NSObject {

    private var connectionController: SmartCardConnectionController?
    private var isActive: Bool = false
    var delegate: SmartCardConnectionManagerCallBack?
    
    func startConnection() {
        if self.isActive {
            return
        }
        self.isActive = true
        self.updateConnections()
        TKSmartCardSlotManager.default?.addObserver(self, forKeyPath: slotObserverNames, context: nil)
    }

    func stopConnection() {
        if !self.isActive  {
            return
        }
        self.isActive = false
        TKSmartCardSlotManager.default?.removeObserver(self, forKeyPath: slotObserverNames)
        self.connectionController?.endSession()
        self.connectionController = nil
    }

    private func updateConnections() {
        // Creating the smart card has to be done on the main thread and after a slight delay
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
            guard let slotManager = TKSmartCardSlotManager.default else {
                return
            }
            guard let slotName = slotManager.slotNames.first else {
                self.delegate?.didDisconnectSmartCard(connection: self, error: nil)
                self.connectionController = nil
                return
            }
            let slot = slotManager.slotNamed(slotName)
            guard let smartCard = slot?.makeSmartCard() else {
                return
            }
            SmartCardConnectionController.smartCardControllerWithSmartCard(smartCard: smartCard) { connectionController, error in
                if let error = error {
                    self.delegate?.didFailConnectingSmartCard(error: error)
                }else {
                    self.connectionController = connectionController
                    self.delegate?.didConnectSmartCard(connection: self)
                }
            }
        }
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        self.updateConnections()
    }

    var connectionState: SmartCardConnectionState {
        return self.connectionController == nil ? .closed : .open
    }

}

//MARK: Execute commands
extension SmartCardConnectionManager {
    
    func selectApplication(handler: @escaping (UInt32, Error?) -> Void) {
        debugPrint("SmartCardCommand:- selectApplication")

        let bytes: [UInt8] = [0xA0, 0x00, 0x00, 0x03, 0x08]
        let data1 = NSData(bytes: bytes, length: 5)
        let apdu = APDU(cla: 0x00, ins: 0xA4, p1: 0x04, p2: 0,
                        data: data1.asData, type: .short)
        self.connectionController?.execute(command: apdu, handler: { responseData, timeInterval, error in
            if let error = error {
                debugPrint("SmartCardCommand:- selectApplication Error: \(error.localizedDescription)")
                handler(0, error)
            }else {
                self.getVersion(handler: handler)
            }
        })
    }

    func getVersion(handler: @escaping (UInt32, Error?) -> Void) {
        debugPrint("SmartCardCommand:- getVersion")
        let apdu = APDU(cla: 0x00, ins: 0xfd, p1: 0, p2: 0,
                        data: Data(), type: .short)
        self.connectionController?.execute(command: apdu, handler: { responseData, timeInterval, error in
            if let error = error {
                debugPrint("SmartCardCommand:- getVersion Error: \(error.localizedDescription)")
                handler(0,error)
            }else {
                if let data = responseData,
                    data.count > 2 {
                    let binaryPacket = BinaryPacket(payload: data)
                    let version = NFCVersion(major: binaryPacket.uint8(0),
                                             minor:  binaryPacket.uint8(1),
                                             micro:  binaryPacket.uint8(2))
                    debugPrint("SmartCardCommand:- \(version.major).\(version.micro).\(version.minor)")
                }
                self.getSerialNumber(handler: handler)
            }
        })
    }

    func getSerialNumber(handler: @escaping (UInt32, Error?) -> Void) {
        debugPrint("SmartCardCommand:- getSerialNumber")
        let apdu = APDU(cla: 0, ins: pivInsGetSerialNumber, p1: 0, p2: 0, data: Data(), type: .short)
        self.connectionController?.execute(command: apdu, handler: { responseData, timeInterval, error in
            if let data = responseData, data.count > 4 {
               let binaryPacket = BinaryPacket(payload: data)
                let serialNumber = binaryPacket.uint32(0)
                handler(serialNumber, error)
            }else {
                debugPrint("NFCCommand:- getSerialNumber Error: \(String(describing: error?.localizedDescription))")
                handler(0, error)
            }
        })
    }

}
