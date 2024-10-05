//
//  RegexStrings.swift
//  UnitTestLearning
//
//  Created by Ashish Awasthi on 05/10/24.
//

import Foundation

open class  RegexStrings {
    /// Password must contain at least 8 characters, 1 uppercase, 1 number, and 1 special character.
    public static var passwordRegex: String {
        let oneOrMoreUpperCase = "(?=.*[A-Z])"
        let oneOrMoreLowerCase = "(?=.*[a-z])"
        let oneOrMoreNumber = "(?=.*[0-9])"
        let oneOrMoreSpecials = "(?=.*[!@#$%^&*()_+=-])"
        let lengthGreaterThan = "{8,}"
        return "^\(oneOrMoreUpperCase)\(oneOrMoreLowerCase)\(oneOrMoreNumber)\(oneOrMoreSpecials).\(lengthGreaterThan)"
    }

    /// Email predicate alphabet & number more than one + @ +
    public static var emailRegex: String {
        let firstpart = "[A-Z0-9a-z]([A-Z0-9a-z._%+-]{0,30}[A-Z0-9a-z])?"
        let serverpart = "([A-Z0-9a-z]([A-Z0-9a-z-]{0,30}[A-Z0-9a-z])?\\.){1,5}"
        return firstpart + "@" + serverpart + "[A-Za-z]{2,6}"
    }
}

extension String {
    public func evaluate(regex: String) -> Bool {
        let predicate = NSPredicate(format: "SELF MATCHES %@", regex)
        return predicate.evaluate(with: self)
    }
}
