//
//  HomeViewModel.swift
//  SwiftToObjectiveCToCPlusPlus
//
//  Created by Ashish Awasthi on 13/04/25.
//

import Foundation

protocol APIProtocol {

    func combinedName(firstName: String,
                      lastName: String)
    func addNumber(a: Int32,
                   b: Int32)

    func makeGetRequest(url: String,
                        completion: @escaping (String?) -> Void)
    func validateCPlusPlusDelegateCallBack(a: Int32,
                                           b: Int32,
                                           completion: @escaping (Int) -> Void)
    func multipleCallBack(value: Int32,
                          completion: @escaping (Int) -> Void)

    func callBackTwoParam(value: Int32,
                          completion: @escaping (Int, String) -> Void)
}

class HomeViewModel: APIProtocol,
                     ObservableObject {

    @Published var result: String = ""
    let cPlusPlusWrapper: SimpleCPlusPlusWrapper = SimpleCPlusPlusWrapper()
    let objeAsync: CPlusPlusAsyncCommunication = CPlusPlusAsyncCommunication()
    
    func combinedName(firstName: String,
                      lastName: String)  {
        self.result = cPlusPlusWrapper.combindMyName(firstName,
                                                     lastName: lastName)
    }

    func addNumber(a: Int32,
                   b: Int32)  {
        self.result = "\(self.cPlusPlusWrapper.addNumber(a, b: b))"
    }

    func makeGetRequest(url: String,
                        completion: @escaping (String?) -> Void) {
        self.cPlusPlusWrapper.makeGetRequest(url,
                                             completeHandler: { responseStr, error_ in
            DispatchQueue.main.async {
                self.result = responseStr ?? ""
            }
            completion(responseStr)
        })
    }

    func validateCPlusPlusDelegateCallBack(a: Int32,
                                           b: Int32,
                                           completion: @escaping (Int) -> Void) {
        self.objeAsync.addNumber(a, second: b) { result, error in
            completion(result)
        }
    }

    func multipleCallBack(value: Int32,
                          completion: @escaping (Int) -> Void) {

        self.objeAsync.multipleCallBack(value) { result, error in
            completion(result)
        }
    }

    func callBackTwoParam(value: Int32,
                          completion: @escaping (Int, String) -> Void) {

        self.objeAsync.setupCallbacks(value) { code, message in
            completion(Int(code), message ?? "")
        }
    }
}
