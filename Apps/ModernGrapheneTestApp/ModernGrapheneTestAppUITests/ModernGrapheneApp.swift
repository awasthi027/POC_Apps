//
//  ModernGrapheneApp.swift
//  UITestPOCUITests
//
//  Created by Ashish Awasthi on 05/02/24.
//

import Foundation
import XCTest

//app needs a bundle id
public protocol GrapheneApplicationProtocol {
    //var bundleID: String {get}
    var application: XCUIApplication { get }
}



/// A abstract base class for declaring Apps (like Hub, Safari, and Settings) within this module.
/// Subclasses inherit the @Screen declaration curtesy of this class's conformance to `ScreenDeclaring`
open class BasicGrapheneApp: GrapheneApplicationProtocol, ScreenDeclaring, AppProviding {

   // let mockOverrides: URL

    public var application: XCUIApplication

  //  @Screen var anyScreen: AnyScreen

    public init(application: XCUIApplication) {
//        let testName = RetryableTestCase.currentTestCase?.filesafeName ?? UUID().uuidString
//        let mapFile = URL(
//            fileURLWithPath: "\(testName).routeMap",
//            relativeTo: URL(fileURLWithPath: ProcessInfo.processInfo.environment["TMPDIR"] ?? FileManager.default.currentDirectoryPath)
//        )

     //   self.mockOverrides = mapFile

        self.application = application

        //XCTAssertNoThrow(try self.removeMocks())
//
//        self.app.launchEnvironment.merge([Router.mockOverridesRoutMapKey: mockOverrides.path],
//                                         uniquingKeysWith: { $1 })

        InstanceInjectionRecipient<Self>.claimUnclaimed(with: self as! Self)
//                                                                 ^^ This is silly right?
//                                                                 One day, the compiler will open
//                                                                 its eyes and go, "Holy S**t!!!"

//        let _: [DiscoverableProperty] = Screen<FeatureValidatedScreen>.discoverMembers(of: self)
//
//
//        if let testCase = RetryableTestCase.currentTestCase {
//            testCase.addTeardownBlock {
//                do {
//                    try self.removeMocks()
//                } catch {
//                    XCTFail("Unable to remove route map file: \(error)")
//                }
//            }
//        } else {
//            XCTContext.runActivity(named: "WARNING: leaking route map file at \(mockOverrides) because \(Self.self) was initialized outside of the context of a \(GrapheneTestCase.self)") { _ in }
//        }
    }

//    public func removeMocks() throws {
//        if FileManager.default.fileExists(atPath: mockOverrides.path) {
//            try FileManager.default.removeItem(at: mockOverrides)
//        }
//    }

//    public func mock(@RouteMappingBuilder _ builder: () -> [RouteMapping]) throws {
//        try JSONEncoder().encode(builder()).write(to: mockOverrides)
//    }
}

///This Class is used for leveraging features from Modern Graphene.
///All new FeatureValidatedScreens in SDK app can be added here.
open class SDKApp: BasicGrapheneApp {
    public override init(application: XCUIApplication) {
        super.init(application: application)
    }
}

/// A class that encapsulates the XCUIApplication and its Screens under test.
public class ModernGrapheneApp: SDKApp {
    public let schemeName: String?

    public init(bundleID: String = "com.air-watch.pivd", schemeName: String?) {
        self.schemeName = schemeName
        let app = XCUIApplication()
        app.launchArguments = ["isRunningUITests"]
        super.init(application: app)

//        // Add testObserver to XCTestObservationCenter
//        XCTestObservationCenter.shared.addTestObserver(pivdUITestObserver)
    }

    //MARK: General screens
    @Screen(timeout: 60) var homeScreen: ModernGrapheHomeScreen

}
