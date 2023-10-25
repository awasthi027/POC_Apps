//
//  Download.swift
//  CloudService
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
* DATE       :  06/10/20                                         *
* VERSION    :  1.0                                              *
*
*----------------------------------------------------------------*
*
* MODULE SUMMARY : Download infomation model class               *
*
*
*
*
*----------------------------------------------------------------*
*
* TRACEABILITY RECORDS to SW requirements and detailed design :  *
* iOS 12 and onward
*
*
*----------------------------------------------------------------*
*
* MODIFICATION RECORDS                                           *
*
******************************************************************
*/

import Foundation

internal struct DownloadInfo {
    internal var subDirPath: String
    internal var previewURL: URL
    internal var req: URLRequest?
    internal var uuid: UUID = UUID.init()
  
    //
    // MARK: - Variables And Properties
    //
    var downloaded: Bool = false
    internal init(preview reqURL: URL, req: URLRequest? = nil, localDir path: String) {
        self.previewURL = reqURL
        self.req = req
        self.subDirPath = path
    }
}

internal class Download {
    //
    // MARK: - Variables And Properties
    //
    var isDownloading = false
    var progress: Float = 0
    var resumeData: Data?
    var task: URLSessionDownloadTask?
    var info: DownloadInfo
  
    //
    // MARK: - Initialization
    //
    init(info: DownloadInfo) {
        self.info = info
    }
}
