// Runs Swift Testing tests without SwiftPM, through Swift Testing's documented C entry point
// (swt_abiv0_getEntryPoint). `swift test` does not need this file.
import Foundation
import Testing

private typealias EntryPoint = @convention(thin) @Sendable (
    _ configurationJSON: UnsafeRawBufferPointer?,
    _ recordHandler: @escaping @Sendable (_ recordJSON: UnsafeRawBufferPointer) -> Void
) async throws -> Bool

@_silgen_name("swt_abiv0_getEntryPoint")
private func swt_abiv0_getEntryPoint() -> UnsafeRawPointer

@main
struct Runner {
    static func main() async {
        let entryPoint = unsafeBitCast(swt_abiv0_getEntryPoint(), to: EntryPoint.self)
        let passed = (try? await entryPoint(nil) { buffer in
            guard let record = try? JSONSerialization.jsonObject(with: Data(buffer)) as? [String: Any],
                  record["kind"] as? String == "event",
                  let payload = record["payload"] as? [String: Any],
                  let kind = payload["kind"] as? String else { return }
            let name = (payload["testID"] as? String) ?? ""
            switch kind {
            case "issueRecorded":
                let text = (payload["messages"] as? [[String: Any]])?.compactMap { $0["text"] as? String }.joined(separator: " | ") ?? ""
                print("  FAILED \(name): \(text)")
            default: break
            }
        }) ?? false
        print(passed ? "\nAll tests passed." : "\nSome tests FAILED.")
        exit(passed ? 0 : 1)
    }
}
