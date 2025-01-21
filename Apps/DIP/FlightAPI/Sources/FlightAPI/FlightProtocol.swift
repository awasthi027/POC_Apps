//
//  FlightProtocol.swift
//  FlightAPI
//
//  Created by Ashish Awasthi on 19/01/25.
//

protocol FlightBookingInfoProtocol {

    var pnr: String { get  }
    var bookingId: String { get  }
    var source: String { get  }
    var destination: String { get  }
    var insuranceId: String? { get  }
    var message: String? { get  }
}

public struct FlightBookingInfo: FlightBookingInfoProtocol {
    public var pnr: String

    public var bookingId: String

    public var source: String

    public var destination: String

    public var insuranceId: String?
    public var message: String?

    public init(pnr: String,
                bookingId: String,
                source: String,
                destination: String,
                insuranceId: String? = nil,
                message: String? = nil) {
        self.pnr = pnr
        self.bookingId = bookingId
        self.source = source
        self.destination = destination
        self.insuranceId = insuranceId
        self.message = message
    }
}


public protocol FlightProtocol {
    func bookFlight() -> FlightBookingInfo
}
