//
//  ValidationTest.swift
//  UnitTestLearning
//
//  Created by Ashish Awasthi on 05/10/24.
//


import Testing
import UnitTestLearning

@Suite("Login Credentials Validations Tests")
struct ValidationTest {
    // Add your test cases

    @Test("Check various invalid emails",arguments: ["abc@f.i","abc@.in","@.in","abc@fin","abc@fin.","abc+1@finco"])
    func invalidEmails(args: String) {
        let isValid = args.evaluate(regex: RegexStrings.emailRegex)
        #expect(!isValid)
    }

    @Test("Check various credentials", arguments: ["abc+1@fin.co", "abc.zyx@cc.com"],
          ["abcd123@!AA", "sss121BB@AA"] )
    func validateCredentails(email: String,
                             password: String) {
        let isValidEmail = email.evaluate(regex: RegexStrings.emailRegex)
        let isValidPassword = password.evaluate(regex: RegexStrings.passwordRegex)
        let isValid = isValidEmail && isValidPassword
        #expect(isValid)
    }

    @Test(
        "Check various credentials",
        arguments: zip(["abc+1@fin.co", "abc.zyx@cc.com"], ["abcd123@!AA", "sss121BB@AA"]))
    func validateCredentails2(email: String, password: String) {
        let isValidEmail = email.evaluate(regex: RegexStrings.emailRegex)
        let isValidPassword = password.evaluate(regex: RegexStrings.passwordRegex)
        let isValid = isValidEmail && isValidPassword
        #expect(isValid)
    }
}
