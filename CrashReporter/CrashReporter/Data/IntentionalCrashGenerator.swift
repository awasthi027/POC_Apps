import Foundation

struct IntentionalCrashGenerator: CrashGenerator {
    func generate(_ type: CrashType) {
        // Runtime values prevent the compiler from rejecting/optimizing the crash away.
        let n = Int(ProcessInfo.processInfo.environment["NONEXISTENT_VAR"] ?? "0") ?? 0
        switch type {
        case .forceUnwrap:8
            let value: String? = n == 0 ? nil : "x"
            print(value!)
        case .arrayOutOfBounds:
            let array = [1, 2, 3]
            print(array[n + 10])
        case .divideByZero:
            print(10 / n)
        case .fatalError:
            fatalError("Intentional fatal error")
        case .uncaughtException:
            NSException(name: .genericException, reason: "Intentional NSException",
                        userInfo: nil).raise()
        case .stackOverflow:
            print(overflow(n))
        }
    }

    @inline(never)
    private func overflow(_ depth: Int) -> Int {
        // The never-true-in-practice side effect stops the optimizer turning this into a loop.
        if depth % 1_000_000 == -1 { print(depth) }
        return depth &+ overflow(depth &+ 1) &* 3
    }
}
