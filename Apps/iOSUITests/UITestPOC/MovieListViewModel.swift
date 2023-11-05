//
//  ProductListViewModel.swift
//  UITestPOC
//
//  Created by Ashish Awasthi on 17/10/23.
//

import Foundation

struct Product: Decodable, Hashable {
    let id: Int
    let title: String
}

struct ProductResponseObj: Decodable {
    var products: [Product] = []
}

import CloudService

typealias APIHandler = (Bool, Error?) ->Void

class ProductListViewModel: NetWorkCall, ObservableObject {

    @Published var list: [Product] = []
    var allItems: [Product] = []

    func publishListModel() {
        self.list = allItems
    }

    func productList(handler: @escaping APIHandler) {

        let form = GetForm.init(url: "https://dummyjson.com/products",
                                headers: [:])

        cloudService.request(form: form, decodeClass: ProductResponseObj.self) { [weak self] result in
            guard let weakSelf = self else { return }
            switch(result) {
            case .success(let dict):
                if let model = dict[kResponseObj] as? ProductResponseObj {
                    weakSelf.allItems = model.products
                }
                handler(true, nil)
                break
            case .failure(let error):
                handler(false, error)
                break
            }
        }
    }
}

