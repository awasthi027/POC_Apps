
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
* DATE       :  19/07/20                                         *
* VERSION    :  1.0                                              *
*
*----------------------------------------------------------------*
*
* MODULE SUMMARY : This is independent class which we are using  *
  adding task in queqe we can track the queue status             *
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

class GenericOperation: BaseOperation {
    
    var form: RequestForm
    var provider: BaseProvider
    var result: CResult<[String : Any]>? = nil
    var id: UUID
    init(id: UUID, form: RequestForm) {
        self.id = id
        self.form = form
        self.provider = form.provider
    }
    
    override func main() {
        guard isCancelled == false else {
            finish(true)
            return
        }
        executing(true)
        self.provider.request(form: self.form) { (result) in
            self.result = result
            self.executing(false)
            self.finish(true)
        }
    }
}
