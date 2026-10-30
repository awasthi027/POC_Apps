import Foundation
import Combine

@MainActor
final class CrashListViewModel: ObservableObject {
    @Published private(set) var reports: [CrashReport] = []

    private let fetch: FetchCrashReportsUseCase
    private let delete: DeleteCrashReportsUseCase
    private let generate: GenerateCrashUseCase

    init(fetch: FetchCrashReportsUseCase,
         delete: DeleteCrashReportsUseCase,
         generate: GenerateCrashUseCase) {
        self.fetch = fetch
        self.delete = delete
        self.generate = generate
    }

    func load() { reports = fetch.execute() }

    func crash(_ type: CrashType) { generate.execute(type) }

    func remove(at offsets: IndexSet) {
        offsets.map { reports[$0] }.forEach(delete.execute)
        load()
    }

    func clearAll() {
        delete.executeAll()
        load()
    }
}
