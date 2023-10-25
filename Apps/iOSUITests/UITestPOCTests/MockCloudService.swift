//
//  MockCloudService.swift
//  TEZ888Tests
//
//  Created by Tanuja Awasthi on 13/10/23.
//

import Foundation

@testable import UITestPOC

import CloudService

class MockCloudService: CloudService {
    /// MOCk Result data
    var resultData: Data?
    // MOCK error object
    var error: Error?
    
     override func request<T: Decodable>(form: RequestForm, decodeClass: T.Type,
                                    _ isRetrunURLResp: Bool = true,
                                      priority: OperationPriority = .high, 
                                    completed: @escaping (_ result: CResult<[AnyHashable : Any]>) -> Void) {
         guard let data = self.resultData else {
             if let error = self.error {
                 completed(.failure(error))
             }
             return
         }
         var apiRespDict: [String : Any] = [:]
         let isBaseDecode = decodeClass is BaseDecodingModel.Type
        if !isBaseDecode {  /* Convert data object as per give class */
            RW.process(.success(data), decodeClass) { (result) in
                if result.isSuccess, let dict = result.value, let respObj = dict[kResponseObj]  {
                    apiRespDict[kResponseObj] = respObj
                    completed(.success(apiRespDict))
                }else {
                    if let item = result.error {
                        completed(.failure(item))
                    } else {
                        if let error = self.error {
                            completed(.failure(error))
                        }
                    }
                }
            }
        } else { /* raw data object, user can parse data at their side */
            completed(.success(apiRespDict))
        }
    }

    static let defaultError: NSError = NSError(domain:"VumeAPI", code: 401, userInfo: nil)
}

