//
//  PeriperalService.swift
//  BLEDevice
//
//  Created by Ashish Awasthi on 29/08/25.
//

import CoreBluetooth


// This class acts as the Peripheral (server) in a BLE connection.
open class PeripheralServerService: NSObject,
                                    ObservableObject {

    // The peripheral manager must be a property of the class to ensure it is not deallocated.
    // This is a common source of bugs where delegate methods are never called.
    var peripheralManager: CBPeripheralManager!
    @Published public var periPheralDataRead: String = ""
    var characteristicsSubscribedByCentral: [CBCharacteristic] = []

    @Published public var readDataSendByClient: String = ""
    @Published public var bleState: BLEState = .unknown
    @Published public var isBLEAdvertising: Bool = false
    // This one is for errors, passing an Error object.
    public var onChatCommunication: ((String) -> Void)?

    public override init() {
        super.init()
        // 2. Initialize the peripheral manager and set its delegate to this class.
        // It is initialized on the main queue to ensure delegate callbacks occur on the main thread.
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }

    public func startAdvertising() {
        guard  peripheralManager.state == .poweredOn else {
            self.bleState = .unknown
            return
        }
        // Create the service
        print("Peripheral Manager is powered on. Setting up service.")
        self.bleState = .poweredOn
        
        // Create the service and add the characteristic to it.
        let myService = CBMutableService(type: PeripheralServiceType.first.service_uuid,
                                         primary: true)
        myService.characteristics = characteristicsList

        // Add the service to the peripheral manager. This triggers the next delegate method.
        peripheralManager.add(myService)

    }

    public func stopAdvertising() {
        if self.peripheralManager.isAdvertising {
            peripheralManager.stopAdvertising()
        }
        self.isBLEAdvertising = false
        self.bleState = .unknown
        self.readDataSendByClient = ""
    }

    var characteristicsList: [CBMutableCharacteristic] {
        // Create the characteristic with read, write, and notify properties.
        let firstCharacteristic = CBMutableCharacteristic(
            type: BLEServiceCharacteristic.first.cbUUId,
            properties: [.read, .write, .notify],
            value: nil,
            permissions: [.readable, .writeable]
        )

        let secondCharacteristic = CBMutableCharacteristic(
            type:  BLEServiceCharacteristic.second.cbUUId,
            properties: [.read, .write, .notify],
            value: nil,
            permissions: [.readable, .writeable]
        )
        let jsonCharacteristic = CBMutableCharacteristic(
            type:  BLEServiceCharacteristic.json.cbUUId,
            properties: [.read, .write, .notify],
            value: nil,
            permissions: [.readable, .writeable]
        )
        let chatCharacteristic = CBMutableCharacteristic(
            type:  BLEServiceCharacteristic.oneToOneChat.cbUUId,
            properties: [.read, .write, .notify],
            value: nil,
            permissions: [.readable, .writeable]
        )
        return [firstCharacteristic,
                secondCharacteristic,
                jsonCharacteristic,
                chatCharacteristic]
    }

    public func sendValueTotCharacteristic(characteristic: BLEServiceCharacteristic,
                                           data: Data) {
        guard let characteristic = characteristicsSubscribedByCentral.first(where: { $0.uuid == characteristic.cbUUId }) as? CBMutableCharacteristic else {
            print("This Id not subscribed by any central: \(characteristic.cbUUId)")
            return
        }
        // Here you would begin sending notifications
        // For example:
        peripheralManager.updateValue(data, for: characteristic, onSubscribedCentrals: nil)
    }

    func readCentralCharacteristicDataAndRespondBack(requests: [CBATTRequest],
                                                     peripheralManager: CBPeripheralManager) {
        requests.forEach { request in
            if request.characteristic.uuid == BLEServiceCharacteristic.oneToOneChat.cbUUId,
               let data = request.value {
                let info = data.string
                self.readDataSendByClient.append("\n\(info)")
                if let updateChat = self.onChatCommunication {
                    updateChat(info)
                }
            }else {
                if let data = request.value {
                    self.readDataSendByClient.append("\n\(data.string)")
                }
            }
        }
        // Respond to the write request.
        peripheralManager.respond(to: requests.first!, withResult: .success)
    }

    func sendDefaultCharacteristicValueToSubscribedCentral(request: CBATTRequest,
                                                           peripheralManager: CBPeripheralManager) {
        var dataToSend: Data = Data()
        if request.characteristic.uuid == BLEServiceCharacteristic.first.cbUUId {
            dataToSend = "Hello to First Characteristic!".data
            print("Read request received and responded to.")
        }
        if request.characteristic.uuid == BLEServiceCharacteristic.second.cbUUId {
            print("Read request received and responded to.")
            dataToSend = "Hello to Second Characteristic!".data
        }
        if request.characteristic.uuid == BLEServiceCharacteristic.json.cbUUId {
            print("Read request received and responded to.")
            let dict: [String: Any] = ["name": "Ashish",
                                        "age": 30,
                                        "isDeveloper": true]
            dataToSend = dict.toJSONData ?? Data()
        }
        if request.characteristic.uuid == BLEServiceCharacteristic.oneToOneChat.cbUUId {
            dataToSend = "Ping!".data
        }
        // Provide the value to be read.
        request.value = dataToSend
        // Respond to the request to complete the read operation.
        peripheralManager.respond(to: request, withResult: .success)
    }
}


extension PeripheralServerService: CBPeripheralManagerDelegate {
    // 3. This delegate method is called when the peripheral manager's state is updated.
    // It's the perfect place to check if the Bluetooth hardware is ready to use.
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            self.bleState = .poweredOn
        case .poweredOff:
            self.bleState = .poweredOff
        case .unauthorized:
            self.bleState = .unauthorized
        case .unsupported:
            self.bleState = .unsupported
        default:
            self.bleState = .unknown
        }
    }

    // This delegate method is called after a service has been successfully added.
    public func peripheralManager(_ peripheral: CBPeripheralManager,
                                  didAdd service: CBService,
                                  error: Error?) {
        if let error = error {
            print("Error adding service: \(error.localizedDescription)")
            return
        }
        self.isBLEAdvertising = true
        print("Service added successfully. Starting to advertise.")
        // 4. Start advertising your service.
        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [PeripheralServiceType.first.service_uuid],
            CBAdvertisementDataLocalNameKey: "My BLE Device" // Optional but good for recognition
        ]
        peripheralManager.startAdvertising(advertisementData)
    }

    // This delegate method is called when a central device requests to read a characteristic's value.
    public func peripheralManager(_ peripheral: CBPeripheralManager,
                                  didReceiveRead request: CBATTRequest) {
        
        self.sendDefaultCharacteristicValueToSubscribedCentral(request: request,
                                                               peripheralManager: peripheral)
    }
    
    // This delegate method is called when a central device writes a value to a characteristic.
    public func peripheralManager(_ peripheral: CBPeripheralManager,
                                  didReceiveWrite requests: [CBATTRequest]) {

        self.readCentralCharacteristicDataAndRespondBack(requests: requests,
                                                         peripheralManager: peripheral)
    }

    // This delegate method is called when a central subscribes to a characteristic's notifications.
    public func peripheralManager(_ peripheral: CBPeripheralManager,
                                  central: CBCentral,
                                  didSubscribeTo characteristic: CBCharacteristic) {
        characteristicsSubscribedByCentral.append(characteristic)
        print("Central \(central.identifier) subscribed to characteristic.")
        // Here you would begin sending notifications
        // For example:
        // let notificationData = "New data!".data(using: .utf8)!
        // peripheralManager.updateValue(notificationData, for: myCharacteristic, onSubscribedCentrals: nil)
    }
}
