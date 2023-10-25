
//  URLRequest.swift
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
* MODULE SUMMARY : This is the class where we will form URl      *
  According to the request type and it the class which give      *
  request formed                                                 *
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

private let contentType = "Content-type"
private let urlEncodedContentType = "application/x-www-form-urlencoded"

extension URLRequest {
    // MARK: Form Request
    internal static func request(_ convertible: URLConvertible,
                         method: HTTPMethod = .get,
                         headers: HTTPHeaders? = nil,
                         requestModifier: RequestModifier? = nil) ->URLRequest? {
        let convertible = ParameterlessRequestConvertible(url: convertible,
                                                          method: method,
                                                          headers: headers,
                                                          requestModifier: requestModifier)
        let initialRequest: URLRequest
        do {
            initialRequest = try convertible.asURLRequest()
            try initialRequest.validate()
        } catch {
            return nil
        }
        return initialRequest
    }
   internal static func postRequest(_ convertible: URLConvertible,
                             method: HTTPMethod = .post,
                             headers: HTTPHeaders? = nil,
                             parameters: Parameters?,
                             encoding: ParameterEncoding = JSONEncoding.default,
                             requestModifier: RequestModifier? = nil) ->URLRequest? {
        let convertibleReq: RequestConvertible
        if let headers = headers, let item = headers.value(for:contentType), item == urlEncodedContentType {
            convertibleReq = RequestConvertible(url: convertible,
                                                method: method,
                                                parameters: parameters,
                                                encoding: URLEncoding.default,
                                                headers: headers,
                                                requestModifier: requestModifier)
        }else {
            convertibleReq = RequestConvertible(url: convertible,
                                                method: method,
                                                parameters: parameters,
                                                encoding: encoding,
                                                headers: headers,
                                                requestModifier: requestModifier)
        }
        
        let initialRequest: URLRequest
        do {
            initialRequest = try convertibleReq.asURLRequest()
            try initialRequest.validate()
        } catch {
            return nil
        }
        return initialRequest
    }
    // MARK: MultipartFormData
    
    /// Creates an `UploadRequest` for the multipart form data built using a closure and sent using the provided
    /// `URLRequest` components and `RequestInterceptor`.
    ///
    /// It is important to understand the memory implications of uploading `MultipartFormData`. If the cumulative
    /// payload is small, encoding the data in-memory and directly uploading to a server is the by far the most
    /// efficient approach. However, if the payload is too large, encoding the data in-memory could cause your app to
    /// be terminated. Larger payloads must first be written to disk using input and output streams to keep the memory
    /// footprint low, then the data can be uploaded as a stream from the resulting file. Streaming from disk MUST be
    /// used for larger payloads such as video content.
    ///
    /// The `encodingMemoryThreshold` parameter allows Alamofire to automatically determine whether to encode in-memory
    /// or stream from disk. If the content length of the `MultipartFormData` is below the `encodingMemoryThreshold`,
    /// encoding takes place in-memory. If the content length exceeds the threshold, the data is streamed to disk
    /// during the encoding process. Then the result is uploaded as data or as a stream depending on which encoding
    /// technique was used.
    ///
    /// - Parameters:
    ///   - multipartFormData:       `MultipartFormData` building closure.
    ///   - convertible:             `URLConvertible` value to be used as the `URLRequest`'s `URL`.
    ///   - encodingMemoryThreshold: Byte threshold used to determine whether the form data is encoded into memory or
    ///                              onto disk before being uploaded. `MultipartFormData.encodingMemoryThreshold` by
    ///                              default.
    ///   - method:                  `HTTPMethod` for the `URLRequest`. `.post` by default.
    ///   - headers:                 `HTTPHeaders` value to be added to the `URLRequest`. `nil` by default.
    ///   - fileManager:             `FileManager` to be used if the form data exceeds the memory threshold and is
    ///                              written to disk before being uploaded. `.default` instance by default.
    ///   - requestModifier:         `RequestModifier` which will be applied to the `URLRequest` created from the
    ///                              provided parameters. `nil` by default.
    ///
    /// - Returns:                   The created `UploadRequest`.
    
  internal static func upload(multipartFormData: @escaping (MultipartFormData) -> Void,
                     to url: URLConvertible,
                     usingThreshold encodingMemoryThreshold: UInt64 = MultipartFormData.encodingMemoryThreshold,
                     method: HTTPMethod = .post,
                     headers: HTTPHeaders? = nil,
                     fileManager: FileManager = .default,
                     requestModifier: RequestModifier? = nil) -> (URLRequest, Data)?{
        let convertible = ParameterlessRequestConvertible(url: url,
                                                          method: method,
                                                          headers: headers,
                                                          requestModifier: requestModifier)
        let formData = MultipartFormData(fileManager: fileManager)
        multipartFormData(formData)
        
        let initialRequest: URLRequest
        let uploadData: Data
        do {
            initialRequest = try convertible.asURLRequest()
            try initialRequest.validate()
            //uploadData = try formData.encode()
            uploadData =  formData.multiPartData
        } catch {
            return nil
        }
        return (initialRequest, uploadData)
    }
    
   internal struct ParameterlessRequestConvertible: URLRequestConvertible {
        let url: URLConvertible
        let method: HTTPMethod
        let headers: HTTPHeaders?
        let requestModifier: RequestModifier?
        
        func asURLRequest() throws -> URLRequest {
            var request = try URLRequest(url: url, method: method, headers: headers)
            try requestModifier?(&request)
            return request
        }
    }
    
    
    // MARK: - DataRequest
    
    /// Closure which provides a `URLRequest` for mutation.
   internal typealias RequestModifier = (inout URLRequest) throws -> Void
    
   internal struct RequestConvertible: URLRequestConvertible {
        let url: URLConvertible
        let method: HTTPMethod
        let parameters: Parameters?
        let encoding: ParameterEncoding
        let headers: HTTPHeaders?
        let requestModifier: RequestModifier?
        
        func asURLRequest() throws -> URLRequest {
            var request = try URLRequest(url: url, method: method, headers: headers)
            try requestModifier?(&request)
            return try encoding.encode(request, with: parameters)
        }
    }
}
