//
//  CToObjectCToSwiftTest.swift
//  SwiftToObjectiveCToCPlusPlus
//
//  Created by Ashish Awasthi on 12/06/25.
//

import Testing
@testable import SwiftToObjectiveCToCPlusPlus

struct CToObjCToSwiftTests {

    @Test func testCDelegateToObjCToSwift() async throws {
        
        let viewModel = CCallViewModel()
        var result = ""
        try #require(await viewModel.makeRequestToCMethod { output in
            result = output ?? ""
        })
        sleep(1)
        #expect(result == "Hello from C async world!")
    }

    @Test func testCDelegateToObjCToSwiftWithParam() async throws {
        let viewModel = CCallViewModel()
        var result = "Hello from C async world!"
        guard let requestData = "Hello from C async world!".data(using: .utf8) else {
            return
        }
        try #require(await viewModel.makeRequestToCMethod(data: requestData) { output in
            result = output ?? ""
        })
        #expect(result == "Hello from C async world!")
    }

    @Test func sampleCallBackTest() async throws {
        let viewModel = CCallViewModel()
        var result = "Hello from C async world!"
        try #require(await viewModel.sampleCallBackRequest(str: result) { output in
            result = output ?? ""
        })
        #expect(result == "Hello from C async world!")
    }
}
