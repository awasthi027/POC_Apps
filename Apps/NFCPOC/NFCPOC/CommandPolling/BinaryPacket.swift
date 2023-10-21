//
//  BinaryPacket.swift
//  NFCPOC
//
//  Created by Ashish Awasthi on 20/10/23.
//

import Foundation

class BinaryPacket {

    var payload: Data

    init(payload: Data) {
        self.payload = payload
    }
}

extension BinaryPacket {

    internal func payloadData(_ start: Int, _ length: Int) ->Data {
       return payload.subtract(start, length)
    }
    /* Find  UInt8  8 bit or 1 bytes value  from by passing start and end index */
    internal func uint8(_ start: Int ) ->UInt8 {
       return payload.subtract(start, 1).nsData.uint8
    }
    /* Find  UInt16  16 bit or 2 bytes value  from by passing start and end index */
    internal func uint16(_ start: Int) ->UInt16 {
       return payload.subtract(start, 2).nsData.uint16
    }
    /* Find  UInt32  32 bit or 4 bytes value  from by passing start and end index */
    internal func uint32(_ start: Int) ->UInt32 {
      return payload.subtract(start, 4).nsData.uint32
    }
    /* Find  UInt64 64 bit or 8 bytes value  from by passing start and end index */
    internal func uint64(_ start: Int) ->UInt64 {
       return payload.subtract(start, 8).nsData.uint64
    }
    /* Find double value  from by passing start and end index */
    internal func doubleValue(_ start: Int, length: Int) ->Double {
      return payload.subtract(start, length).nsData.doubleValue
    }
    /* Find string  from by passing start and end index */
    internal func stringValue(_ start: Int, length: Int) ->String {
      return payload.subtract(start, length).nsData.stringUTF8!
    }
    /* Find data from by passing start and end index */
    internal func data(_ start: Int, length: Int) ->Data {
      return payload.subtract(start, length)
    }
}
