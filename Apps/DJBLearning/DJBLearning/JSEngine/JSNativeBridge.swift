//
//  JSNativeBridge.swift
//  DJBLearning
//
//  Installs every `native_*` global that `decoded_payload.js` expects into a
//  `JSContext`, bridging each call to the real implementations in
//  `NativeChecks`. This is the ONLY place that knows about JavaScriptCore -
//  `NativeChecks` stays framework-agnostic and testable on its own.
//

import Foundation
import JavaScriptCore
import UIKit

enum JSNativeBridge {

    /// Registers every `native_*` symbol the payload references as a global
    /// on `context`, plus the `native_PlatformInfo` object property.
    static func install(context: JSContext, logger: JSRunLog) {
        installPlatformInfo(context: context)
        installLogging(context: context, logger: logger)
        installMountChecks(context: context)
        installDebugAndEnvironmentChecks(context: context)
        installEnforcementChecks(context: context)
        installFileSystemChecks(context: context)
        installProcessChecks(context: context)
    }

    // MARK: - native_PlatformInfo

    private static func installPlatformInfo(context: JSContext) {
        context.setObject(
            [
                "systemName": "iOS",
                "systemVersion": UIDevice.current.systemVersion
            ],
            forKeyedSubscript: "native_PlatformInfo" as NSString
        )
    }

    // MARK: - native_Log / native_ReportException

    private static func installLogging(context: JSContext, logger: JSRunLog) {
        let logBlock: @convention(block) (String, String) -> Void = { level, message in
            logger.log(level: level, message: message)
        }
        context.setObject(logBlock, forKeyedSubscript: "native_Log" as NSString)

        let reportExceptionBlock: @convention(block) (String) -> Void = { message in
            logger.reportException(message)
        }
        context.setObject(reportExceptionBlock, forKeyedSubscript: "native_ReportException" as NSString)
    }

    // MARK: - native_GetFileSystemCount / native_GetFileSystemAttributes

    private static func installMountChecks(context: JSContext) {
        let attributesBlock: @convention(block) () -> [[String: Any]] = {
            NativeChecks.fileSystemAttributes()
        }
        context.setObject(attributesBlock, forKeyedSubscript: "native_GetFileSystemAttributes" as NSString)

        let countBlock: @convention(block) () -> Int = {
            NativeChecks.fileSystemAttributes().count
        }
        context.setObject(countBlock, forKeyedSubscript: "native_GetFileSystemCount" as NSString)
    }

    // MARK: - native_CheckDebugPermission / native_IsDEBUG / native_CheckEnvironmentVariablePresent

    private static func installDebugAndEnvironmentChecks(context: JSContext) {
        let debugPermissionBlock: @convention(block) () -> Bool = {
            NativeChecks.isDebuggerAttached()
        }
        context.setObject(debugPermissionBlock, forKeyedSubscript: "native_CheckDebugPermission" as NSString)

        let isDebugBlock: @convention(block) () -> Bool = {
            #if DEBUG
            return true
            #else
            return false
            #endif
        }
        context.setObject(isDebugBlock, forKeyedSubscript: "native_IsDEBUG" as NSString)

        // The payload passes a `DataView` wrapping a 32-byte SHA-256 digest.
        // JavaScriptCore doesn't auto-bridge typed array byte contents, so we
        // use a tiny JS helper (evaluated once) to unwrap it into a plain
        // number array we CAN read from Swift.
        let dataViewToByteArray = context.evaluateScript(
            "(function(dv){ return Array.from(new Uint8Array(dv.buffer)); })"
        )

        let envVarBlock: @convention(block) (JSValue) -> Bool = { dataView in
            guard let converter = dataViewToByteArray,
                  let bytesValue = converter.call(withArguments: [dataView]),
                  let numbers = bytesValue.toArray() as? [NSNumber] else {
                return false
            }
            let targetHash = numbers.map { UInt8(truncating: $0) }
            return NativeChecks.environmentVariableMatchesHash(targetHash)
        }
        context.setObject(envVarBlock, forKeyedSubscript: "native_CheckEnvironmentVariablePresent" as NSString)
    }

    // MARK: - native_CheckVnodeEnforce / native_CheckProcEnforce / native_CheckCodeSigningPermissions

    private static func installEnforcementChecks(context: JSContext) {
        let vnodeBlock: @convention(block) () -> Bool = {
            NativeChecks.isVnodeEnforced()
        }
        context.setObject(vnodeBlock, forKeyedSubscript: "native_CheckVnodeEnforce" as NSString)

        let procEnforceBlock: @convention(block) () -> Bool = {
            NativeChecks.isProcEnforced()
        }
        context.setObject(procEnforceBlock, forKeyedSubscript: "native_CheckProcEnforce" as NSString)

        let codeSigningBlock: @convention(block) () -> Bool = {
            NativeChecks.isCodeSigningEnforced()
        }
        context.setObject(codeSigningBlock, forKeyedSubscript: "native_CheckCodeSigningPermissions" as NSString)
    }

    // MARK: - Filesystem existence / dylib / stat / write checks

    private static func installFileSystemChecks(context: JSContext) {
        let fileExistsBlock: @convention(block) (String) -> Bool = { path in
            FileManager.default.fileExists(atPath: path)
        }
        context.setObject(fileExistsBlock, forKeyedSubscript: "native_CheckFileSystemItemExistsAtLocation" as NSString)

        let dylibLoadingBlock: @convention(block) (JSValue) -> Bool = { pathsValue in
            guard let paths = pathsValue.toArray() as? [String] else { return false }
            return NativeChecks.isAnyDylibLoaded(matching: paths)
        }
        context.setObject(dylibLoadingBlock, forKeyedSubscript: "native_CheckDynamicLibraryLoading" as NSString)

        let runtimeLibBlock: @convention(block) (String) -> Bool = { substring in
            NativeChecks.isAnyDylibLoaded(matching: [substring])
        }
        context.setObject(runtimeLibBlock, forKeyedSubscript: "native_CheckForLibrariesLoadedByApplicationAtRuntime" as NSString)

        let statBlock: @convention(block) (String, Bool) -> [String: Any] = { path, _ in
            NativeChecks.fileStatistics(atPath: path)
        }
        context.setObject(statBlock, forKeyedSubscript: "native_GetFileStatistics" as NSString)

        let createFileBlock: @convention(block) (String, String) -> Bool = { path, content in
            NativeChecks.attemptWrite(toPath: path, content: content)
        }
        context.setObject(createFileBlock, forKeyedSubscript: "native_CreateFileSystemItemAtLocation" as NSString)
    }

    // MARK: - Process creation / shell presence / anti-debug

    private static func installProcessChecks(context: JSContext) {
        let canForkBlock: @convention(block) () -> Bool = {
            NativeChecks.canFork()
        }
        context.setObject(canForkBlock, forKeyedSubscript: "native_CheckProcessCreation" as NSString)

        let systemShellBlock: @convention(block) () -> Bool = {
            NativeChecks.isSystemShellAbsent()
        }
        context.setObject(systemShellBlock, forKeyedSubscript: "native_CheckSystemShell" as NSString)

        let disablePTraceBlock: @convention(block) () -> Void = {
            NativeChecks.disablePTrace()
        }
        context.setObject(disablePTraceBlock, forKeyedSubscript: "native_DisablePTrace" as NSString)
    }
}
