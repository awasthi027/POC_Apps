//
//  MemoryLeakExampleTests.swift
//  SwizzlingPOCTests
//
//  Created by Ashish Awasthi on 19/11/24.
//


import XCTest
@testable import SwizzlingPOC

class MemoryLeakExampleTests: XCTestCase {
    
    func testMemoryLeak() {
        let sut = Server()
        sut.add(client: Client(server: sut))
        
        addTeardownBlock { [weak sut] in
            XCTAssertNil(sut, "Potential memory leak, this object should have been deallocated ⚠️")
        }
    }
}
