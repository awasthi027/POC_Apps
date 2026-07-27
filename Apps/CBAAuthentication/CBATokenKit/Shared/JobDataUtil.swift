//
//  JobDataUtil.swift
//  CBAAuthentication
//
//  Created by Ashish Awasthi on 24/07/26.
//

import Foundation
// Be careful when importing frameworks.  This is used by the token extension, which restricts what can be used.

class JobDataUtil: NSObject {
    // MARK: - Reading and Writing
    static var jobSettings: JobSettings = CBAJobSettings.shared

    public class func clearFromSharedDefaults() {
        jobSettings.jobData = nil
    }

    /// validates the dictionary argument. If valid, then writes the dictionary to specified user defaults.
    /// returns: true if the dictionary was valid and successfully written
    ///
    class func writeToDefaults(jobData: TokenKeyJobData) {
        var ykOperationData: Data?
        do {
            NSKeyedArchiver.setClassName("TokenKeyJobData", for: TokenKeyJobData.classForKeyedArchiver()!)    // required due to crossing framework boundaries
            ykOperationData = try NSKeyedArchiver.archivedData(withRootObject: jobData, requiringSecureCoding: false)
        } catch {
            // not much we can do here since this is also used in token extension.  We have no logging library available to a token extension. No UI is allowed in a token extension.
            return
        }

        jobSettings.jobData = ykOperationData
    }

    class func readFromSharedDefaults() -> TokenKeyJobData? {
        guard let encodedJobData = jobSettings.jobData else {
            return nil
        }
        var resultJobData: TokenKeyJobData?
        do {
            NSKeyedUnarchiver.setClass(TokenKeyJobData.classForKeyedUnarchiver(), forClassName: "TokenKeyJobData")      // must map class due to this crossing framework boundaries
            NSKeyedUnarchiver.setClass(NSError.classForKeyedUnarchiver(), forClassName: "YKFSessionError")            // must map class to cross boundaries - token extension cannot access YubiKit for YKFSessionError, but it is subclass of NSError
            resultJobData = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(encodedJobData) as? TokenKeyJobData
        } catch let error {
            // not much we can do here since this is also used in token extension.  We have no logging library available to a token extension. No UI is allowed in a token extension.
            print("error: \(error)")
            return nil
        }
        // we don't decide anything about the validity, just get the data
        return resultJobData
    }

    // MARK: - signalling

    // This is a protocol of communication between the extension and the app.
    // When the token extension sets up a job, it specifies a value for the finishedDefaultsKey member.
    //  it then begins to watch for a defaults value to be set with that key.
    // When an operation is finished and results/errors are loaded back into this item, the specified key is
    // used to save a little data in shared user defaults. It does not matter what value is stored in the entry with that key.
    // When the token extension sees an entry appear with the key, it reads the data and completes the token operation.

    public class func setFinishedFlag( flagName: String, suiteName: String = CBAConstants.appGroupIdentifier) {
        guard let sharedDefaults = UserDefaults(suiteName: suiteName) else {
            // this class is also used in token extension where we have no access to the UI and no access to a logging library
            return
        }
        sharedDefaults.set(true, forKey: flagName)
    }

}
