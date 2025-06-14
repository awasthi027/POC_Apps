//
//  SwiftToObjectiveCToCPlusPlusTests.swift
//  SwiftToObjectiveCToCPlusPlusTests
//
//  Created by Ashish Awasthi on 13/04/25.
//

import Testing
@testable import SwiftToObjectiveCToCPlusPlus

struct CPlusPlusToObjCToSwiftTests {


    @Test func testCPlusPlusDelegateCall() async throws {
        let viewModel = HomeViewModel()
        var result = 0
        try #require(await viewModel.validateCPlusPlusDelegateCallBack(a: 10,
                                                                       b: 20) { output in
            result = output

        })
        #expect(result == 30)
    }

    @Test func testCPlusMultipleCallBack() async throws {
        let viewModel = HomeViewModel()
        var result = 0
        try #require(await viewModel.multipleCallBack(value: 100) { output in
            result += output
        })
        #expect(result == 200)
    }

    @Test func testCPlusCallBackWithMultipleParams() async throws {

        let viewModel = HomeViewModel()
        var resultCode = 0
        var resultMessage = ""

        try #require(await viewModel.callBackTwoParam(value: 10) { code, message in
            resultCode = code
            resultMessage = message
        })
        #expect(resultCode == 10)
        #expect(resultMessage == "")

        try #require(await viewModel.callBackTwoParam(value: 0) { code, message in
            resultCode = code
            resultMessage = message
        })
        #expect(resultCode == 0)
        #expect(resultMessage == "Unexpected inputs parameters")
    }
}

