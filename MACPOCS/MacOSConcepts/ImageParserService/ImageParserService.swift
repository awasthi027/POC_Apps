//
//  ImageParserService.swift
//  ImageParserService
//
//  Created by Ashish Awasthi on 27/08/26.
//

import Foundation
import CoreGraphics
import ImageIO

/// Decodes image bytes sent from the host app and replies with pixel
/// dimensions. Runs in its own process — if it crashes, only this process
/// dies, not the host app.
final class ImageParserService: NSObject, ImageParserServiceProtocol {
    // Real corrupt image bytes rarely crash ImageIO — Apple hardens it
    // against exactly that. This marker simulates "the decoder has a bug"
    // so the isolation can be demonstrated without a genuine exploit.
    private static let crashMarker = Data("XPCCRASHDEMO".utf8)

    func parseImage(_ data: Data, withReply reply: @escaping (Int, Int) -> Void) {
        if data.starts(with: Self.crashMarker) {
            let arrayItem: [Int] = [1]
            print("Item: \(arrayItem[1])") // deliberately out of range — kills this process only
        }

        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int
        else {
            reply(0, 0) // (0, 0) signals "couldn't parse"
            return
        }
        reply(width, height)
    }
}
