//
//  FlightBooking.swift
//  Flight
//
//  Created by Ashish Awasthi on 18/01/25.
//


import Foundation
import InsuranceAPI
import FlightAPI

public class FlightIMPL: FlightProtocol {

    public weak var insurance: InsuranceProtocol?

    public init(insurance: InsuranceProtocol? = nil) {
        self.insurance = insurance
    }

    public func bookFlight() -> FlightBookingInfo {
        var message: String = "Booked flight"
        let insuranceInfo = self.insurance?.purchaseInsurance()
        if let item = insuranceInfo?.message {
            message += " and " + item
        }
        return FlightBookingInfo(pnr: "ABC",
                                 bookingId: "ABC_ID",
                                 source: "BLR",
                                 destination: "GWL",
                                 insuranceId: insuranceInfo?.insuranceId ?? "",
                                 message: message)
    }
}
