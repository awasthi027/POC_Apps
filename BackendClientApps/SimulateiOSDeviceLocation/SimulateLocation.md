# How to Simulate iOS Device Location

Simulating location on an iOS device or simulator is useful for testing location-based features without physically moving. Here are all the available methods.

---

## ✅ Method 1: iOS Simulator — Built-in Presets (Easiest)

1. **Run** your app on the **iOS Simulator** from Xcode.
2. In the macOS menu bar, go to:
   ```
   Features → Location
   ```
3. Choose one of the built-in presets:

| Preset              | Description                        |
|---------------------|------------------------------------|
| None                | No location provided               |
| Custom Location...  | Enter any latitude/longitude       |
| Apple               | Apple HQ, Cupertino, CA            |
| City Bicycle Ride   | Moving simulation through a city   |
| City Run            | Running pace simulation            |
| Freeway Drive       | Highway speed simulation           |

> 💡 **Custom Location** lets you enter any lat/lon, e.g., `28.6139, 77.2090` for New Delhi.

---

## ✅ Method 2: Set Default Location via Edit Scheme (GPX)

Use a `.gpx` file to simulate a fixed or moving location every time you run the app.

### Step-by-step:

1. In Xcode, go to:
   ```
   Product → Scheme → Edit Scheme...  (⌘<)
   ```
2. Select **Run** in the left sidebar.
3. Click the **Options** tab.
4. Under **Core Location**, set **Default Location** to a GPX file.

### Single Point GPX:

```xml
<?xml version="1.0"?>
<gpx version="1.1" creator="Xcode">
  <wpt lat="28.6139" lon="77.2090">
    <name>New Delhi, India</name>
  </wpt>
</gpx>
```

### Moving Route GPX (multiple waypoints):

```xml
<?xml version="1.0"?>
<gpx version="1.1" creator="Xcode">
  <trk>
    <name>Sample Route</name>
    <trkseg>
      <trkpt lat="37.3318" lon="-122.0312"><time>2026-06-08T10:00:00Z</time></trkpt>
      <trkpt lat="37.3325" lon="-122.0320"><time>2026-06-08T10:00:05Z</time></trkpt>
      <trkpt lat="37.3330" lon="-122.0330"><time>2026-06-08T10:00:10Z</time></trkpt>
    </trkseg>
  </trk>
</gpx>
```

> 📁 A sample `SampleLocation.gpx` file is included in the project for easy testing.

---

## ✅ Method 3: Simulate Location on a Physical Device (via Xcode Debug Bar)

1. **Connect** your iPhone to your Mac via USB.
2. **Run** the app from Xcode on your physical device.
3. In the **Debug bar** at the bottom of the Xcode window, click the **📍 location arrow** icon.
4. Select **Custom Location...** and enter your desired lat/lon.

> ⚠️ This only works **while the app is actively running** through Xcode.

---

## ✅ Method 4: Simulate Location Using the Debug Bar (Simulator)

While the simulator is running your app:

1. Look at the **Xcode Debug toolbar** at the bottom.
2. Click the **location arrow (▷ with dot)** icon.
3. Choose a preset or enter custom coordinates.

---

## ✅ Method 5: Simulate via iOS Simulator Menu at Runtime

While your app is running in the simulator:

1. Go to **Simulator app** in the Dock.
2. From the menu bar: `Features → Location`.
3. Change the location — your `CLLocationManager` will receive the update **live**.

---

## ✅ Method 6: Mock in Code (Unit Testing / UI Testing)

For automated tests, inject a mock location rather than relying on real hardware.

```swift
class MockLocationManager: CLLocationManager {
    override var location: CLLocation? {
        return CLLocation(latitude: 48.8566, longitude: 2.3522) // Paris
    }
}
```

Use **dependency injection** to swap in `MockLocationManager` during test targets.

---

## 📍 Required Info.plist Key

Your app **must** have this key in `Info.plist`, otherwise `CLLocationManager` will silently fail:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app displays your current location name on the map.</string>
```

To add it in Xcode:
1. Select your project in the Navigator.
2. Select the **target** → **Info** tab.
3. Click `+` and add `Privacy - Location When In Use Usage Description`.
4. Set the value to a user-friendly message.

---

## 🌍 Quick Reference — Popular Test Coordinates

| City              | Latitude   | Longitude    |
|-------------------|------------|--------------|
| Cupertino, CA     | 37.3318    | -122.0312    |
| New Delhi, India  | 28.6139    | 77.2090      |
| Mumbai, India     | 19.0760    | 72.8777      |
| London, UK        | 51.5074    | -0.1278      |
| Tokyo, Japan      | 35.6762    | 139.6503     |
| Paris, France     | 48.8566    | 2.3522       |
| Sydney, Australia | -33.8688   | 151.2093     |
| New York, USA     | 40.7128    | -74.0060     |
| Dubai, UAE        | 25.2048    | 55.2708      |

---

## 📝 Notes

- The **Simulator does not have GPS hardware** — all location data must be simulated.
- On a **real device**, `requestWhenInUseAuthorization()` must be called and the user must accept the permission prompt.
- `CLGeocoder.reverseGeocodeLocation()` requires an **active internet connection** to resolve place names.
- The `distanceFilter` on `CLLocationManager` controls how many meters of movement trigger a location update (set to `10` meters in this app).
