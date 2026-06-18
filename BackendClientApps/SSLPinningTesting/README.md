# SSLPinningTesting

Sample iOS app for validating the backend at `/Users/ashisha2/Desktop/backend-learning/ssl-pinning-service`.

## What the app does

The SwiftUI sample validates three things:

1. A pinned iOS HTTPS call to `GET /api/secure/ping`
2. A backend self-check for the correct pin with `POST /api/client/verify`
3. A backend self-check for the wrong pin with `POST /api/client/verify?pin=...`

The app pins the backend's current leaf certificate using the bundled file `SSLPinningTesting/localhost.pem`.

## Backend expected by the app

Default base URL:

```text
https://localhost:8443
```

The current bundled certificate was exported from:

```text
/Users/ashisha2/Desktop/backend-learning/ssl-pinning-service/certs/server.p12
```

## Run the backend

```bash
cd "/Users/ashisha2/Desktop/backend-learning/ssl-pinning-service"
mvn -DskipTests clean package
java -jar target/ssl-pinning-service-1.0.0.jar
```

## Run the iOS sample

Open `SSLPinningTesting.xcodeproj` and run the `SSLPinningTesting` scheme in the iOS Simulator.

The default `https://localhost:8443` target is intended for the simulator while the Spring Boot service runs on the same Mac.

## If the backend certificate changes

Re-export the PEM and replace `SSLPinningTesting/localhost.pem`:

```bash
openssl pkcs12 \
  -in "/Users/ashisha2/Desktop/backend-learning/ssl-pinning-service/certs/server.p12" \
  -clcerts -nokeys \
  -passin pass:changeit \
  | sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p'
```

## Notes

- This sample performs certificate pinning for the iOS client.
- The backend's `verify` endpoint demonstrates public-key pin validation on the server side.
- Because the backend uses a self-signed certificate, the sample intentionally validates by pin match instead of normal CA trust.

