// Utility functions and sample data for BLEDevice
import Foundation

/// A sample dictionary with 10 bytes
let sampleBytesDictionary: [String: UInt8] = [
    "byte0": 0x00,
    "byte1": 0x01,
    "byte2": 0x02,
    "byte3": 0x03,
    "byte4": 0x04,
    "byte5": 0x05,
    "byte6": 0x06,
    "byte7": 0x07,
    "byte8": 0x08,
    "byte9": 0x09
]

extension Dictionary where Value == UInt8 {
    /// Encodes the values of the dictionary as raw bytes (Data)
    var rawBytesData: Data {
        return Data(self.values)
    }
}
