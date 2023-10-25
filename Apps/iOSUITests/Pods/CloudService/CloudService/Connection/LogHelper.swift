
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
* MODULE SUMMARY : This log helper independent private class.    *
  by using this class, we are logging Cloud SDK log              *
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

internal func pretty_print(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
	FSLogInfo(message, file: file, function: function, line: line)
}

internal func pretty_print_error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
	FSLogError(message, file: file, function: function, line: line)
}

fileprivate class FSLoggerDate {
	static var dateFormatter: DateFormatter?

	class func dateNow() -> String {
		if FSLoggerDate.dateFormatter == nil {
			FSLoggerDate.dateFormatter = DateFormatter()
#if DEBUG
			FSLoggerDate.dateFormatter!.dateFormat = "HH:mm:ss.SSS"
#else
			FSLoggerDate.dateFormatter!.dateFormat = "yyyy-MM-dd HH:mm:ss"
#endif
		}
		return FSLoggerDate.dateFormatter!.string(from: Date())
	}
}

#if DEBUG
internal func FSLogDebug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    let f = (file as NSString).lastPathComponent
	let d = FSLoggerDate.dateNow()
    print("\(d) \(libName) 📘 \(f) \(function) \(message)")
}
#endif

internal func FSLogInfo(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
	let f = (file as NSString).lastPathComponent
	let d = FSLoggerDate.dateNow()
#if DEBUG
	print("\(d) \(libName) 📒 \(f) \(function) \(message)")
#else
	print("\(d) \(libName) INFO \(f) \(function) \(message)")
#endif
}

internal func FSLogWarning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
	let f = (file as NSString).lastPathComponent
	let d = FSLoggerDate.dateNow()
#if DEBUG
	print("\(d) \(libName) 📙 \(f) \(function) \(message)")
#else
	print("\(d) \(libName) WARNING \(f) \(function) \(message)")
#endif
}

internal func FSLogError(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
	let f = (file as NSString).lastPathComponent
	let d = FSLoggerDate.dateNow()
#if DEBUG
	print("\(d) \(libName) 📕 \(f) \(function) \(message)")
#else
	print("\(d) \(libName) ERROR \(f) \(function) \(message)")
#endif
}

internal func FSFrameworkVersion() {
    let d = FSLoggerDate.dateNow()
    #if DEBUG
      print("\(d) \(libName) :  📘 \(libVersion)")
    #else
        print("\(d) \(libName) Info \(libVersion)")
    #endif
}

