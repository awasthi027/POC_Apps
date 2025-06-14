//
//  BasicCPlusPlusToObjCToSwiftTest.swift
//  SwiftToObjectiveCToCPlusPlus
//
//  Created by Ashish Awasthi on 13/06/25.
//

import Testing
@testable import SwiftToObjectiveCToCPlusPlus

struct BasicCPlusPlusToObjCToSwiftTest {

    @Test func testBasicCombindString() async throws {
        let viewModel = HomeViewModel()
        viewModel.combinedName(firstName: "Ashish",
                                        lastName:"Awasthi")
        #expect(viewModel.result == "Ashish Awasthi")
    }

    @Test func testBasicSum() async throws {
        let viewModel = HomeViewModel()
        viewModel.addNumber(a: 10,
                            b: 20)
        #expect(viewModel.result == "30")
    }

    @Test func testAPICall() async throws {
        let viewModel = HomeViewModel()
        var result: String? = nil
        try #require(await viewModel.makeGetRequest(url: "https://dummyjson.com/products") { response in
            result = response
        })
        #expect(result != nil)
    }
}
