//
//  PlistUserDataSource.swift
//  ArchLearning
//
//  Example of swapping the remote data source for something else entirely,
//  e.g. bundled seed/demo data from a .plist file instead of a live network
//  call. Conforms to the exact same RemoteUserDataSource protocol used by
//  RemoteUserAPIDataSource, so it can be injected into UserRepository or
//  the MVVM-only service with zero changes to any other layer:
//
//      let repository = UserRepository(remote: PlistUserDataSource(), local: ...)
//
//  This is the extension point referenced for "tomorrow we inject data
//  from a .plist or some other means".
//

import Foundation

struct PlistUserDataSource: RemoteUserDataSource {
    let plistURL: URL?

    init(bundle: Bundle = .main, resourceName: String = "sample_users") {
        self.plistURL = bundle.url(forResource: resourceName, withExtension: "plist")
    }

    init(plistURL: URL?) {
        self.plistURL = plistURL
    }

    func fetchUsers() async throws -> [UserEntity] {
        guard let plistURL, let data = try? Data(contentsOf: plistURL) else {
            return []
        }
        let decoder = PropertyListDecoder()
        let dtos = try decoder.decode([UserDTO].self, from: data)
        return dtos.map { $0.toEntity() }
    }
}
