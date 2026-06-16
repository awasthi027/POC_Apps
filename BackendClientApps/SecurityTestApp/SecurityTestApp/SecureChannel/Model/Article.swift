import Foundation

struct Article: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let description: String?
    let content: String?

    var detailsText: String {
        let value = description?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? content?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? ""
        return value.isEmpty ? "No description" : value
    }

    init(id: Int, title: String, description: String?, content: String?) {
        self.id = id
        self.title = title
        self.description = description
        self.content = content
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case description
        case content
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let intId = try? container.decode(Int.self, forKey: .id) {
            id = intId
        } else {
            let stringId = try container.decode(String.self, forKey: .id)
            guard let parsedId = Int(stringId) else {
                throw DecodingError.dataCorruptedError(forKey: .id, in: container, debugDescription: "Article id is not numeric")
            }
            id = parsedId
        }

        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        content = try container.decodeIfPresent(String.self, forKey: .content)
    }
}

