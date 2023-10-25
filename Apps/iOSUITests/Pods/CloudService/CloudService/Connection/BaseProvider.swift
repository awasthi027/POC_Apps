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
public let kRespData = "data"
public let KRespJson = "json"
public let kRespStr = "string"
public let kResponse = "response"
public let kResponseObj = "responseobj"
public let kDataSize = "size"
public let kStatus = "status"
public let kDestinationURL = "destURL"

protocol BaseProviderProtocol:AnyObject {
    func baseProvider(_ base: BaseProvider, didPrintLog text: String)
}
class BaseProvider {
    weak var delegate: BaseProviderProtocol?
    internal func request(form: RequestForm, completeRequest: @escaping (_ result: CResult<[String : Any]>) -> Void)  {
        if ReachabilityManager.shared.isNetworkAvailable == false {
            completeRequest(.failure(CSError.noInternet.error(msg: "")))
            ReachabilityManager.shared.displayInternetStatus()
            return
        }
        completeRequest(.success([kRespData : Data()]))
    }
    
    // MARK: Check reques type
    internal func dataRequest(form: RequestForm, successHandler: @escaping(_ result: CResult<[String : Any]>)->Void)  {
        //Implementing URLSession
        switch form {
        case let fItem as PatchForm:
            self.patchData(form: fItem) { (result) in
                successHandler(result)
            }
            break
        case let fItem as PostForm:
            self.postData(form: fItem) { (result) in
                successHandler(result)
            }
            break
        case let fItem as DeleteForm:
            self.deleteData(form: fItem) { (result) in
                successHandler(result)
            }
            break
        case let fItem as PutForm:
            self.putData(form: fItem) { (result) in
                successHandler(result)
            }
            break
        case let fItem as GetForm:
            self.forData(form: fItem) { (result) in
                successHandler(result)
            }
            break
        case let fItem as UploadForm:
            self.upload(form: fItem) { (result) in
                successHandler(result)
            }
            break
        case let fItem as DownloadForm:
          self.upload(form: fItem) { (result) in
              successHandler(result)
            }
            break
        default:
            fatalError("Attempted to perform unsupported Request subclass: \(type(of: request))")
            break
        }
    }
     // MARK: Request for data
    
    internal func forData(form: GetForm, successHandler: @escaping(_ result: CResult<[String : Any]>)->Void)  {
        //Implementing URLSession
        guard let req = URLRequest.request(form.url, method: form.method, headers: form.headers) else {
            successHandler(.failure(CSError.invalidRequest.error(msg: "")))
            return
        }
        self.delegate?.baseProvider(self, didPrintLog: "Req URL:- \(form.url))\nMethod:- \(form.method.rawValue)\nHeaders- \(form.headers)")
        let defaultSession = form.session
        defaultSession?.dataTask(with: req) { (data, response, error) in
            if let errorItem = error {
                FSLogError(errorItem.localizedDescription)
                successHandler(.failure(errorItem))
            }
            guard let data = data else { return }
            RW.validJson(from: data, complete: { (validData, parseError) in
                if let data = validData, let resp = response {
                    successHandler(.success([kRespData : data, kResponse : resp]))
                }else {
                    successHandler(.failure(CSError.noResponse.error(msg: "")))
                }
            })
        }.resume()
    }
    internal func postData(form: PostForm, successHandler: @escaping(_ result: CResult<[String : Any]>)->Void)  {
        //Implementing URLSession
        guard let req = URLRequest.postRequest(form.url, method: form.method, headers: form.headers, parameters: form.params) else {
            successHandler(.failure(CSError.invalidRequest.error(msg: "")))
            return
        }
        self.delegate?.baseProvider(self, didPrintLog: "Req URL:-\(form.url))\nMethod:- \(form.method.rawValue)\nBody- \(form.params)\nHeaders- \(form.headers)")
        let defaultSession = form.session
        defaultSession?.dataTask(with: req) { (data, response, error) in
            if let errorItem = error {
                FSLogError(errorItem.localizedDescription)
                successHandler(.failure(errorItem))
            }
            guard let data = data else { successHandler(.failure(CSError.noError.error(msg: "")))
                return }
            RW.validJson(from: data, complete: { (validData, parseError) in
                if let data = validData, let resp = response {
                    successHandler(.success([kRespData : data, kResponse : resp]))
                }else {
                    successHandler(.failure(CSError.noResponse.error(msg: "")))
                }
            })
        }.resume()
    }
    internal func deleteData(form: DeleteForm, successHandler: @escaping(_ result: CResult<[String : Any]>)->Void)  {
        //Implementing URLSession
        guard let req = URLRequest.postRequest(form.url, method: form.method, headers: form.headers, parameters: form.params) else {
            successHandler(.failure(CSError.invalidRequest.error(msg: "")))
            return
        }
        self.delegate?.baseProvider(self, didPrintLog: "Req URL:-\(form.url))\nMethod:- \(form.method.rawValue)\nBody- \(form.params)\nHeaders- \(form.headers)")
        let defaultSession = form.session
        defaultSession?.dataTask(with: req) { (data, response, error) in
            if let errorItem = error {
                FSLogError(errorItem.localizedDescription)
                successHandler(.failure(errorItem))
            }
            guard let data = data else { successHandler(.failure(CSError.noError.error(msg: "")))
                return }
            RW.validJson(from: data, complete: { (validData, parseError) in
                if let data = validData, let resp = response {
                    successHandler(.success([kRespData : data, kResponse : resp]))
                }else {
                    successHandler(.failure(CSError.noResponse.error(msg: "")))
                }
            })
        }.resume()
    }
    internal func patchData(form: PatchForm, successHandler: @escaping(_ result: CResult<[String : Any]>)->Void)  {
        //Implementing URLSession
        guard let req = URLRequest.postRequest(form.url, method: form.method, headers: form.headers, parameters: form.params) else {
            successHandler(.failure(CSError.invalidRequest.error(msg: "")))
            return
        }
        self.delegate?.baseProvider(self, didPrintLog: "Req URL:-\(form.url))\nMethod:- \(form.method.rawValue)\nBody- \(form.params)\nHeaders- \(form.headers)")
        let defaultSession = form.session
        defaultSession?.dataTask(with: req) { (data, response, error) in
            if let errorItem = error {
                FSLogError(errorItem.localizedDescription)
                successHandler(.failure(errorItem))
            }
            guard let data = data else { successHandler(.failure(CSError.noError.error(msg: "")))
                return }
            RW.validJson(from: data, complete: { (validData, parseError) in
                if let data = validData, let resp = response {
                    successHandler(.success([kRespData : data, kResponse : resp]))
                }else {
                    successHandler(.failure(CSError.noResponse.error(msg: "")))
                }
            })
        }.resume()
    }
    internal func putData(form: PutForm, successHandler: @escaping(_ result: CResult<[String : Any]>)->Void)  {
        //Implementing URLSession
        guard let req = URLRequest.postRequest(form.url, method: form.method, headers: form.headers, parameters: form.params) else {
            successHandler(.failure(CSError.invalidRequest.error(msg: "")))
            return
        }
        self.delegate?.baseProvider(self, didPrintLog: "Req URL:-\(form.url))\nMethod:- \(form.method.rawValue)\nBody- \(form.params)\nHeaders- \(form.headers)")
        let defaultSession = form.session
        defaultSession?.dataTask(with: req) { (data, response, error) in
            if let errorItem = error {
                FSLogError(errorItem.localizedDescription)
                successHandler(.failure(errorItem))
            }
            guard let data = data else { successHandler(.failure(CSError.noError.error(msg: "")))
                return }
            RW.validJson(from: data, complete: { (validData, parseError) in
                if let data = validData, let resp = response {
                    successHandler(.success([kRespData : data, kResponse : resp]))
                }else {
                    successHandler(.failure(CSError.noResponse.error(msg: "")))
                }
            })
        }.resume()
    }
    
    internal func upload(form: RequestForm, successHandler: @escaping(_ result: CResult<[String : Any]>)->Void)  {
        //Implementing URLSession
        let boundary = "Boundary-\(UUID().uuidString)"
        guard let uploadForm = form as? UploadForm, let req = URLRequest.upload(multipartFormData: { (multipartFormData) in
            var data = Data()
            for (key,value) in uploadForm.params {
                let item = multipartFormData.convertFormField(named: key, value: value , using: boundary)
                data.appendString(item)
             }
            let item = multipartFormData.convertFileData(fieldName: uploadForm.dataKey, fileName: uploadForm.fileName, mimeType: uploadForm.mimeType, fileData: uploadForm.data, using: boundary)
            data.append(item)
            data.appendString("--\(boundary)--")
            multipartFormData.multiPartData = data
        },to: uploadForm.url, method: form.method, headers: uploadForm.headers) else {
            successHandler(.failure(CSError.invalidRequest.error(msg: "")))
            return
        }
        /* Append Boundary in content type... If you not append boundary. It will bad request error*/
        var request = req.0
        if let contentType = request.headers.value(for: "Content-Type") {
           let boundaryContent = "\(contentType); boundary=\(boundary)"
            request.headers["Content-Type"] = boundaryContent
        }
        self.delegate?.baseProvider(self, didPrintLog: "Req URL:- \(String(describing: request.url)))\nMethod:- \(String(describing: request.method))\nBody- \(uploadForm.params)\nHeaders- \(request.headers)")
        let defaultSession = form.session
        defaultSession?.uploadTask(with: request, from:  req.1, completionHandler: { (data, response, error) in
            if let errorItem = error {
                FSLogError(errorItem.localizedDescription)
                successHandler(.failure(errorItem))
            }
            guard let data = data else { return }
            RW.validJson(from: data, complete: { (validData, parseError) in
                if let errorItem = parseError {
                    successHandler(.failure(errorItem))
                }else {
                    if let data = validData, let resp = response {
                      successHandler(.success([kRespData : data, kResponse : resp]))
                    }else {
                        successHandler(.failure(CSError.noResponse.error(msg: "")))
                    }
                }
            })
        }).resume()
    }
   
}
