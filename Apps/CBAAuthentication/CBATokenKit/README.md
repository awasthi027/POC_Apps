# CBATokenKit — CryptoTokenKit token extension

This extension is **required** for Safari / ASWebAuthenticationSession to use the client
certificate in an mTLS challenge. It publishes the public certificate + a key handle into
the system keychain and performs the private-key signature during the TLS handshake.

## Public vs private — what is actually stored
- **Public certificate** → published (`TKTokenKeychainCertificate`), readable by any app.
- **Private key** → NOT stored in the keychain. The p12 is passed from the host app via the
  token configuration's `configurationData`; the extension holds the `SecKey` and signs on
  demand in `TokenSession`. The published `TKTokenKeychainKey` is only a public-key handle.

## Files
| File | Role |
|---|---|
| `TokenDriver.swift` | Principal class; creates the token for a configuration. |
| `Token.swift` | Loads the p12 from `configurationData`, publishes cert + key handle. |
| `TokenSession.swift` | Performs the actual signature (why the extension is mandatory). |
| `Info.plist` | Declares the CTK extension point, class-id and driver-class. |

## Re-create the target in Xcode
1. **File ▸ New ▸ Target… ▸ Persistent Token Extension** (CryptoTokenKit). Name it `CBATokenKit`.
2. Delete the auto-generated sources and add these four files to the `CBATokenKit` target.
3. In the target's **Info.plist**, keep:
   - `NSExtensionPointIdentifier` = `com.apple.ctk-tokens`
   - `NSExtensionAttributes.com.apple.ctk.class-id` = `ashi.com.newLearning.CBAAuthentication.CBATokenKit`
   - `NSExtensionAttributes.com.apple.ctk.driver-class` = `$(PRODUCT_MODULE_NAME).TokenDriver`
4. Ensure the app target **embeds** `CBATokenKit` (General ▸ Frameworks, Libraries, and
   Embedded Content / PlugIns).
5. Sign the app **and** the extension with the same team (`S2ZMFGQM93`).

No keychain-sharing entitlement or app group is needed — the p12 travels through
`configurationData`, not a shared keychain.

## Test (real device only — ctkd does not load token extensions in the Simulator)
1. Build & install, launch the app.
2. Tap **Publish Cert to CTK**. Console should show `CBAToken: published cert + key handle…`.
   If you see `configurationData missing/invalid`, the p12 didn't reach the extension.
3. Reboot once if the token doesn't appear (ctkd caches token extensions).
4. Open `https://client.badssl.com/` in **Safari** → the OS should offer the badssl client
   certificate in its picker → selecting it completes mTLS (signature produced by
   `TokenSession`).

