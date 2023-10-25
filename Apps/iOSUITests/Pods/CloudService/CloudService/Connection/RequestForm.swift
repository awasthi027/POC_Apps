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
* MODULE SUMMARY : This is independent class which we are using
  for returnig HTTP protocal reference from                      *
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

public enum RequestType {
    case data
    case uploadFile
    case downloadFile
    case stream
}
public class RequestForm {
    ///   - id: Keep remember request id, It will required, when you want to cancel request
    public private(set) var id: UUID = UUID()
    var requestType: RequestType
    public var method: HTTPMethod = .get
    public var url: String = ""
    public var headers: HTTPHeaders
    internal var provider: HTTPProvider = HTTPProvider()
    internal var session: URLSession!
    public init(url: String, methodType: HTTPMethod = .get,headers: HTTPHeaders, requestType: RequestType = .data) {
        self.url = url.validateURL
        self.method = methodType
        self.headers = headers
        self.requestType = requestType
    }
}

public class GetForm: RequestForm {
    
}

public class PostForm: RequestForm {
   public var params: Parameters
    public  init(url: String,headers: HTTPHeaders ,params: Parameters, method: HTTPMethod = .post) {
        self.params = params
        super.init(url: url, methodType:method, headers: headers)
    }
}
public class DeleteForm: RequestForm {
   public var params: Parameters
    public  init(url: String,headers: HTTPHeaders ,params: Parameters, method: HTTPMethod = .delete) {
        self.params = params
        super.init(url: url, methodType:method, headers: headers)
    }
}

public class PatchForm: RequestForm {
   public var params: Parameters
    public  init(url: String,headers: HTTPHeaders ,params: Parameters, method: HTTPMethod = .patch) {
        self.params = params
        super.init(url: url, methodType:method, headers: headers)
    }
}

public class PutForm: RequestForm {
   public var params: Parameters
    public  init(url: String,headers: HTTPHeaders ,params: Parameters) {
        self.params = params
        super.init(url: url, methodType:.put, headers: headers)
    }
}

public class UploadForm: RequestForm {
    var params: Parameters
    var dataKey: String
    var data: Data
    var fileName: String
    var mimeType: String
    public init(url: String, param: Parameters, method: HTTPMethod = .post, fileName: String, dataKey: String, data: Data, headers: HTTPHeaders, mimeType: String) {
        self.params = param
        self.dataKey = dataKey
        self.data = data
        self.mimeType = mimeType
        self.fileName = fileName
        super.init(url: url, methodType: method, headers: headers, requestType: .uploadFile)
    }
}

public class DownloadForm: RequestForm {
    var params: Parameters
    var mimeType: String
    var fileName: String
    var subDirPath: String
    public init(url: String, param: Parameters = Parameters.init(), headers: HTTPHeaders = HTTPHeaders.init(), mimeType: String = "", fileName: String = "", subDirPath: String, method: HTTPMethod = .get) {
        self.params = param
        self.mimeType = mimeType
        self.fileName = fileName
        self.subDirPath = subDirPath
        super.init(url: url, methodType: method, headers: headers, requestType: .downloadFile)
    }
}

extension String {
    var validateURL: String {
        return self.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    }

}
