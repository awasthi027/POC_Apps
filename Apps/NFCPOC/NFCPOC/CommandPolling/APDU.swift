//
//  APDU.swift
//  NFCPOC
//
//  Created by Ashish Awasthi on 20/10/23.
//

import Foundation

struct APDU {
    /*!
     @method initWithCla:ins:p1:p2:data:type:

     @abstract
        Creates a new APDU binary command from a list of parameters specified by the ISO/IEC 7816-4 standard.

     @param cla
        The instruction class.
     @param ins
        The instruction number.
     @param p1
        The first instruction paramater byte.
     @param p2
        The second instruction paramater byte.
     @param data
        The command data.
     @param type
        The type of the APDU, short or extended.

     @returns
        The newly initialized object or nil if the data param is empty or if the data length is too large for a short APDU.
     */
    var cla: UInt8
    var ins: UInt8
    var p1: UInt8
    var p2: UInt8
    var data: Data
    var type: APDUType

    init(cla: UInt8,
         ins: UInt8,
         p1: UInt8,
         p2: UInt8,
         data: Data,
         type: APDUType) {
        self.cla = cla
        self.ins = ins
        self.p1 = p1
        self.p2 = p2
        self.data = data
        self.type = type
    }

    var apduData: Data {
        var commandData = Data()
        commandData.appendUInt8(cla)
        commandData.appendUInt8(ins)
        commandData.appendUInt8(p1)
        commandData.appendUInt8(p2)
        if self.data.count > 0 {
            commandData.appendUInt8(UInt8(self.data.count))
            commandData.append(data)
        }
//        var commandPlusData = Data(capacity: commandData.count + 1)
//        commandPlusData.appendUInt8(0x00)
//        commandPlusData.append(commandData)
        return commandData
    }
}
