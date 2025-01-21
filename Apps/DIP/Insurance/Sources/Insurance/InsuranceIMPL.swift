//
//  InsuranceIMPL.swift
//  Insurance
//
//  Created by Ashish Awasthi on 19/01/25.
//

import InsuranceAPI
import FlightAPI

public class InsuranceIMPL: InsuranceProtocol {

    public var flight: FlightProtocol?

    public init(flight: FlightProtocol? = nil) {
        self.flight = flight
    }

    public func purchaseInsurance() -> InsuranceInfo {
        var message: String = "Purchaged Insurance"
        // Insurance purchasing logic
        let flightInfo = self.flight?.bookFlight()
        if let item = flightInfo?.message {
            message += " and " + item
        }
        return InsuranceInfo(bookingId: "Insu_ABC",
                             insuranceId: "Insu_ABC_ID",
                             startDate: "Jan 2025", expiryDate: "Jan 2026",
                             pnr: flightInfo?.pnr ?? "",
                             message: message)
    }
}
