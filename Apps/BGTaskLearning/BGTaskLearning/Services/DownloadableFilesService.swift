import Foundation

struct DownloadableFile {
    let id: String
    let name: String
    let url: String
    let fileSize: Int64
    
    init(name: String, url: String, fileSize: Int64) {
        self.id = UUID().uuidString
        self.name = name
        self.url = url
        self.fileSize = fileSize
    }
}

final class DownloadableFilesService {
    static let shared = DownloadableFilesService()
    
    let files: [DownloadableFile] = [
        DownloadableFile(
            name: "Test File (10MB)",
            url: "https://proof.ovh.net/files/10Mb.dat",
            fileSize: 1024 * 1024 * 10
        ),
        DownloadableFile(
            name: "Video File (21MB)",
            url: "https://download.samplelib.com/mp4/sample-30s.mp4",
            fileSize: 1024 * 1024 * 21
        ),
        DownloadableFile(
            name: "Large Test File (100MB)",
            url: "https://proof.ovh.net/files/100Mb.dat",
            fileSize: 1024 * 1024 * 100
        ),
    ]
    
    private init() {}
    
    func getFile(by id: String) -> DownloadableFile? {
        return files.first { $0.id == id }
    }
    
    func getAllFiles() -> [DownloadableFile] {
        return files
    }
}
