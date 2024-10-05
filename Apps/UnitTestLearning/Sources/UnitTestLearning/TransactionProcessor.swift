//
//  TransactionProcessor.swift
//  UnitTestLearning
//
//  Created by Ashish Awasthi on 24/09/24.
//

import Foundation

public struct Transaction {
    
    public let amount: Double
    public let isValid: Bool
    public init(amount: Double, isValid: Bool) {
        self.amount = amount
        self.isValid = isValid
    }
}

open class TransactionProcessor {
    public init() {}
    public func calculateBalance(transactions: [Transaction]) -> Double {
        return transactions.filter { $0.isValid }.reduce(0) { $0 + $1.amount }
    }
}
