//
//  CloudService.swift
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
* MODULE OR UNIT: Publc                                *
*
* PROGRAMMER :  Tanuja Awasthi                                   *
* DATE       :  10/07/20                                         *
* VERSION    :  1.0                                              *
*
*----------------------------------------------------------------*
*
* MODULE SUMMARY : Communicate with  cloud                 *
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


public protocol CloudServiceProtocal: AnyObject {
    func cloud(_ service: CloudService, httpLog resp: String)
    /// This is optional method, Only needed to implemented when you want download progress  status
    func cloud(_ service: CloudService, didWritten bytes: Int64, expectedBytes: Int64, progress: Float, totalSize: String)
    /// This is optional method, Will called before writing actual file in given directory.
    func cloud(_ service: CloudService, willComplete destUrl: URL)
    /// This is optional method, Download request  completed and download file will available in given directory
    func cloud(_ service: CloudService, data: Data,  didComplete destUrl: URL)
}
/* Optional Protocol */
extension CloudServiceProtocal {
    public func cloud(_ service: CloudService, httpLog resp: String) { }
    public func cloud(_ service: CloudService, didWritten bytes: Int64, expectedBytes: Int64, progress: Float,totalSize: String) { }
    public func cloud(_ service: CloudService, willComplete destUrl: URL) { }
    public func cloud(_ service: CloudService, data: Data, didComplete destUrl: URL) { }
}

public protocol CloudServiceDataSource: AnyObject  {
    func onSyncQuery(_ service: CloudService, request: CloudSyncQueryRequest) ->CloudSyncQueryResp
}
extension CloudServiceDataSource {
    func onSyncQuery(_ service: CloudService, request: CloudSyncQueryRequest) ->CloudSyncQueryResp {
        return .undefined
    }
}

public enum OperationPriority: Int {
    case high
    case medium
    case low
}

open class CloudService: NSObject {
    /// Shared singleton instance used by all `CloudService.request` APIs. Cannot be modified.
    public static let `default` = CloudService()
    
    /// Underlying `URLSession` used to create `URLSessionTasks` for this instance, and for which this instance's
    /// `delegate` handles `URLSessionDelegate` callbacks.
    ///
    /// - Note: This instance should **NOT** be used to interact with the underlying `URLSessionTask`s. Doing so will
    ///         break internal Cloud Service logic that tracks those tasks.
    ///
    internal let session: URLSession
    
    /// Root `DispatchQueue` for all internal callbacks and state update. **MUST** be a serial queue.
    internal let highPriorityQueue: OperationQueue

    /// Root `DispatchQueue` for all internal callbacks and state update. **MUST** be a serial queue.
    internal let mediumPriorityQueue: OperationQueue

    /// Root `DispatchQueue` for all internal callbacks and state update. **MUST** be a serial queue.
    internal let lowPriorityQueue: OperationQueue
    
    /// Value determining whether this instance automatically calls `resume()` on all created `Request`s.
    public let startRequestsImmediately: Bool
    
    /// Perform maximum concurrent operation
    public static var maxConcurrentOperationCount: Int = 1
    
    /// delegate method to inform cloud infomation state.
    public weak var delegate: CloudServiceProtocal?
    
    /// datasource method get required nfomation from requested module
    public weak var dataSource: CloudServiceDataSource?
    
    /// Background service Handler Object, Optional for normal service. Only needed for background service
    public var backgroundCompletionHandler: (() -> Void)? {
        get {
            return self.downloadService.backgroundCompletionHandler
        }
        set {
            self.downloadService.backgroundCompletionHandler = newValue
        }
    }
    /// background download service
    internal var dService: DownloadService?
    
    internal var dwnHndQueue: CSQueue = CSQueue<((_ result: CResult<[AnyHashable: Any]>) -> Void)>()
    /// `Set` of currently active `Request`s.
    //var activeRequests: Set<Request> = []
    
    /// Creates a `Session` from a `URLSession` and other parameters.
    ///
    /// - Note: When passing a `URLSession`, you must create the `URLSession` with a specific.
    ///
    /// - Parameters:
    ///   - session:                  Underlying `URLSession` for this instance.
    ///   - startRequestsImmediately: Determines whether this instance will automatically start all `Request`s. `true`
    ///                               by default. If set to `false`, all `Request`s created must have `.resume()` called.
    ///                               on them for them to start.
    ///   - requestQueue:             `DispatchQueue` on which to perform `URLRequest` creation. By default this queue
    ///                               will use the `rootQueue` as its `target`. A separate queue can be used if it's
    
    public init(session: URLSession,
                startRequestsImmediately: Bool = true, requestQueue: OperationQueue) {
        precondition(session.configuration.identifier == nil,
                     "Clould service does not support background URLSessionConfigurations.")
        self.session = session
        self.startRequestsImmediately = startRequestsImmediately
        self.highPriorityQueue = requestQueue

        mediumPriorityQueue = OperationQueue()
        mediumPriorityQueue.qualityOfService = .userInitiated
        mediumPriorityQueue.maxConcurrentOperationCount = CloudService.maxConcurrentOperationCount
        mediumPriorityQueue.name = "com.cloudservice.medium.queqe"

        lowPriorityQueue = OperationQueue()
        lowPriorityQueue.qualityOfService = .utility
        lowPriorityQueue.maxConcurrentOperationCount = CloudService.maxConcurrentOperationCount
        lowPriorityQueue.name = "com.cloudservice.low.queqe"
    }
    
    /// Creates a `Session` from a `URLSessionConfiguration`.
    ///
    /// - Note: This initializer lets Cloud Service  handle the creation of the underlying `URLSession` and its
    ///         `delegateQueue`, and is the recommended initializer for most uses.
    ///
    /// - Parameters:
    ///   - configuration:            `URLSessionConfiguration` to be used to create the underlying `URLSession`. Changes
    ///                               to this value after being passed to this initializer will have no effect.
    
    ///   - startRequestsImmediately: Determines whether this instance will automatically start all `Request`s. `true`
    ///                               by default. If set to `false`, all `Request`s created must have `.resume()` called.
    ///                               on them for them to start.
    ///   - requestQueue:             `DispatchQueue` on which to perform `URLRequest` creation. By default this queue
    
    public convenience init(configuration: URLSessionConfiguration = URLSessionConfiguration.cloud.default,
                            startRequestsImmediately: Bool = true)
    {
        precondition(configuration.identifier == nil, "Cloud does not support background URLSessionConfigurations.")
        FSFrameworkVersion()
        let session = URLSession(configuration: configuration)

        let highPriorityQueue = OperationQueue()
        highPriorityQueue.qualityOfService = .userInteractive
        highPriorityQueue.maxConcurrentOperationCount = CloudService.maxConcurrentOperationCount
        highPriorityQueue.name = "com.cloudservice.high.queqe"
        self.init(session: session,
                  startRequestsImmediately: startRequestsImmediately, requestQueue: highPriorityQueue)
    }
    
    deinit {
        session.invalidateAndCancel()
    }
    var downloadService: DownloadService {
        guard let service = self.dService else {
            self.dService = DownloadService(self, maxConCurrentOpsCount: CloudService.maxConcurrentOperationCount)
            return self.dService ?? DownloadService(self, maxConCurrentOpsCount: CloudService.maxConcurrentOperationCount)
        }
        return service
    }
    /// Make Request to Get  the data  from URL
    ///
    /// - Note: Call this method to get the data by passing UR
    ///
    /// - Parameters:
    ///   - configuration:`RequestForm`is class, which is supporting multiple params like URL, Request Method, Body etc Default Method is GET Default Hearde Application/Json
    ///   - requestQueue:  Request will suport quequ syncing
    ///   - id: Keep remember request id, It will required, when you want to cancel request
    
    public func request(form: RequestForm, _ isRetrunURLResp: Bool = true, completed: @escaping (_ result: CResult<[AnyHashable : Any]>) -> Void) {
        self.request(form: form, decodeClass: BaseDecodingModel.self, isRetrunURLResp) { (result) in
            completed(result)
        }
    }
    /// Make Request to Get  the data  from URL
    ///
    /// - Note: Call this method to get the data by passing UR
    ///
    /// - Parameters:
    ///   - configuration:`RequestForm`is class, which is supporting multiple params like URL, Request Method, Body etc Default Method is GET Default Hearde Application/Json
    
    ///   - decodeClass: Pass the class name in which you want to wrap the request data
    ///                               by default. If set to `false`, all `Request`s created must have `.resume()` called.
    ///                               on them for them to start.
    ///   - requestQueue:  Request will suport quequ syncing
    ///   - id: Keep remember request id, It will required, when you want to cancel request
    
    open func request<T: Decodable>(form: RequestForm, decodeClass: T.Type, _ isRetrunURLResp: Bool = true,
                                       priority: OperationPriority = .high, completed: @escaping (_ result: CResult<[AnyHashable : Any]>) -> Void) {
        let formItem = form
        switch formItem {
        case let formItem as DownloadForm:
            dwnHndQueue.enQueue(completed)
            self.handleDownloadFileRequest(formItem)
            return
        default:
            formItem.session = self.session
            break
        }
        formItem.provider.delegate = self
        let operation = GenericOperation.init(id: form.id, form: formItem)
        switch priority {
        case .high:
            self.highPriorityQueue.addOperations([operation], waitUntilFinished: false)
        case .medium:
            self.mediumPriorityQueue.addOperations([operation], waitUntilFinished: false)
        case .low:
            self.lowPriorityQueue.addOperations([operation], waitUntilFinished: false)
        }
        operation.completionBlock = {
            guard let resultItem = operation.result, let respDict = resultItem.value, let urlRes = respDict[kResponse] as? HTTPURLResponse else  {
                self.delegate?.cloud(self, httpLog: "URL Resp:- \(String(describing: operation.result?.error))")
                if let error = operation.result?.error {
                    completed(.failure(error))
                }else {
                    completed(.failure(CSError.noResponse.error(msg: "")))
                }
                return
            }
            var apiRespDict: [String : Any] = [:]
            if isRetrunURLResp {
                apiRespDict[kResponse] = urlRes
            }
            if resultItem.isSuccess, let data = respDict[kRespData] as? Data, urlRes.status != HTTPStatusCode.forbidden {
                apiRespDict[kRespData] = data
                self.delegate?.cloud(self, httpLog: "URL Resp:- \(urlRes) \n\(RW.log(from: data))")
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
                              completed(.failure(CSError.json.error(msg: "")))
                            }
                        }
                    }
                } else { /* raw data object, user can parse data at their side */
                    completed(.success(apiRespDict))
                }
            }else {
                if let errorItem = resultItem.error {
                    completed(.failure(errorItem))
                    self.delegate?.cloud(self, httpLog: "URL Resp:- \(urlRes) \nError:\(errorItem)")
                }else {
                    let data = respDict[kRespData] as? Data ?? Data()
                    let customError = CSError.tokenExpire(urlRes.statusCode).error(msg: RW.string(from: data))
                    self.delegate?.cloud(self, httpLog: "URL Resp:- \(urlRes) \nError:\(customError)")
                    completed(.failure(customError))
                }
            }
        }
    }
    // MARK: - Download action methods
    func handleDownloadFileRequest(_ form: DownloadForm) {
        if let url = URL.init(string: form.url) {
            if form.headers.count > 0 {
                guard let req = URLRequest.request(form.url, method: form.method, headers: form.headers) else {
                    return
                }
                let info = DownloadInfo.init(preview: url, req: req, localDir: form.subDirPath)
                self.downloadService.addDownloadRequestInQueue(info)
            } else {
                let info = DownloadInfo.init(preview: url,localDir: form.subDirPath)
                self.downloadService.addDownloadRequestInQueue(info)
            }
            
        } else {
            if let handler = dwnHndQueue.deQueue() {
                handler(.failure(CSError.invalidURL.error(msg: "")))
            }
        }
        self.delegate?.cloud(self, httpLog: "Download Request Log: URL:-\(form.url)\nMethod:-\(form.method.rawValue)\nParam:-\(form.params),\nHeader:-\(form.headers)")
    }
   
   /* var appState: AppWorkingState {
        var stateItem: AppWorkingState = .unknown
        if let item = self.dataSource {
            let appState = item.onSyncQuery(self, request: .appState)
            switch appState {
            case .appState(let state):
                stateItem = state
            default:
                break
            }
        }
        return stateItem
    } */
    
    public func cancelDownload(_ url: String) {
        if let url = URL.init(string: url) {
            self.downloadService.pauseDownload(url)
        }
    }
    
    public func pauseDownload(_  url: String) {
        if let url = URL.init(string: url) {
            self.downloadService.pauseDownload(url)
        }
    }
    
    public func resumeDownload(_  url: String) {
        if let url = URL.init(string: url) {
            self.downloadService.resumeDownload(url)
        }
    }
   // MARK: - Cancellation
    
    public func cancelAllRequests(_ priority: OperationPriority = .high, completed: @escaping(Bool) ->Void = {_ in }) {
        switch priority {
        case .high:
            for item in self.highPriorityQueue.operations {
                if let operation = item as? GenericOperation {
                    debugPrint("High Operation Id: \(operation.id)")
                }
                item.cancel()
                debugPrint("High isOperation canceled: \(item.isCancelled)")
            }
            break
        case .medium:
            for item in self.mediumPriorityQueue.operations {
                if let operation = item as? GenericOperation {
                    debugPrint("Medium Operation Id: \(operation.id)")
                }
                item.cancel()
                debugPrint("Medium isOperation canceled: \(item.isCancelled)")
            }
            break
        case .low:
            for item in self.lowPriorityQueue.operations {
                if let operation = item as? GenericOperation {
                    debugPrint("low Operation Id: \(operation.id)")
                }
                item.cancel()
                debugPrint("low isOperation canceled: \(item.isCancelled)")
            }
            break
        }
        completed(true)
    }
    
    public func cancelRequest(request id: UUID, completed:@escaping(Bool) ->Void = {_ in }) {
        for item in self.highPriorityQueue.operations  {
            if let operation = item as? GenericOperation, operation.id == id {
                operation.cancel()
                break
            }
        }
        completed(true)
    }
    public func inProgressDownload(completed: @escaping (_ result: CResult<[AnyHashable: Any]>) -> Void)  {
        self.dwnHndQueue.enQueue(completed)
        self.downloadService.session.getAllTasks { tasks in
            if tasks.count == 0, let handler = self.dwnHndQueue.deQueue() {
                /* No request pending for download clear. Clear all downloades if still in pending request..*/
                self.downloadService.activeDownloads.removeAll()
                handler(.success([kStatus : DownloadStatus.unknown]))
            }
        }
    }
}
// MARK: - Download Request callback delegate methods

extension CloudService: DownloadServiceProtocal {
    
    func download(_ service: DownloadService, didWritten bytes: Int64, expectedBytes: Int64, progress: Float,totalSize: String) {
        self.delegate?.cloud(self, didWritten: bytes, expectedBytes: expectedBytes, progress:progress, totalSize: totalSize)
    }
    func download(_ service: DownloadService, data: Data, didComplete destUrl: URL) {
        if let completedHandler = self.dwnHndQueue.deQueue() {
            completedHandler(.success([kStatus: DownloadStatus.completed, kDataSize : data.count,kDestinationURL: destUrl]))
        }
        self.delegate?.cloud(self, data: data, didComplete: destUrl)
    }
    func download(_ service: DownloadService, willComplete destUrl: URL) {
        self.delegate?.cloud(self, willComplete: destUrl)
    }
}
 // MARK: -  Cloud provider delegate methods

extension CloudService: BaseProviderProtocol {
    func baseProvider(_ base: BaseProvider, didPrintLog text: String) {
        self.delegate?.cloud(self, httpLog: text)
    }
}
