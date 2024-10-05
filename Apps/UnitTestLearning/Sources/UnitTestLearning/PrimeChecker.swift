//
//  PrimeChecker.swift
//  UnitTestLearning
//
//  Created by Ashish Awasthi on 24/09/24.
//

import Foundation

open class PrimeChecker {

    public init() { }
    public func isPrime(_ number: Int) -> Bool {
        guard number > 1 else { return false }
        for i in 2..<number {
            if number % i == 0 {
                return false
            }
        }
        return true
    }
}
