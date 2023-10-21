//
//  DataExtension.swift
//  NFCPOC
//
//  Created by Ashish Awasthi on 20/10/23.
//

import Foundation

extension Data {
  /* Append 8 bit values between 0 .....255 */
    public mutating func appendUInt8(_ value: UInt8) {
        let array:[UInt8] = [value]
        let data = NSData(bytes: array, length:MemoryLayout<UInt8>.size)
        self.append(data as Data)
    }
    /* Append 16 bit 2 bytes values between */
    public mutating func appendUInt16(_ value:UInt16) {
        let array:[UInt16] = [value]
        let data = NSData(bytes: array, length:MemoryLayout<UInt16>.size)
        self.append(data as Data)
    }
      /* Append 32 bit 4 bytes values between */
    public mutating func appendUInt32(_ value: UInt32) {
     let array:[UInt32] = [value]
     let data = NSData(bytes: array, length:MemoryLayout<UInt32>.size)
     self.append(data as Data)
    }

     /* Append 64 bit 8 bytes values between */
    public mutating func appendUInt64(_ value: UInt64) {
        let array:[UInt64] = [value]
        let data = NSData(bytes: array, length:MemoryLayout<UInt64>.size)
        self.append(data as Data)
    }
    /* Append 64 bit 8 bytes double values between */
    public mutating func appendDouble(_ value: Double) {
        let array:[Double] = [value]
        let data = NSData(bytes: array, length:MemoryLayout<UInt64>.size)
        self.append(data as Data)
    }
       /* Append string length and string  */
    public mutating func appendString(_ string: String) {
        if let data = string.data(using: String.Encoding.utf8, allowLossyConversion: true) {
            let strDataLength: Int = (data.count)// First add string data legnth then address string.
            let uIntValue:UInt16 = UInt16(strDataLength)
            self.appendUInt16(uIntValue)
            self.append(data)
        }
    }

}
extension Data {
    /* Gets bytes array from the data object (Data) */
    public var bytes : [UInt8] {
        return [UInt8](self)
    }

    var string: String {
        let str = String(decoding: self, as: UTF8.self)
        return str
    }
    /* Substract data object by passing start bytes and needed number of bytes called length*/
    public func subtract(_ start: Int, _ length: Int) ->Data {
        precondition(self.count >=  start + length,
                     "Invalid data range range. trying to find out of bound data")
        let allBytes = Array(Data(bytes: self.bytes, count: self.count))
        let partBytes = Array(allBytes[start..<start + length])
        let dataPart = Data(bytes: partBytes, count: partBytes.count)
        return dataPart
    }
    public var nsData: NSData {
        return self as NSData
    }

    var hexDescription: String {
        return reduce(" ") {$0 + String(format: "%02x", $1)}
    }

   

}

extension NSData {
    /* Convert data in UInt8 */
    var uint8: UInt8 {
        get {
            var number: UInt8 = 0
            self.getBytes(&number, length: MemoryLayout<UInt8>.size)
            return number
        }
    }
    /* Convert data in UInt16 */
    public var uint16: UInt16 {
        get {
            var number: UInt16 = 0
            self.getBytes(&number, length: MemoryLayout<UInt16>.size)
            return number
        }
    }
    /* Convert data in UInt32 */
    public var uint32: UInt32 {
        get {
            var number: UInt32 = 0
            self.getBytes(&number, length: MemoryLayout<UInt32>.size)
            return number
        }
    }
    /* Convert data in UInt64 */
    var uint64: UInt64 {
        get {
            var number: UInt64 = 0
            self.getBytes(&number, length: MemoryLayout<UInt64>.size)
            return number
        }
    }
    /* Convert data in Double */
    var doubleValue: Double {
        get {
            var number: Double = 0
            self.getBytes(&number, length: MemoryLayout<Double>.size)
            return number
        }
    }
    var stringUTF8: String? {
        get {
            return NSString(data: self as Data, encoding: String.Encoding.utf8.rawValue) as String?
        }
    }

    var asData: Data {
       return Data(self)
    }
}
