import Foundation

protocol CrashRepository {
    func fetchReports() -> [CrashReport]
    func delete(_ report: CrashReport)
    func deleteAll()
}

protocol CrashGenerator {
    func generate(_ type: CrashType)
}
