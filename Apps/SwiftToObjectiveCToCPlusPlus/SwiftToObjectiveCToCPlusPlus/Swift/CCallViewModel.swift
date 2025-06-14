//
//  CCallViewModel.swift
//  SwiftToObjectiveCToCPlusPlus
//
//  Created by Ashish Awasthi on 12/06/25.
//

class CCallViewModel: NSObject {
    let objeAsynC: CAsyncCaller = CAsyncCaller()
    var asyncHandler: ((String?) -> Void)? = nil

    override init() {
        super.init()
        self.objeAsynC.delegate = self
    }

    func makeRequestToCMethod(completion: @escaping (String?) -> Void) {
        self.asyncHandler = completion
        objeAsynC.startAsyncOperation()
    }

    func makeRequestToCMethod(data: Data,
                              completion: @escaping (String?) -> Void) {
        objeAsynC.performAsyncOperation(withInput: data) { str, error in
            completion(str)
        }
    }

    func sampleCallBackRequest(str: String,
                              completion: @escaping (String?) -> Void) {
        objeAsynC.sampleCallBackRequest(str) { str, error in
            completion(str)
        }
    }
}

extension CCallViewModel: CAsyncCallbackDelegate {

    func didReceive(_ str: String!, error: (any Error)!) {
        //self.asyncHandler?(str)
    }

    func didReceive(_ data: Data!, error: (any Error)!) {
        let str = data.toString
        self.asyncHandler?(str)
        print("DelegateCallNBack: \(String(describing: str))")
    }
}

extension Data {
    var toString: String? {
        return String(data: self, encoding: .utf8)
    }
}

