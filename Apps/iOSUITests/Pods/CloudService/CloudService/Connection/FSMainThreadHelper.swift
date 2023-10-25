
/*
******************************************************************
* COPYRIGHT (c) <<2020>> <<Tanu Inc  >>         *
*
 * All rights reserved                                           *
*
 * This software embodies materials and concepts which are       *
* confidential to <<Customer Name>> and is made available solely *
* pursuant to the terms of a written license agreement with      *
* <<Tanu  Product>>.                                             *
*
* Designed and Developed by Tanu Inc                             *
.           *
*----------------------------------------------------------------*
* MODULE OR UNIT: CloudService                                   *
*
* PROGRAMMER :  Tanuja Awasthi                                   *
* DATE       :  18/07/20                                         *
* VERSION    :  1.0                                              *
*
*----------------------------------------------------------------*
*
* MODULE SUMMARY : This is thread checker class. Only access to  *
       Cloud service                                             *
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

public class FSMainThreadHelper {
   public static func runSyncOnMainThread<T>(block: ()->(T?)) -> T? {
        // Check if already in MainThread
        if Thread.isMainThread {
            return block()
        }
        // Force to run block in MainThread
        let result = DispatchQueue.main.sync(execute: {
            return block()
        })
        return result
    }    
}
