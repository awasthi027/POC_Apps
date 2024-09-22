//
//  GenericOperation.swift
//  ThreadIngPOC
//
//  Created by Ashish Awasthi on 17/09/24.
//
import Foundation
import MachO
import QuartzCore

extension NSNotification.Name {
    internal static let sdkContextDidChange = NSNotification.Name("SDKContextDidChange")
}

internal struct NotificationObjectKeys {
    static let sdkContext = "sdkcontext"
}

internal class SDKOperation: Operation,
                                @unchecked Sendable {

    internal var directDependency: SDKOperation?

    internal let sdkManager: SDKManager
    internal var dataContext: SDKContext = SDKContext()
    internal var presenter: SDKQueuePresenter = SDKQueuePresenter()

    internal var operationCompletedSuccessfully = false

   required init(sdkManager: SDKManager,
         dataContext: SDKContext,
         presenter: SDKQueuePresenter) {
        self.sdkManager = sdkManager
        self.dataContext = dataContext
        self.presenter = presenter
        super.init()
        self.name = String(describing: type(of: self))
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(updateContext(notification:)),
                                               name: NSNotification.Name.sdkContextDidChange,
                                               object: nil)
    }

    deinit {
        cleanup()
    }

    func createDependencyChain<T: SDKOperation>(_ operationTypes: [T.Type],
                                                dataStore: SDKContext? = nil) -> [T] {
        let operationDataStore = dataStore ?? self.dataContext
        self.dataContext = operationDataStore
        var previousOperation: SDKOperation? = nil
        let operations = operationTypes.map { (operationType) -> T in
            let operation = operationType.init(sdkManager: self.sdkManager, 
                                               dataContext: self.dataContext,
                                               presenter: self.presenter)
            if let previousOperation = previousOperation {
                operation.directDependency = previousOperation
                operation.addDependency(previousOperation)
            }
            previousOperation = operation
            return operation
        }
        return operations
    }

    func createOperationGroup<T: SDKOperation>(_ operationTypes: [T.Type],
                                               dataStore: SDKContext? = nil) -> [T] {
        let operationDataStore = dataStore ?? self.dataContext
        self.dataContext = operationDataStore
        let operations = operationTypes.map { (sdkOperationType) -> T in
            let operation = sdkOperationType.init(sdkManager: self.sdkManager,
                                               dataContext: self.dataContext,
                                               presenter: self.presenter)
            return operation
        }
        return operations
    }

    var startTime = CFTimeInterval(0)
    var completionTime = CFTimeInterval(0)
    var beginMemoryStats = MemoryStatistics.current

    override func main() {
        assert(Thread.isMainThread == false, "Should not schedule these operations from the main queue")

        if let dependecy = self.directDependency {
            guard dependecy.operationCompletedSuccessfully else {
                print("Operation: \(self.name ?? "Noname operation") is being cancelled due to failure of \(String(describing: dependecy.name))")
                self.operationCompletedSuccessfully = false
                self.finishOperation()
                return
            }
        }

        guard self.isCancelled == false else {
            self.operationCompletedSuccessfully = false
            print("Operation: \(self.name ?? "Operation name is not set and") was cancelled from outside")
            return
        }

        let failedDependencies = self.dependencies.filter { $0.isCancelled }
        guard failedDependencies.isEmpty else {
            print("Operation: \(String(describing: type(of: self))) has some failed dependencies. Cancelling current Operation")
            self.operationCompletedSuccessfully = false
            self.cancel()
            return
        }
        self.startTime = CACurrentMediaTime()
        self.startOperation()
    }

    @objc final func updateContext(notification: Notification) {
        guard let sdkContext = notification.userInfo?[NotificationObjectKeys.sdkContext] as? SDKContext
        else {
            print("Operation: did not recieve context in updateContext notification")
            return
        }
        self.dataContext = sdkContext

    }

    final func markOperationComplete() {
        self.completionTime = CACurrentMediaTime()
        let difference = MemoryStatistics.currentDifference(MemoryStatistics.beginningMemory)
        print("Operation: Overall Memory Change after \(self.name ?? String(describing: type(of: self))) \(difference)")
        print("Operation: Total Time for \(self.name ?? String(describing: type(of: self))): \(self.completionTime - self.startTime)")
        self.operationCompletedSuccessfully = true
        self.finishOperation()
    }

    final func markOperationFailed() {
        self.completionTime = CACurrentMediaTime()
        print("Operation: Total Time for \(self.name ?? String(describing: type(of: self))): \(self.completionTime - self.startTime)")
        print("Operation: Operation Failed: \(self.name ?? String(describing: type(of: self))) ")
        self.operationCompletedSuccessfully = false
        self.finishOperation()
    }

    override func cancel() {
        print("Operation: Operation Cancelled: \(self.name ?? String(describing: type(of: self))) ")
        super.cancel()
        self.operationCompletedSuccessfully = false
        self.cleanup()
        self.finishOperation()
    }

    func startOperation() { fatalError("Operation: This should be overriden by subclasses") }

    func finishOperation() {
        self.cleanup()
        print("Operation: Finished Operation: \(self.name ?? String(describing: type(of: self)))")
    }

    final func cleanup() {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name.sdkContextDidChange, object: nil)
    }

    internal func createOperation<T: SDKOperation>() -> T {
        return T(sdkManager: self.sdkManager,
                 dataContext: self.dataContext,
                 presenter: self.presenter)
    }
}


internal typealias SDKSetupInlineOperation = SDKOperation
internal class SDKSetupAsyncOperation: SDKOperation {
    // MARK: overriding existing properties from NSOperation
    private var iAsynchronous: Bool = true
    override final var isAsynchronous: Bool {
        get { return iAsynchronous }
        set { iAsynchronous = newValue }
    }

    private var iExecuting: Bool = false
    override final var isExecuting: Bool {
        get { return iExecuting }
        set {
            if iExecuting != newValue {
                willChangeValue(forKey: "isExecuting")
                iExecuting = newValue
                didChangeValue(forKey: "isExecuting")
            }
        }
    }

    private var iFinished: Bool = false
    override final var isFinished: Bool {
        get {
            return iFinished
        }
        set {
            if iFinished != newValue {
                willChangeValue(forKey: "isFinished")
                iFinished = newValue
                didChangeValue(forKey: "isFinished")
            }
        }
    }

    override final func start() {
        self.main()
    }

    override func finishOperation() {
        self.isExecuting = false
        self.isFinished = true
    }
}

internal typealias MemoryStatistics = mstats
extension MemoryStatistics: CustomDebugStringConvertible {

    // Static variable to store the beginning memory statistics
    // Usually set within module initialization
    static private(set) var beginningMemory = MemoryStatistics.current

    private static var setupDone = false

    static func setupBeginningMemory() {
        guard self.setupDone == false else {
            return
        }

        self.beginningMemory = MemoryStatistics.current
        self.setupDone = true
    }

    static var current: MemoryStatistics {
        return mstats()
    }

    public var debugDescription: String {
        "Operation: Total Bytes: \(bytes_total.bytes); Used: \(bytes_used.bytes); Free: \(bytes_free.bytes); Used Chunks: \(chunks_used) Free Chunks: \(chunks_free)"
    }

    static func - (left: MemoryStatistics, right: MemoryStatistics) -> MemoryStatistics {
        var result = MemoryStatistics()
        result.bytes_total = left.bytes_total - right.bytes_total
        result.bytes_used = left.bytes_used - right.bytes_used
        result.bytes_free = left.bytes_free - right.bytes_free
        result.chunks_free = left.chunks_free - right.chunks_free
        result.chunks_used = left.chunks_used - right.chunks_used
        return result
    }

    static func diffDescription(left: MemoryStatistics, right: MemoryStatistics) -> String {
        return "Change: \(left - right)"
    }

    static func currentDifference(_ other: MemoryStatistics) -> MemoryStatistics {
        return MemoryStatistics.current - other
    }

}

extension Int {
    var bytes: String {
        return ByteCountFormatter.string(fromByteCount: Int64(self), countStyle: .memory)
    }
}
