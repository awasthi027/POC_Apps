//
//  ReverseGeocoder.swift
//  SimulateiOSDeviceLocation
//
//  Created by Ashish Awasthi on 08/06/26.
//

import Foundation
import CoreLocation
import MapKit
import Combine

@MainActor
class ReverseGeocoder: ObservableObject {

    @Published var placeName: String = ""

    /// Resolves a human-readable place name from the given coordinates.
    func fetchPlaceName(latitude: Double, longitude: Double) {
        Task {
            do {
                let location = CLLocation(latitude: latitude, longitude: longitude)
                guard let request = MKReverseGeocodingRequest(location: location) else {
                    placeName = "Unknown location"
                    return
                }
                let mapItems = try await request.mapItems
                let mapItem = mapItems.first
                if let mapItem {
                    let p = mapItem.placemark
                    let parts: [String?] = [p.name, p.locality, p.administrativeArea]
                    placeName = parts.compactMap { $0 }.joined(separator: ", ")
                } else {
                    placeName = "Unknown location"
                }
            } catch {
                placeName = "Could not resolve place: \(error.localizedDescription)"
            }
        }
    }
}
