import Foundation

protocol BaseURLProviding {
    var baseURL: String { get }
    func update(baseURL: String)
}

final class BaseURLStore: BaseURLProviding {
    private(set) var baseURL: String
   // Get MAC IP Command: ipconfig getifaddr en0
    init(baseURL: String = "http://<MAC.IP>:8080/") {
        self.baseURL = baseURL
    }

    func update(baseURL: String) {
        self.baseURL = baseURL
    }
}
