//
//  HTTPProvider.swift

/*
******************************************************************
* COPYRIGHT (c) <<2020>> <<tanu inc  >>         *
*
 * All rights reserved                                           *
*
 * This software embodies materials and concepts which are       *
* confidential to <<Customer Name>> and is made available solely *
* pursuant to the terms of a written license agreement with      *
* <<tanu Product>>.                                            *
*
* Designed and Developed by tanu inc Industries, Inc.
.           *
*----------------------------------------------------------------*
* MODULE OR UNIT: CloudService                                *
*
* PROGRAMMER :  Tanuja Awasthi                                   *
* DATE       :  18/07/20                                         *
* VERSION    :  1.0                                              *
*
*----------------------------------------------------------------*
*
* MODULE SUMMARY : This is class where we are deciding to connect*
  with HTTP protocal
*
*
*
*
*----------------------------------------------------------------*
*
* TRACEABILITY RECORDS to SW requirements and detailed design :  *
* iOS 10 and onward
*
*
*----------------------------------------------------------------*
*
* MODIFICATION RECORDS                                           *
*
******************************************************************
*/

import Foundation

class HTTPProvider: BaseProvider {
    override internal func request(form: RequestForm, completeRequest: @escaping (_ result: CResult<[String : Any]>) -> Void)  {
        super.request(form: form) { (result) in
            if result.isSuccess {
                self.dataRequest(form: form) { (result) in
                    completeRequest(result)
                }
            }else {
                completeRequest(result)
            }
        }
    }
}

extension HTTPProvider {
 
}
