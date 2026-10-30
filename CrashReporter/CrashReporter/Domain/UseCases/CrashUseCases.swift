import Foundation

struct FetchCrashReportsUseCase {
    let repository: CrashRepository
    func execute() -> [CrashReport] {
        repository.fetchReports().sorted { $0.date > $1.date }
    }
}

struct DeleteCrashReportsUseCase {
    let repository: CrashRepository
    func execute(_ report: CrashReport) { repository.delete(report) }
    func executeAll() { repository.deleteAll() }
}

struct GenerateCrashUseCase {
    let generator: CrashGenerator
    func execute(_ type: CrashType) { generator.generate(type) }
}
