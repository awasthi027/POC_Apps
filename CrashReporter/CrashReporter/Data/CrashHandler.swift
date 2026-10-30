import Foundation
import MachO

/// Captures crashes and persists them as Apple-format `.ips` reports in Application Support/CrashReports.
///
/// The crash-time path only writes a small raw record (signal, fault address, raw return
/// addresses) with async-signal-safe calls, on an alternate stack so stack overflows are
/// survivable. On the next launch the record is combined with the image list (UUIDs/bases)
/// snapshotted at launch and written out as a full `.ips`, which Xcode can symbolicate
/// against the matching dSYM.
enum CrashHandler {
    private static let launchDate = Date()

    static func install() {
        let fm = FileManager.default
        try? fm.createDirectory(at: FileCrashRepository.directory, withIntermediateDirectories: true)
        try? fm.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
        for url in [FileCrashRepository.directory, supportDirectory] {
            var excluded = url
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? excluded.setResourceValues(values)
        }

        // Convert a record left by the previous run before this launch overwrites the metadata.
        IPSReport.finalizePending(record: pendingURL, metadata: metadataURL,
                                  into: FileCrashRepository.directory)
        IPSReport.writeMetadata(to: metadataURL, launchDate: launchDate)

        RawRecord.prepare(path: pendingURL.path)
        installAlternateStack()

        NSSetUncaughtExceptionHandler { exception in
            RawRecord.saveException(exception)
        }

        for sig in [SIGABRT, SIGILL, SIGTRAP, SIGSEGV, SIGBUS, SIGFPE] {
            var action = sigaction()
            action.__sigaction_u.__sa_sigaction = handleSignal
            // SA_ONSTACK runs the handler on the alternate stack (a stack overflow leaves none
            // on the faulting one).
            action.sa_flags = SA_SIGINFO | SA_ONSTACK | SA_RESETHAND
            sigemptyset(&action.sa_mask)
            sigaction(sig, &action, nil)
        }
    }

    private static var supportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CrashHandler", isDirectory: true)
    }
    private static var pendingURL: URL { supportDirectory.appendingPathComponent("pending.crash") }
    private static var metadataURL: URL { supportDirectory.appendingPathComponent("metadata.json") }

    /// sigaltstack is per-thread, so this covers the thread that calls install() (the main thread).
    private static func installAlternateStack() {
        let size = 128 * 1024
        var stack = stack_t()
        stack.ss_sp = malloc(size)
        stack.ss_size = size
        stack.ss_flags = 0
        sigaltstack(&stack, nil)
    }
}

private func handleSignal(_ sig: Int32, _ info: UnsafeMutablePointer<siginfo_t>?,
                          _ context: UnsafeMutableRawPointer?) {
    RawRecord.saveSignal(sig, info: info, context: context)
    // Returning would re-execute the faulting instruction (a trap like an array index failure
    // can then spin instead of dying), so terminate explicitly with the default action.
    signal(sig, SIG_DFL)
    var unblock = sigset_t()
    sigemptyset(&unblock)
    sigaddset(&unblock, sig)
    pthread_sigmask(SIG_UNBLOCK, &unblock, nil)
    raise(sig)
}

// MARK: - Crash-time record (async-signal-safe: no allocation, no Foundation, no locks)

private enum RawRecord {
    static let maxFrames = 512
    static let reasonCapacity = 2048
    static let magic: UInt64 = 0x4950_5343_5241_5348
    /// Words: magic, kind (0 signal, 1 exception), signal, si_code, fault address,
    /// seconds, microseconds, thread id, frame count, reason length; then frames, then reason bytes.
    static let headerWords = 10

    struct State {
        var path: UnsafeMutablePointer<CChar>
        var buffer: UnsafeMutablePointer<UInt64>
        var saved: Bool
    }

    // A `let` pointer (rather than static vars) avoids lazy-init and exclusivity checks at crash time.
    static let state: UnsafeMutablePointer<State> = {
        let words = headerWords + maxFrames + reasonCapacity / 8 + 1
        let s = UnsafeMutablePointer<State>.allocate(capacity: 1)
        s.initialize(to: State(path: strdup(""),
                               buffer: UnsafeMutablePointer<UInt64>.allocate(capacity: words),
                               saved: false))
        return s
    }()

    static func prepare(path: String) {
        free(state.pointee.path)
        state.pointee.path = strdup(path)
    }

    static func saveSignal(_ sig: Int32, info: UnsafeMutablePointer<siginfo_t>?,
                           context: UnsafeMutableRawPointer?) {
        let s = state
        if s.pointee.saved { return }
        s.pointee.saved = true
        let frames = s.pointee.buffer + headerWords
        let count = context.map { captureFrames(from: $0, into: frames) } ?? 0
        commit(kind: 0, signal: sig, code: info?.pointee.si_code ?? 0,
               faultAddress: UInt64(UInt(bitPattern: info?.pointee.si_addr)),
               frameCount: count, reason: nil, reasonLength: 0)
    }

    static func saveException(_ exception: NSException) {
        let s = state
        if s.pointee.saved { return }
        s.pointee.saved = true
        let frames = s.pointee.buffer + headerWords
        var count = 0
        for address in exception.callStackReturnAddresses.prefix(maxFrames) {
            frames[count] = UInt64(address.uintValue)
            count += 1
        }
        let text = "\(exception.name.rawValue)\u{1}\(exception.reason ?? "unknown")"
        let bytes = Array(text.utf8.prefix(reasonCapacity))
        bytes.withUnsafeBufferPointer {
            commit(kind: 1, signal: SIGABRT, code: 0, faultAddress: 0, frameCount: count,
                   reason: $0.baseAddress, reasonLength: $0.count)
        }
    }

    /// Frame 0 is the faulting pc, then lr, then the frame-pointer chain of the crashing thread.
    private static func captureFrames(from context: UnsafeMutableRawPointer,
                                      into out: UnsafeMutablePointer<UInt64>) -> Int {
        let thread = context.assumingMemoryBound(to: ucontext_t.self)
            .pointee.uc_mcontext.pointee.__ss
        #if arch(arm64)
        // Return addresses on the stack may carry pointer-authentication bits.
        let mask: UInt64 = 0x7F_FFFF_FFFF
        let pc = UInt64(thread.__pc) & mask
        let lr = UInt64(thread.__lr) & mask
        var fp = UInt64(thread.__fp)
        #elseif arch(x86_64)
        let mask = UInt64.max
        let pc = UInt64(thread.__rip)
        let lr: UInt64 = 0
        var fp = UInt64(thread.__rbp)
        #else
        return 0
        #endif

        var count = 0
        out[count] = pc; count += 1
        if lr != 0 { out[count] = lr; count += 1 }

        let me = pthread_self()
        let high = UInt64(UInt(bitPattern: pthread_get_stackaddr_np(me)))
        let low = high &- UInt64(pthread_get_stacksize_np(me))
        var first = true
        while count < maxFrames, fp != 0, fp & 0x7 == 0, fp >= low, fp &+ 16 <= high {
            let record = UnsafePointer<UInt64>(bitPattern: UInt(fp))!
            let next = record[0]
            let ret = record[1] & mask
            if ret == 0 { break }
            // On arm64 the first saved lr normally repeats the lr register.
            if !(first && ret == lr) { out[count] = ret; count += 1 }
            first = false
            if next <= fp { break }
            fp = next
        }
        return count
    }

    private static func commit(kind: UInt64, signal: Int32, code: Int32, faultAddress: UInt64,
                               frameCount: Int, reason: UnsafePointer<UInt8>?, reasonLength: Int) {
        let s = state
        let buf = s.pointee.buffer
        var tv = timeval()
        gettimeofday(&tv, nil)
        var tid: UInt64 = 0
        pthread_threadid_np(nil, &tid)

        buf[0] = magic
        buf[1] = kind
        buf[2] = UInt64(signal)
        buf[3] = UInt64(bitPattern: Int64(code))
        buf[4] = faultAddress
        buf[5] = UInt64(tv.tv_sec)
        buf[6] = UInt64(tv.tv_usec)
        buf[7] = tid
        buf[8] = UInt64(frameCount)
        buf[9] = UInt64(reasonLength)
        if let reason, reasonLength > 0 {
            memcpy(UnsafeMutableRawPointer(buf + headerWords + frameCount), reason, reasonLength)
        }

        let total = (headerWords + frameCount) * 8 + reasonLength
        let fd = open(s.pointee.path, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
        guard fd >= 0 else { return }
        var written = 0
        while written < total {
            let n = write(fd, UnsafeRawPointer(buf) + written, total - written)
            if n <= 0 { break }
            written += n
        }
        close(fd)
    }
}

// MARK: - Next-launch .ips generation

private enum IPSReport {
    // MARK: Metadata snapshot (written every launch)

    static func writeMetadata(to url: URL, launchDate: Date) {
        let info = Bundle.main.infoDictionary ?? [:]
        let images = loadedImages()
        let main = images.first { ($0["path"] as? String) == Bundle.main.executablePath }
        let meta: [String: Any] = [
            "appName": info["CFBundleName"] as? String ?? "App",
            "version": info["CFBundleShortVersionString"] as? String ?? "?",
            "build": info["CFBundleVersion"] as? String ?? "?",
            "bundleID": Bundle.main.bundleIdentifier ?? "unknown",
            "osTrain": osTrain(),
            "osBuild": sysctlString("kern.osversion"),
            "modelCode": modelCode(),
            "pid": ProcessInfo.processInfo.processIdentifier,
            "launch": launchDate.timeIntervalSince1970,
            "procPath": Bundle.main.executablePath ?? "",
            "mainUUID": main?["uuid"] as? String ?? "",
            "images": images
        ]
        if let data = try? JSONSerialization.data(withJSONObject: meta) {
            try? data.write(to: url, options: .atomic)
        }
    }

    private static func loadedImages() -> [[String: Any]] {
        var images: [[String: Any]] = []
        for i in 0..<_dyld_image_count() {
            guard let header = _dyld_get_image_header(i),
                  let name = _dyld_get_image_name(i) else { continue }
            let h = UnsafeRawPointer(header).assumingMemoryBound(to: mach_header_64.self)
            guard h.pointee.magic == MH_MAGIC_64 else { continue }

            var uuid = ""
            var low = UInt64.max, high: UInt64 = 0
            var cmd = UnsafeRawPointer(h) + MemoryLayout<mach_header_64>.size
            for _ in 0..<h.pointee.ncmds {
                let lc = cmd.assumingMemoryBound(to: load_command.self).pointee
                if lc.cmd == UInt32(LC_UUID) {
                    let u = cmd.assumingMemoryBound(to: uuid_command.self).pointee
                    uuid = UUID(uuid: u.uuid).uuidString.lowercased()
                } else if lc.cmd == UInt32(LC_SEGMENT_64) {
                    let seg = cmd.assumingMemoryBound(to: segment_command_64.self).pointee
                    let segName = withUnsafeBytes(of: seg.segname) {
                        String(cString: $0.bindMemory(to: CChar.self).baseAddress!)
                    }
                    if segName != "__PAGEZERO" && segName != "__LINKEDIT" {
                        low = min(low, seg.vmaddr)
                        high = max(high, seg.vmaddr + seg.vmsize)
                    }
                }
                cmd += Int(lc.cmdsize)
            }
            guard low != UInt64.max else { continue }

            let path = String(cString: name)
            images.append(["base": Int(UInt(bitPattern: header)), "size": Int(high - low),
                           "uuid": uuid, "path": path,
                           "name": (path as NSString).lastPathComponent,
                           "arch": arch(of: h.pointee)])
        }
        return images.sorted { ($0["base"] as? Int ?? 0) < ($1["base"] as? Int ?? 0) }
    }

    private static func arch(of header: mach_header_64) -> String {
        let sub = UInt32(bitPattern: header.cpusubtype) & 0x00FF_FFFF
        switch header.cputype {
        case CPU_TYPE_ARM64: return sub == 2 ? "arm64e" : "arm64"
        case CPU_TYPE_X86_64: return "x86_64"
        default: return "unknown"
        }
    }

    // MARK: Finalizing a pending record

    static func finalizePending(record: URL, metadata: URL, into directory: URL) {
        defer { try? FileManager.default.removeItem(at: record) }
        guard let raw = try? Data(contentsOf: record),
              raw.count >= RawRecord.headerWords * 8,
              let metaData = try? Data(contentsOf: metadata),
              let meta = (try? JSONSerialization.jsonObject(with: metaData)) as? [String: Any]
        else { return }

        func word(_ i: Int) -> UInt64 {
            raw.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: i * 8, as: UInt64.self) }
        }
        let frameCount = Int(word(8))
        let reasonLength = Int(word(9))
        guard word(0) == RawRecord.magic, frameCount <= RawRecord.maxFrames,
              raw.count >= (RawRecord.headerWords + frameCount) * 8 + reasonLength
        else { return }

        let kind = word(1)
        let sig = Int32(truncatingIfNeeded: word(2))
        let siCode = Int32(truncatingIfNeeded: Int64(bitPattern: word(3)))
        let faultAddress = word(4)
        let captured = Date(timeIntervalSince1970: TimeInterval(word(5)) + TimeInterval(word(6)) / 1e6)
        let tid = word(7)
        let addresses = (0..<frameCount).map { word(RawRecord.headerWords + $0) }
        let reasonStart = (RawRecord.headerWords + frameCount) * 8
        let reason = String(decoding: raw[reasonStart..<(reasonStart + reasonLength)], as: UTF8.self)

        // Symbolication needs each frame as (image, offset into image).
        var images = meta["images"] as? [[String: Any]] ?? []
        var absentIndex: Int?
        func frame(_ address: UInt64) -> [String: Any] {
            if let idx = images.firstIndex(where: {
                let base = UInt64($0["base"] as? Int ?? 0), size = UInt64($0["size"] as? Int ?? 0)
                return address >= base && address < base + size
            }) {
                return ["imageOffset": Int(address - UInt64(images[idx]["base"] as? Int ?? 0)),
                        "imageIndex": idx]
            }
            if absentIndex == nil {
                absentIndex = images.count
                images.append(["source": "A", "base": 0, "size": 0,
                               "uuid": "00000000-0000-0000-0000-000000000000"])
            }
            return ["imageOffset": Int(address), "imageIndex": absentIndex!]
        }
        let frames = addresses.map(frame)
        for i in images.indices where images[i]["source"] == nil { images[i]["source"] = "P" }

        let incident = UUID().uuidString
        let pid = meta["pid"] as? Int ?? 0
        let bundleID = meta["bundleID"] as? String ?? "unknown"
        let appName = meta["appName"] as? String ?? "App"
        let version = meta["version"] as? String ?? "?"
        let build = meta["build"] as? String ?? "?"
        let train = meta["osTrain"] as? String ?? "?"
        let osBuild = meta["osBuild"] as? String ?? "?"
        let launch = Date(timeIntervalSince1970: meta["launch"] as? TimeInterval ?? 0)
        let t = termination(sig: sig, siCode: siCode, address: faultAddress, pc: addresses.first ?? 0)

        var exception: [String: Any] = ["codes": t.codes, "type": t.type, "signal": t.signal]
        if let subtype = t.subtype { exception["subtype"] = subtype }

        var body: [String: Any] = [
            "version": 2, "userID": Int(getuid()), "procRole": "Foreground",
            "modelCode": meta["modelCode"] as? String ?? "",
            "osVersion": ["isEmbedded": isEmbedded, "train": train, "releaseType": "User", "build": osBuild],
            "captureTime": format(captured, fraction: 4),
            "incident": incident, "pid": pid, "translated": false, "cpuType": cpuType,
            "procLaunch": format(launch, fraction: 4), "procName": appName,
            "procPath": meta["procPath"] as? String ?? "",
            "bundleInfo": ["CFBundleShortVersionString": version, "CFBundleVersion": build,
                           "CFBundleIdentifier": bundleID],
            "parentProc": "launchd", "parentPid": 1, "coalitionName": bundleID,
            "codeSigningID": bundleID,
            "exception": exception,
            "termination": ["flags": 0, "code": Int(sig), "namespace": "SIGNAL",
                            "indicator": t.indicator, "byProc": "exc handler", "byPid": pid],
            "faultingThread": 0,
            "threads": [["id": tid, "triggered": true, "frames": frames]],
            "usedImages": images
        ]
        if kind == 1 {
            let parts = reason.components(separatedBy: "\u{1}")
            let name = parts.first ?? "NSException"
            let text = parts.count > 1 ? parts[1] : ""
            body["asi"] = ["CoreFoundation": [
                "*** Terminating app due to uncaught exception '\(name)', reason: '\(text)'"]]
            body["lastExceptionBacktrace"] = frames
        }

        let header: [String: Any] = [
            "app_name": appName, "timestamp": format(captured, fraction: 2),
            "app_version": version, "slice_uuid": meta["mainUUID"] as? String ?? "",
            "build_version": build, "platform": platform, "bundleID": bundleID,
            "share_with_app_devs": 0, "is_first_party": 0, "bug_type": "309",
            "os_version": "\(train) (\(osBuild))", "roots_installed": 0,
            "name": appName, "incident_id": incident
        ]

        // Apple's layout: one-line header JSON, newline, pretty-printed body JSON.
        guard var data = try? JSONSerialization.data(withJSONObject: header, options: [.sortedKeys]),
              let bodyData = try? JSONSerialization.data(withJSONObject: body,
                                                         options: [.prettyPrinted, .sortedKeys])
        else { return }
        data.append(0x0A)
        data.append(bodyData)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: directory.appendingPathComponent("\(incident).ips"), options: .atomic)
    }

    // MARK: Helpers

    private static func termination(sig: Int32, siCode: Int32, address: UInt64, pc: UInt64)
        -> (type: String, signal: String, indicator: String, codes: String, subtype: String?) {
        func hex(_ v: UInt64) -> String { String(format: "0x%016llx", v) }
        switch sig {
        case SIGSEGV, SIGBUS:
            // SEGV_ACCERR (2) is a protection failure (e.g. the stack guard page); else unmapped.
            let protection = siCode == 2
            let kern = protection ? "KERN_PROTECTION_FAILURE" : "KERN_INVALID_ADDRESS"
            return ("EXC_BAD_ACCESS", sig == SIGSEGV ? "SIGSEGV" : "SIGBUS",
                    sig == SIGSEGV ? "Segmentation fault: 11" : "Bus error: 10",
                    "\(hex(protection ? 2 : 1)), \(hex(address))", "\(kern) at \(hex(address))")
        case SIGTRAP:
            return ("EXC_BREAKPOINT", "SIGTRAP", "Trace/BPT trap: 5", "\(hex(1)), \(hex(pc))", nil)
        case SIGILL:
            return ("EXC_BAD_INSTRUCTION", "SIGILL", "Illegal instruction: 4", "\(hex(1)), \(hex(0))", nil)
        case SIGFPE:
            return ("EXC_ARITHMETIC", "SIGFPE", "Floating point exception: 8", "\(hex(1)), \(hex(0))", nil)
        default:
            return ("EXC_CRASH", "SIGABRT", "Abort trap: 6", "\(hex(0)), \(hex(0))", nil)
        }
    }

    private static func format(_ date: Date, fraction: Int) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.\(String(repeating: "S", count: fraction)) Z"
        return f.string(from: date)
    }

    private static func osTrain() -> String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        #if os(iOS)
        return "iPhone OS \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
        #else
        return "macOS \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
        #endif
    }

    private static func modelCode() -> String {
        ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? sysctlString("hw.machine")
    }

    private static func sysctlString(_ name: String) -> String {
        var size = 0
        sysctlbyname(name, nil, &size, nil, 0)
        var buffer = [CChar](repeating: 0, count: max(size, 1))
        sysctlbyname(name, &buffer, &size, nil, 0)
        return String(cString: buffer)
    }

    #if os(iOS)
    private static let platform = 2
    private static let isEmbedded = true
    #else
    private static let platform = 1
    private static let isEmbedded = false
    #endif

    #if arch(arm64)
    private static let cpuType = "ARM-64"
    #else
    private static let cpuType = "X86-64"
    #endif
}
