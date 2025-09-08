//
//  CentralClientService.swift
//  BLEDevice
//
//  Created by Ashish Awasthi on 29/08/25.
//
import CoreBluetooth

// This struct is used to keep track of discovered peripherals and their last seen time.
struct DiscoveredPeripheral {
    let peripheral: CBPeripheral
    var lastSeen: Date
}

// The time in seconds after which a peripheral is considered lost.
let TIMEOUT_INTERVAL: TimeInterval = 60.0

open class CentralClientService: NSObject, ObservableObject {

    private var centralManager: CBCentralManager!
    @Published public var dataReceived: String = ""
    @Published public var isBLEConnected: Bool = false
    @Published public var bleState: BLEState = .unknown
    var availableCharacteristicForWriteData: [CBCharacteristic] = []

    // A dictionary to store discovered peripherals, keyed by their UUID.
    var discoveredPeripherals: [UUID: DiscoveredPeripheral] = [:]

    // A Array to store discovered peripherals
    var connentedPeripherals: [CBPeripheral] = []

    // This one is for errors, passing an Error object.
   public var onChatCommunication: ((String) -> Void)?

    // A timer to periodically check for timed-out peripherals.
    var cleanupTimer: Timer?

    public override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
        // Start the cleanup timer to regularly check for timed-out devices.
        self.cleanupTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(checkTimeouts), userInfo: nil, repeats: true)
    }

    // MARK: - Timeout Logic

    @objc func checkTimeouts() {
        let now = Date()
        var timedOutDevices: [UUID] = []

        // Find all peripherals that have not been seen within the timeout interval.
        for (uuid, peripheral) in discoveredPeripherals {
            if now.timeIntervalSince(peripheral.lastSeen) > TIMEOUT_INTERVAL {
                timedOutDevices.append(uuid)
            }
        }

        // Remove the timed-out peripherals from the list.
        for uuid in timedOutDevices {
            if let peripheral = discoveredPeripherals.removeValue(forKey: uuid) {
                print("Peripheral \(peripheral.peripheral.identifier.uuidString) timed out and is no longer available.")
                self.isBLEConnected = false
            }
        }
    }

    public func startScanning() {
        guard centralManager.state == .poweredOn else {
            print("Cannot scan - Bluetooth not ready")
            return
        }
        centralManager.scanForPeripherals(withServices: [PeripheralServiceType.first.service_uuid], options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
        print("Scanning started...")
    }

    // MARK: - Public Methods

    public func sendMessage(periPheralType: PeripheralServiceType = .first,
                            characteristic: BLEServiceCharacteristic,
                            data: Data) {
        guard let peripheral = self.connentedPeripherals.first,
              let characteristic = self.availableCharacteristicForWriteData.first(where: { $0.uuid == characteristic.cbUUId }) as? CBCharacteristic else {
            print("Cannot send message - not connected, This characteristic is not available to write data: \(characteristic.cbUUId)")
            return
        }
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }

    public func disconnect(periPheralType: PeripheralServiceType = .first) {

        if let peripheral = self.connentedPeripherals.first {
            centralManager.cancelPeripheralConnection(peripheral)
            self.isBLEConnected = false
            self.dataReceived = ""
        }
    }
}

extension CentralClientService:  CBCentralManagerDelegate {
    // MARK: - CBCentralManagerDelegate
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("Central manager state updated: \(central.state.rawValue)")
        switch central.state {
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

    public func centralManager(_ central: CBCentralManager,
                               didDiscover peripheral: CBPeripheral,
                               advertisementData: [String: Any],
                               rssi RSSI: NSNumber) {
        print("Discovered peripheral: \(peripheral.name ?? "Unknown")")
        // Connect to the peripheral
        let now = Date()
        let discovered = DiscoveredPeripheral(peripheral: peripheral, lastSeen: now)
        // Update the last seen time for this peripheral.
        discoveredPeripherals[peripheral.identifier] = discovered
        centralManager.connect(peripheral, options: nil)
    }

    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to peripheral: \(peripheral.name ?? "Unknown")")
        connentedPeripherals.append(peripheral)
        peripheral.delegate = self
        peripheral.discoverServices(nil)
        self.isBLEConnected = true
    }

    public func centralManager(_ central: CBCentralManager,
                               didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect: \(error?.localizedDescription ?? "Unknown error")")
        self.isBLEConnected = false
    }

}
extension CentralClientService: CBPeripheralDelegate {
    // MARK: - CBPeripheralDelegate

    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            print("Discovered service: \(service.uuid)")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral,
                           didDiscoverCharacteristicsFor
                           service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            print("Discovered characteristic: \(characteristic.uuid)")
            if characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
            if characteristic.properties.contains(.read) {
                peripheral.readValue(for: characteristic)
            }
            availableCharacteristicForWriteData.append(characteristic)
        }
    }

    public func peripheral(_ peripheral: CBPeripheral,
                           didUpdateValueFor characteristic: CBCharacteristic,
                           error: Error?) {
        guard error == nil,
                let data = characteristic.value else {
            print("Error reading value: \(error?.localizedDescription ?? "Unknown error")")
            return
        }
        self.dataReceived.append("\n\(data.string)")
        if characteristic.uuid == BLEServiceCharacteristic.oneToOneChat.cbUUId,
           let updateChat = self.onChatCommunication {
                updateChat(data.string)
        }
    }
}

public extension CentralClientService {

    func peripheralName(periPheralType: PeripheralServiceType = .first) -> String {
        guard let peripheral = self.connentedPeripherals.first else {
            return "No Peripheral Connected"
        }
        return peripheral.name ?? "Unknown Name"
    }
}
