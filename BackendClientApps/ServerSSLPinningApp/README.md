# Server SSL Pinning App (Swift)

iOS client for the local Spring Boot `server-ssl-pinning` service
(`com.ashi.sslserverPinning`, HTTPS on port `8443`).

This sample adds:

- An `APIClient` for JSON GET/POST calls.
- SSL certificate pinning via `URLSessionDelegate` (SHA-256 of the DER cert).
- SwiftUI screen to call the two pinning endpoints.

## Key Files

- `ServerSSLPinningApp/APIClient.swift`
- `ServerSSLPinningApp/SSLPinning.swift`
- `ServerSSLPinningApp/PinnedAPIDemoService.swift`
- `ServerSSLPinningApp/ContentView.swift`
- `ServerSSLPinningApp/server-cert.cer` (DER of the server certificate)

## Backend Endpoints

- `GET  /api/pinning/server-pin` → `{ pin, sha256Hex, note }`
- `POST /api/pinning/validate`   body `{ "pin": "sha256/..." }`
  → `{ matched, providedPin, expectedPin, message }`

## Setup

1. The server certificate is already bundled as `server-cert.cer`
   (DER export of `server-cert.pem`).
2. Start the backend:
   ```bash
   cd /Users/ashisha2/Desktop/backend-learning/server-ssl-pinning
   mvn spring-boot:run
   ```
3. Run this app and tap **Get Server Pin**, then **Validate Pin**.
4. On a physical iPhone, replace `localhost` with your Mac's LAN IP
   (the certificate `CN` is `localhost`, so a matching hostname/cert is needed).

## Run

Use Xcode (`Run`) and tap **Validate API** on the app screen.

Optional CLI build command:

```zsh
xcodebuild build \
  -project ServerSSLPinningApp.xcodeproj \
  -scheme ServerSSLPinningApp
```

