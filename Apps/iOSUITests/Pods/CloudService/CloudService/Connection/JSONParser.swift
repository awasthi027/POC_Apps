
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
* MODULE SUMMARY : JSON parser and JSON validation class         *
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

public struct RW {
    public static func jsonObject(from data: Data, parseHandler: @escaping(_ json: Any?, _ error: Error?)-> Void )  {
        do {
            if let jsonDict = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] {
                parseHandler(jsonDict,nil)
            } else if let jsonArray = try JSONSerialization.jsonObject(with:data, options: [.mutableContainers, .allowFragments]) as? Array<Any> {
                parseHandler(jsonArray,nil)
                FSLogInfo("JSON:- \(String(describing: jsonArray))")
            }
        }
        catch let error {
            parseHandler(nil,error)
        }
    }
    public static func processDataObj(_ data: Data, handler: @escaping(_ data: Data?, _ error: Error?) ->Void) {
        do {
            if let _ = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] {
                return handler(data, nil)
            } else if let jsonArray = try JSONSerialization.jsonObject(with:data, options: [.mutableContainers, .allowFragments]) as? Array<Any> {
                let dict = ["data" : jsonArray]
                let data = try JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted)
                return handler(data, nil)
                }
        }
        catch let error {
            return handler(nil, error)
        }
    }
    public static func decodeData<T: Decodable>(raw data: Data, withType type: T.Type,
                                                processComplete: @escaping(_ model: T?, _ error: Error?) ->Void) {
        do {
            let model = try JSONDecoder().decode(T.self, from: data)
            processComplete(model,nil) }
        catch let error {
            processComplete(nil,error)
        }
    }
    
    internal static func validJson(from data: Data, complete: @escaping(_ data: Data? , _ error: Error?) ->Void) {
        if JSONSerialization.isValidJSONObject(data) {
            complete(data, nil)
        } else {
            if let serverStr = String.init(data: data, encoding: String.Encoding.ascii) {
                let asciiData = serverStr.data(using: String.Encoding.utf8, allowLossyConversion: true)
                complete(asciiData, nil)
            }
        }
    }
    
    internal static func log(from data: Data) ->String {
        if data.isEmpty {
            return "Blank data response from cloud. But API call has been successfull."
        }
        if JSONSerialization.isValidJSONObject(data) {
            return "Invalid json object"
        } else {
            do {
                if let serverStr = String.init(data: data, encoding: String.Encoding.ascii) {
                    let asciiData = serverStr.data(using: String.Encoding.utf8, allowLossyConversion: true)
                    var rawJSON = try? JSONSerialization.jsonObject(with: asciiData!, options: JSONSerialization.ReadingOptions())
                    if let item = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] {
                        rawJSON = item
                    } else if let item = try JSONSerialization.jsonObject(with:data, options: [.mutableContainers, .allowFragments]) as? Array<Any> {
                        rawJSON = item
                    }
                    return "Cloud Response:-\n\(String(describing: rawJSON))"
                }
                
            } catch let error {
                return error.localizedDescription
            }
        }
        return ""
    }
    
    public static func process<T: Decodable>(_ response: CResult<Data>?, _ decodeClass: T.Type, completed: @escaping (_ result: CResult<[String: Any]>) -> Void) {
        if let result = response, result.isSuccess, let data = result.value {
            self.decodeData(raw: data, withType: decodeClass.self) { (obj, error) in
              if let jsonObj = obj {
                    completed(.success([kResponseObj: jsonObj]))
                }else {
                    if let errorItem = error {
                        if let str = String(data: data, encoding: .utf8) {
                            completed(.failure(CSError.json.error(msg: str)))
                        }else {
                            completed(.failure(errorItem))
                        }
                     }else {
                        completed(.failure(CSError.json.error(msg: "")))
                    }
                }
            }
        } else {
            if let error = response?.error {
                completed(.failure(error))
            }else {
                completed(.failure(CSError.noResponse.error(msg: "")))
            }
        }
    }
    public static func string(from data: Data) -> String {
        guard let dataStr = String.init(data: data, encoding: String.Encoding.ascii) else {
            return ""
        }
        return dataStr
    }
    public static func classFrom<T: Decodable>(data: Data, name:T.Type)->T? {
        guard let obj = try? JSONDecoder().decode(T.self, from: data) else { return nil }
        return obj
    }
}

