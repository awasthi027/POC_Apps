
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
* MODULE SUMMARY : Extendent URL Session support                 *
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

extension URLSessionConfiguration: CloudExtended {}
extension CloudExtendedExtension where ExtendedType: URLSessionConfiguration {
    /// Clould Service 's default configuration. Same as `URLSessionConfiguration.default` but adds CloudService default
    /// `Accept-Language`, `Accept-Encoding`, and `User-Agent` headers.
    public static var `default`: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.headers = .default
        return configuration
    }
}
