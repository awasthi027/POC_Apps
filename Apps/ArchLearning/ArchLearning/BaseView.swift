//
//  BaseView.swift
//  ArchLearning
//
//  App entry list screen. Presents the two architecture demos as
//  navigable list items; each pushes its own screen built with its own
//  composition root (see ArchitectureOption below).
//

import SwiftUI
import SwiftData

enum ArchitectureOption: String, CaseIterable, Identifiable {
    case cleanMVVM
    case mvvmOnly
    case cleanMVVMWithPlist
    case mvpOnly
    case cleanMVP

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cleanMVVM: return "Clean Architecture + MVVM"
        case .mvvmOnly: return "MVVM Only"
        case .cleanMVVMWithPlist: return "Clean + MVVM (Plist Source)"
        case .mvpOnly: return "MVP Only"
        case .cleanMVP: return "Clean Architecture + MVP"
        }
    }

    var subtitle: String {
        switch self {
        case .cleanMVVM:
            return "Repository + UseCase layer between the view model and data sources"
        case .mvvmOnly:
            return "View model talks to networking + SwiftData directly"
        case .cleanMVVMWithPlist:
            return "Same screen, remote data source swapped for PlistUserDataSource"
        case .mvpOnly:
            return "Presenter pushes state to a passive view, talks to networking + SwiftData directly"
        case .cleanMVP:
            return "Same Repository + UseCase layer as Clean + MVVM, driven by a Presenter instead"
        }
    }

    var icon: String {
        switch self {
        case .cleanMVVM: return "square.stack.3d.up"
        case .mvvmOnly: return "rectangle.stack"
        case .cleanMVVMWithPlist: return "doc.text"
        case .mvpOnly: return "arrow.triangle.branch"
        case .cleanMVP: return "square.stack.3d.up.badge.a"
        }
    }
}

struct BaseView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            List(ArchitectureOption.allCases) { option in
                NavigationLink(value: option) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(option.title, systemImage: option.icon)
                            .font(.headline)
                        Text(option.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Architecture Demos")
            .navigationDestination(for: ArchitectureOption.self) { option in
                destination(for: option)
            }
        }
    }

    @ViewBuilder
    private func destination(for option: ArchitectureOption) -> some View {
        switch option {
        case .cleanMVVM:
            CleanUserListView(viewModel: makeCleanViewModel(remote: RemoteUserAPIDataSource()))
        case .mvvmOnly:
            MVVMUserListView(viewModel: MVVMUserListViewModel(modelContext: modelContext))
        case .cleanMVVMWithPlist:
            CleanUserListView(viewModel: makeCleanViewModel(remote: PlistUserDataSource()))
        case .mvpOnly:
            MVPUserListView(presenter: MVPUserListPresenter(modelContext: modelContext))
        case .cleanMVP:
            CleanMVPUserListView(presenter: makeCleanPresenter(remote: RemoteUserAPIDataSource()))
        }
    }

    /// Composition root for the Clean Architecture + MVVM screen. The only
    /// thing that changes between the "live API" and "plist" demo items is
    /// which `RemoteUserDataSource` implementation is passed in here —
    /// `UserRepository`, `FetchUsersUseCase`, and `CleanUserListViewModel`
    /// are reused as-is, proving the data source is a true drop-in swap.
    private func makeCleanViewModel(remote: RemoteUserDataSource) -> CleanUserListViewModel {
        let localDataSource = SwiftDataUserDataSource(modelContainer: modelContext.container)
        let repository = UserRepository(
            remote: remote,
            local: localDataSource
        )
        let useCase = FetchUsersUseCase(repository: repository)
        return CleanUserListViewModel(fetchUsersUseCase: useCase)
    }

    /// Composition root for the Clean Architecture + MVP screen. Builds the
    /// exact same Repository + UseCase stack as `makeCleanViewModel`,
    /// proving the Domain/Data layers are fully reusable regardless of
    /// whether Presentation is shaped as MVVM or MVP.
    private func makeCleanPresenter(remote: RemoteUserDataSource) -> CleanUserListPresenter {
        let localDataSource = SwiftDataUserDataSource(modelContainer: modelContext.container)
        let repository = UserRepository(
            remote: remote,
            local: localDataSource
        )
        let useCase = FetchUsersUseCase(repository: repository)
        return CleanUserListPresenter(fetchUsersUseCase: useCase)
    }
}

#Preview {
    BaseView()
        .modelContainer(for: UserRecord.self, inMemory: true)
}
