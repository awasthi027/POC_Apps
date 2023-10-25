
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
* MODULE SUMMARY : Download service is independent class
  Which can perform download related action in background        *
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
import UIKit
public enum DownloadStatus: Int {
    case completed
    case inprogress
    case unknown
}
//
// MARK: - Download Service
//

/// Downloads song snippets, and stores in local file.
/// Allows cancel, pause, resume download.

/* Optional Protocol */
protocol DownloadServiceProtocal: NSObjectProtocol {
    /// Only needed to implemented when you want download progress  status
    /// - Parameters:
    ///   - service: service reference
    ///   - bytes: bytes downloaded bytes
    ///   - expectedBytes: expectedBytes expectedbytes to download
    ///   - progress: progress in %
    ///   - totalSize: totalSize total size in mb
    func download(_ service: DownloadService, didWritten bytes: Int64, expectedBytes: Int64, progress: Float,totalSize: String)
    
    /// Will called before writing actual file in given directory.
    /// - Parameters:
    ///   - service: service reference
    ///   - destUrl: destUrl downloaded file destination path
    func download(_ service: DownloadService, willComplete destUrl: URL)
    
    /// This is optional method, Download request  completed and download file will available in given directory
    /// - Parameters:
    ///   - service: service reference
    ///   - data: total data size
    ///   - destUrl:  destUrl downloaded file destination path
    func download(_ service: DownloadService, data: Data, didComplete destUrl: URL)
}

extension DownloadServiceProtocal {
    func download(_ service: DownloadService, willComplete destUrl: URL) { }
}

class DownloadService: NSObject {
    /// Get local file path: download task stores tune here; AV player plays it.
    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    
    //
    // MARK: - Variables And Properties
    //
    /// Contain list of active downloades
    var activeDownloads: [URL: Download] = [ : ] {
        didSet {
            self.updateActiveDownload()
        }
    }
    /// reference of class who expecting callbacks from download service
    var delegate: DownloadServiceProtocal
    
    /// creates downloadsSession
    var session: URLSession = URLSession.init()
    
/// Root `DispatchQueue` for all internal callbacks and state update. **MUST** be a serial queue.
    internal let dwQueue: OperationQueue
    
    /// Maximum concurrent download operation
    internal let maxConCurrentOpsCount: Int = 1
    
    ///  Manage sync request repeated request.
    internal var syncReqQueue: CSQueue = CSQueue<DownloadInfo>()
    
    /// if application in background,
    public var isAppInBackround: Bool = false
    
    /// Background service Handler Object
    public var backgroundCompletionHandler: (() -> Void)?
    
    
    // MARK: - Invoke download backgroud session
    init(_ delegate: DownloadServiceProtocal, maxConCurrentOpsCount: Int) {
        self.delegate = delegate
        let requestQueue = OperationQueue()
        requestQueue.maxConcurrentOperationCount = maxConCurrentOpsCount
        requestQueue.name = "com.ignite.download.queqe"
        self.dwQueue = requestQueue
        super.init()
        
        /* Internet call back needed for downlaod service to stop and resume download*/
        ReachabilityManager.shared.delegate = self
        let config = URLSessionConfiguration.background(withIdentifier:
                                                            "com.tanu.filedownload.bgSession")
        config.isDiscretionary = false
        /* If you set this property to true, you tell the system that you basically don’t care when the file is downloaded. So the system will try to optimise the download as much as possible, e.g. downloading when you’re connected to WiFi and charging the phone.*/
        config.sessionSendsLaunchEvents = false
        /* Set the ‘sessionSendsLaunchEvents’ to true to have your app woken up by the system when the download completes */
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        /* Reading pending download before reset before reseting download session object... */
        self.readPendingDownloadList()
    }

    // MARK: - Download action methods
    func cancelDownload(_ url: URL) {
        guard let download = activeDownloads[url] else {
            return
        }
        // Resume to ensure metrics are gathered.
        download.task?.resume()
        download.task?.cancel()
        activeDownloads[url] = nil
    }
    
    func pauseDownload(_ url: URL) {
        guard
            let download = activeDownloads[url],
            download.isDownloading
            else {
                return
        }
        // Resume to ensure metrics are gathered.
        download.task?.resume()
        download.task?.cancel(byProducingResumeData: { data in
            download.resumeData = data
            //FSLogDebug("Pause download:- \(String(describing: data?.description))======")
        })
        download.isDownloading = false
    }
    
    func resumeDownload(_ url: URL) {
        guard let download = activeDownloads[url], !download.isDownloading else {
            return
        }
        if let resumeData = download.resumeData {
            //FSLogDebug("Resume download:- \(resumeData.debugDescription)========")
            download.task =  self.session.downloadTask(withResumeData: resumeData)
        } else {
          //  FSLogDebug("Fresh resume download=======")
            if let req = download.info.req {
                download.task = self.session.downloadTask(with: req)
            }else {
                download.task = self.session.downloadTask(with: url)
            }
        }
        download.task?.resume()
        download.isDownloading = true
    }
    
    func addDownloadRequestInQueue(_ info: DownloadInfo) {
        self.dwQueue.addOperation {
            /* Make sure download should be in syncing..... We are invoking request duplicate sync request.
             ** dwQueue can manage unique sync request with, but can't manage duplicate request in sync */
            if self.maxConCurrentOpsCount == 1, self.activeDownloads.count > 0 {
                self.syncReqQueue.enQueue(info)
            }else {
                self.startDownload(info)
            }
        }
    }
    
    func startDownload(_ info: DownloadInfo) {
        // 1
        let download = Download(info: info)
        // 2
        if let req = info.req {
            download.task = self.session.downloadTask(with: req)
        }else {
            download.task = self.session.downloadTask(with: info.previewURL)
        }
        // 3
        download.task?.resume()
        // 4
        download.isDownloading = true
        // 5
        self.activeDownloads[info.previewURL] = download
    }
    
}
// MARK:: Reachbility Of and off methods
extension DownloadService: ReachabilityProtocol {
    func reachability(_ manager: ReachabilityManager, didNetworkChange isReachabil: Bool) {
        for (_, value) in self.activeDownloads {
            if isReachabil {
                if !value.isDownloading {
                    self.resumeDownload(value.info.previewURL)
                }
            }else {
                self.pauseDownload(value.info.previewURL)
            }
        }
    }
}

// MARK:: NSURLSession Delegate Methods
extension DownloadService: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let sourceURL = task.currentRequest?.url else {
            return
        }
        if error == nil {
            // FSLogDebug("Clear last download request its failed without error")
            self.activeDownloads[sourceURL] = nil
        }
        //  FSLogDebug("Download Error:- \(error.debugDescription)========")
        guard let error = error else {
            return
        }
        let userInfo = (error as NSError).userInfo
        if let resumeData = userInfo[NSURLSessionDownloadTaskResumeData] as? Data{
            guard
                let download = activeDownloads[sourceURL],
                download.isDownloading
            else {
                return
            }
            download.isDownloading = false
            download.resumeData = resumeData
        }
    }
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        //  FSLogDebug("Download service get event did finish download in background. Completed your task and invalidate background hanlder")
        DispatchQueue.main.async {
            guard let backgroundCompletionHandler =
                    self.backgroundCompletionHandler else {
                return
            }
            backgroundCompletionHandler()
        }
    }
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                           didFinishDownloadingTo location: URL) {
        guard let response = downloadTask.response as? HTTPURLResponse else {
            return //something went wrong
        }
        
        let respHeaders = response.allHeaderFields
        // print("Download header...\(respHeaders)")
        // 1
        guard let sourceURL = downloadTask.currentRequest?.url else {
            return
        }
        
        let download = self.activeDownloads[sourceURL]
        self.activeDownloads[sourceURL] = nil
        if let subDirPath = download?.info.subDirPath {
            self.delegate.download(self, willComplete:  documentsPath.appendingPathComponent(subDirPath))
        }
        // 2
        guard let subPath = download?.info.subDirPath else {
            /* if we are not having local directory sending complete file data object.*/
            if let data = self.readData(url: location) {
                self.delegate.download(self, data: data, didComplete: location)
            }
            return
        }
        var destinationURL = documentsPath.appendingPathComponent(subPath)
        /* Taking file name response header if its have, otherwise write default file name */
        let defaultFileName = destinationURL.lastPathComponent
        if defaultFileName.contains(".") , let fileName = self.fileNameFromResponseHeader(respHeaders) {
            destinationURL = destinationURL.deletingLastPathComponent()
            destinationURL.appendPathComponent(fileName)
        }
        //FSLogDebug("File Destination URL:- \(destinationURL.absoluteString)")
        // 3
        let fileManager = FileManager.default
        do {
            try fileManager.removeItem(at: destinationURL)
        } catch  {
            //FSLogDebug("Remove old file: \(error.localizedDescription)")
        }
        do {
            try fileManager.copyItem(at: location, to: destinationURL)
            download?.info.downloaded = true
        } catch {
            //FSLogDebug("Could not copy file to disk: \(error.localizedDescription)")
        }
        // 4
        if let data = self.readData(url: destinationURL) {
            /*  let str = String(decoding: data, as: UTF8.self)
             print("Download API data:-\(str)") */ // uncomment to check error
            self.delegate.download(self, data: data, didComplete: destinationURL)
        }
        if let info = syncReqQueue.deQueue() {
            self.startDownload(info)
        }
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                           didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                           totalBytesExpectedToWrite: Int64) {
        /* Response should have all the details like filename, content length etc */
        /* guard let response = downloadTask.response as? HTTPURLResponse else {
         return //something went wrong
         }
         let status = response.statusCode
         let completeHeader = response.allHeaderFields
         print("Download header...\(completeHeader)") */
        //1
        guard
            let url = downloadTask.currentRequest?.url, self.activeDownloads.count > 0,
            let download = self.activeDownloads[url]  else {
            return
        }
        let percent = (Float(totalBytesWritten) * 100) / Float(totalBytesExpectedToWrite)
        // 2
        download.progress = percent
        //3
        let totalSize = ByteCountFormatter.string(fromByteCount: totalBytesExpectedToWrite, countStyle: .file)
        self.delegate.download(self, didWritten: totalBytesWritten, expectedBytes: totalBytesExpectedToWrite, progress: download.progress, totalSize: totalSize)
    }
    
    
    internal func readData(url: URL) ->Data? {
        var directory: ObjCBool = ObjCBool(false)
        let fileExist = FileManager.default.fileExists(atPath: url.path, isDirectory: &directory)
        if fileExist {
            do {
                var filePathUrl = URL.init(fileURLWithPath: url.absoluteString)
                if url.isFileURL {
                    filePathUrl = url
                }
                let data = try Data(contentsOf: filePathUrl, options: [.mappedIfSafe] )
                return data
            } catch {
                return nil
            }
        }
        return nil
    }
    
    func fileNameFromResponseHeader(_ headers: [AnyHashable: Any]) ->String? {
        if var fileName = headers["Content-Disposition"] as? String {
            var items = fileName.components(separatedBy: "filename=")
            if items.count > 1 {
                fileName = items[1]
            }
            items = fileName.components(separatedBy: ";")
            if items.count > 0 {
                fileName = items[0]
            }
            fileName = fileName.replacingOccurrences(of: "\"", with: "")
            return fileName
        }
        return nil
    }
}
// MARK: - Storing and Managing Download request info. If application crash while downloading.
/* Below source manage download request when application quit and download is inprogress.....*/
private let KPendingDownloadRequests = "PendingDownloadRequests"
public struct PendingRequest: Decodable {
    public var urL: URL?
    public var downloadId: String = ""
    public var subDirPath: String?
}

extension PendingRequest: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(urL, forKey: .urL)
        try container.encode(downloadId, forKey: .downloadId)
        try container.encode(subDirPath, forKey: .subDirPath)
    }
}

public struct PendingDownloadRequest: Decodable {
    public var requests: [URL : PendingRequest] = [:]
}

extension PendingDownloadRequest: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(requests, forKey: .requests)
    }
}

/* Handling pending download bussiness logic....*/
extension DownloadService {
    func readPendingDownloadList() {
        var downloadList: [URL: Download] = [:]
        for url in pendingDownloadRequests.requests.keys {
            if let request = pendingDownloadRequests.requests[url],let localDirPath = request.subDirPath {
                let downloadInfo = DownloadInfo.init(preview: url, localDir: localDirPath)
                let download = Download.init(info: downloadInfo)
                download.isDownloading = true
                downloadList[url] = download
            }
        }
        self.activeDownloads = downloadList
    }
    
    func updateActiveDownload() {
        var pendingDownloadRequests = PendingDownloadRequest.init()
        for url in self.activeDownloads.keys {
            if let request = self.activeDownloads[url] {
                let item = PendingRequest.init(urL: request.info.previewURL, subDirPath: request.info.subDirPath)
                pendingDownloadRequests.requests[url] = item
            }
        }
        self.pendingDownloadRequests = pendingDownloadRequests
    }
    var pendingDownloadRequests: PendingDownloadRequest {
        /* Persist downlaod request in list */
        get {
            guard let data = UserDefaults.standard.object(forKey: KPendingDownloadRequests) as? Data,  let model = RW.classFrom(data: data, name: PendingDownloadRequest.self) else {
                return PendingDownloadRequest()
            }
            return model
        }
        set {  /* Clear download request from list */
            if let data = newValue.asData {
                let defaultUser = UserDefaults.standard
                defaultUser.set(data, forKey: KPendingDownloadRequests)
                defaultUser.synchronize()
            }
        }
    }
}

