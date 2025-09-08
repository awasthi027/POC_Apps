//
//  BLEUtils.swift
//  
//
//  Created by Ashish Awasthi on 29/08/25.
//

// 1. Define UUIDs for your service and characteristic
import CoreBluetooth

public enum PeripheralServiceType {
    case first

    internal var service_uuid: CBUUID {
        switch self {
        case .first: return CBUUID(string: "A671569B-7D8C-479D-83A8-16629A39266E")
        }
    }
}

public enum BLEServiceCharacteristic {

    case first
    case second
    case json
    case oneToOneChat
   internal var cbUUId: CBUUID {
        switch self {
        case .first: return CBUUID(string: "6B9F2A90-5645-4299-8D7F-8532F1E5E79A")
        case .second: return CBUUID(string: "6B9F2A90-5645-4299-8D7F-8532F1E5E79B")
        case .json: return CBUUID(string: "6B9F2A90-5645-4299-8D7F-8532F1E5E79C")
        case .oneToOneChat: return CBUUID(string: "6B9F2A90-5645-4299-8D7F-8532F1E5E79D")
        }
    }
}

public enum BLEState {

    case poweredOn
    case poweredOff
    case unauthorized
    case unsupported
    case unknown

   public var state: String {
        switch self {
        case .poweredOn: return "Powered On"
        case .poweredOff: return "Powered OFF"
        case .unauthorized: return "unauthorized"
        case .unsupported: return "unsupported"
        case .unknown:  return "unknown"
        }
    }
}


import Foundation

public extension String {
    /// Converts the String to a Data object using UTF-8 encoding.
    var data: Data {
        guard let data = self.data(using: .utf8) else {
            return Data()
        }
        return data
    }
}

public extension Data {
    /// Converts the Data object to a String using UTF-8 encoding.
    var string: String {
        guard let string = String(data: self, encoding: .utf8) else {
            return ""
        }
        return string
    }
}

public extension Dictionary {

  var toJSONData: Data? {
        guard JSONSerialization.isValidJSONObject(self) else { return nil }
        return try? JSONSerialization.data(withJSONObject: self, options: [])
    }
}

public extension Data {
    
    var toDictionary: [String: Any]? {
        (try? JSONSerialization.jsonObject(with: self, options: [])) as? [String: Any]
    }
}

extension Dictionary where Value == UInt8 {
    /// Encodes the values of the dictionary as raw bytes (Data)
    var rawBytesData: Data {
        return Data(self.values)
    }
}
