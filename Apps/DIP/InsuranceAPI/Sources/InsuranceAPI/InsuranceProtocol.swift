//
//  InsuranceProtocol.swift
//  InsuranceAPI
//
//  Created by Ashish Awasthi on 19/01/25.
//

public protocol InsuranceInfoProtocol {

    var bookingId: String { get }
    var insuranceId: String { get }
    var startDate: String  { get }
    var expiryDate: String  { get }
    var pnr: String? { get }
    var message: String? { get }
}

public struct InsuranceInfo: InsuranceInfoProtocol {

    public var bookingId: String
    
    public var insuranceId: String
    
    public var startDate: String
    
    public var expiryDate: String

    public var pnr: String?

    public var message: String?

    public init(bookingId: String,
         insuranceId: String,
         startDate: String,
         expiryDate: String,
         pnr: String? = nil,
         message: String? = nil) {
        self.bookingId = bookingId
        self.insuranceId = insuranceId
        self.startDate = startDate
        self.expiryDate = expiryDate
        self.pnr = pnr
        self.message = message
    }
}

public protocol InsuranceProtocol: AnyObject {
    func purchaseInsurance() -> InsuranceInfo
}
