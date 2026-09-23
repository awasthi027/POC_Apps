//
//  VideoModel.swift
//  PiPLearning
//
//  Created by Ashish Awasthi on 22/09/26.
//

import Foundation

struct VideoModel: Identifiable, Codable {
    let id = UUID()
    let title: String
    let streamingURL: URL
    let thumbnail: String?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case title
        case streamingURL
        case thumbnail
        case description
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(streamingURL.absoluteString, forKey: .streamingURL)
        try container.encode(thumbnail, forKey: .thumbnail)
        try container.encode(description, forKey: .description)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let title = try container.decode(String.self, forKey: .title)
        let urlString = try container.decode(String.self, forKey: .streamingURL)
        let thumbnail = try container.decodeIfPresent(String.self, forKey: .thumbnail)
        let description = try container.decodeIfPresent(String.self, forKey: .description)

        self.init(title: title, streamingURL: URL(string: urlString)!, thumbnail: thumbnail, description: description)
    }

    init(title: String, streamingURL: URL, thumbnail: String? = nil, description: String? = nil) {
        self.title = title
        self.streamingURL = streamingURL
        self.thumbnail = thumbnail
        self.description = description
    }
}
