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
* MODULE SUMMARY : This is the shared class for checking         *
   reachbility. As of now its part of  Cloud connect             *
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
import UIKit

private let ExtenalReachabilityChangedNotification = NSNotification.Name("ExtenalReachabilityChangedNotification")

protocol ReachabilityProtocol: AnyObject {
    func reachability(_ manager: ReachabilityManager, didNetworkChange isReachabil: Bool)
}
public class ReachabilityManager: NSObject {
    /// shared instance
    public static let shared = ReachabilityManager()
    var noNetworkView: NetworkStatusView?
    /// Set message properties
    public var messageAttribute: MessageAttribute = MessageAttribute()
    /** No alert message navigation direction */
    public var defaultMsgPosition: UINavigationLabelAnimationDirection = .eBottom
    /** dafault is FALSE. will not display alert message */
    public var isEnableMessageView: Bool =  false
   
    weak var delegate: ReachabilityProtocol?
    
    private override init() {
        super.init()
        self.startMonitoring()
       
    }
    /** Boolean to track network reachability  Get propertoy */
    public var isNetworkAvailable : Bool {
        return reachability.connection == .wifi || reachability.connection == .cellular
    }
    
    public var isWifiActive: Bool {
      return reachability.connection == .wifi
    }
    
    public var isCellularActive: Bool {
        return reachability.connection == .cellular
    }
    
    /** Reachibility instance for Network status monitoring */
    let reachability = Reachability()!
    
    /** Called whenever there is a change in NetworkReachibility Status */
    /** Parameter notification: Notification with the Reachability instance */
    @objc func reachabilityChanged(notification: Notification) {
        var isReachabil: Bool = false
        var networkStatus: Int = 0
        let reachability = notification.object as! Reachability
        switch reachability.connection {
        case .none:
            isReachabil = false
            debugPrint("Network became unreachable")
        case .wifi:
            networkStatus = 1
            isReachabil = true
            debugPrint("Network reachable through WiFi")
        case .cellular:
            networkStatus = 2
            isReachabil = true
            debugPrint("Network reachable through Cellular Data")
        }
        self.delegate?.reachability(self, didNetworkChange: isReachabil)
        NotificationCenter.default.post(name: ExtenalReachabilityChangedNotification, object: ["status" : networkStatus], userInfo:nil)
    }
  
    /** Starts monitoring the network availability status */
    public func startMonitoring() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.reachabilityChanged),
                                               name: Notification.Name.reachabilityChanged,
                                               object: reachability)
        do{
            try reachability.startNotifier()
        }catch{
            debugPrint("Could not start reachability notifier")
        }
    }
    
    /** Stops monitoring the network availability status */
    public func stopMonitoring() {
        reachability.stopNotifier()
        NotificationCenter.default.removeObserver(self, name: Notification.Name.reachabilityChanged,
                                                  object: reachability)
    }
    /** Display meessge message no internet */
    public func displayInternetStatus() {
        NetworkStatusView.messageAttribute = messageAttribute
        if ReachabilityManager.shared.isEnableMessageView == false {
            return
        }
        DispatchQueue.main.async {
            if self.noNetworkView == nil {
             self.noNetworkView = NetworkStatusView.init(frame:  CGRect(x: xPosition, y: NetworkStatusView.yPositionOfLabel(withDirection: .eTop), width: (UIScreen.main.bounds.size.width - 2 * xPosition) , height: NavigationViewHeight))
            }
            if let item  = self.noNetworkView {
             item.displayInternetStatus()
            }
        }
    }
}
