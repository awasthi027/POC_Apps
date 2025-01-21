//
//  ContentViewModel.swift
//  DIP
//
//  Created by Ashish Awasthi on 18/01/25.
//
import Insurance
import Flight

class ContentViewModel {

    func bookFlight() -> String {
        let flight = FlightIMPL()
        return flight.bookFlight().message ?? ""
    }

    func bookFlightAndInsurance() -> String{
        let insurance = InsuranceIMPL()
        let flight = FlightIMPL(insurance: insurance)
        return flight.bookFlight().message ?? ""
    }

    func bookInsurance() -> String {
        let insurance = InsuranceIMPL()
        return insurance.purchaseInsurance().message ?? ""
    }

    func bookInsuranceAndFlight() -> String {
        let flight = FlightIMPL()
        let insurance = InsuranceIMPL(flight: flight)
        return insurance.purchaseInsurance().message ?? ""
    }
}
