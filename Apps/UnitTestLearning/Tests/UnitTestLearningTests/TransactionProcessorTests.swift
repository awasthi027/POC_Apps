//
//  TransactionProcessorTests.swift
//  UnitTestLearning
//
//  Created by Ashish Awasthi on 24/09/24.
//

import Testing
import UnitTestLearning

struct TransactionProcessorTests {

    let transactionProcessor: TransactionProcessor = TransactionProcessor()

    @Test func testCalculateBalance_withValidTransactions() {

        let transactions = [
            Transaction(amount: 100.0, isValid: true),
            Transaction(amount: 200.0, isValid: true),
            Transaction(amount: -50.0, isValid: true)
        ]

        let balance = transactionProcessor.calculateBalance(transactions: transactions)
        #expect(balance == 250.0)
    }

    @Test func testCalculateBalance_withInvalidTransactions() {

        let transactions = [
            Transaction(amount: 100.0, isValid: true),
            Transaction(amount: 200.0, isValid: false),
            Transaction(amount: -50.0, isValid: true)
        ]
        let balance = transactionProcessor.calculateBalance(transactions: transactions)
        #expect(balance == 50.0)
    }

    @Test func testCalculateBalance_withAllInvalidTransactions() {
        let transactions = [
            Transaction(amount: 100.0, isValid: false),
            Transaction(amount: 200.0, isValid: false),
            Transaction(amount: -50.0, isValid: false)
        ]
        let balance = transactionProcessor.calculateBalance(transactions: transactions)
        #expect(balance == 0.0)
    }

    @Test func testCalculateBalance_withEmptyTransactions() {
        let transactions: [Transaction] = []
        let balance = transactionProcessor.calculateBalance(transactions: transactions)
        #expect(balance == 0.0)
    }
}
