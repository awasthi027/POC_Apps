//
//  ContentView.swift
//  SimulateiOSDeviceLocation
//
//  Created by Ashish Awasthi on 08/06/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var reverseGeocoder = ReverseGeocoder()

    var hasLocation: Bool {
        locationManager.latitude != 0.0 || locationManager.longitude != 0.0
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Device Location")
                .font(.largeTitle)
                .bold()

            if hasLocation {
                VStack(spacing: 12) {
                    HStack {
                        Text("Latitude:")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(String(format: "%.6f°", locationManager.latitude))
                            .foregroundColor(.blue)
                    }
                    HStack {
                        Text("Longitude:")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(String(format: "%.6f°", locationManager.longitude))
                            .foregroundColor(.blue)
                    }
                    Divider()
                    HStack {
                        Text("Place:")
                            .fontWeight(.semibold)
                        Spacer()
                        if reverseGeocoder.placeName.isEmpty {
                            ProgressView()
                        } else {
                            Text(reverseGeocoder.placeName)
                                .foregroundColor(.green)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            } else {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Waiting for location…")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .onChange(of: locationManager.latitude) { _, _ in
            reverseGeocoder.fetchPlaceName(
                latitude: locationManager.latitude,
                longitude: locationManager.longitude
            )
        }
        .onChange(of: locationManager.longitude) { _, _ in
            reverseGeocoder.fetchPlaceName(
                latitude: locationManager.latitude,
                longitude: locationManager.longitude
            )
        }
    }
}

#Preview {
    ContentView()
}
