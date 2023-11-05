//
//  ProductListViewTests.swift
//  UITestPOCTests
//
//  Created by Ashish Awasthi on 23/10/23.
//

import XCTest
@testable import UITestPOC

class ProductListViewTests: BaseTests {

    func testProductListApiSuccess() {

        @ReadBundleFileData(name: "productList", type: "json", defaultValue: nil)
        var resultData: Data?

        let viewModel = ProductListViewModel()
        mockCloudService.resultData = resultData
        viewModel.cloudService = mockCloudService
        let successExpection = expectation(description: "Expecting to success Product list api")
        viewModel.productList { isSuccess, error in
            guard isSuccess,
                  let couponItem = viewModel.allItems.first else {
                XCTFail("Missing Product item")
                return
            }
            XCTAssertEqual(viewModel.allItems.count, 30)
            XCTAssertNotNil(couponItem.id)
            XCTAssertNotNil(couponItem.title)
            successExpection.fulfill()

        }
        wait(for: [successExpection], timeout: 1.0)
    }

    func testProductListApiApiFail() {
        let errorObject = MockCloudService.defaultError
        let viewModel = ProductListViewModel()
        let mockCloudService = MockCloudService()
        mockCloudService.error = errorObject
        viewModel.cloudService = mockCloudService

        let successExpection = expectation(description: "Expecting to fail Product list api")
        viewModel.productList { isSuccess, error in
            XCTAssertFalse(isSuccess)
            XCTAssertNotNil(error)
            guard  let error = error as? NSError else {
                XCTFail("Missing error item")
                return
            }
            XCTAssertEqual(error.code, 401)
            successExpection.fulfill()

        }
        wait(for: [successExpection], timeout: 1.0)
    }

}
