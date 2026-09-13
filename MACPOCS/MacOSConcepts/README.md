# XPC (Cross-Process Communication) Demo

A minimal, working example of two macOS processes talking to each other over
XPC, including what happens when one of them crashes.

## Why XPC exists

A single app is one process with one crash domain and one privilege level.
XPC lets you split off a piece of work into its **own OS process** so that:

- a crash in that piece doesn't take the whole app down
- that piece can run with different (often fewer) privileges/entitlements
- untrusted or risky work (parsing files, talking to hardware, elevated
  operations) is isolated from the main app

Real-world examples: Safari renders each tab in a separate process; Share
Sheet / Finder Sync / Photo Editing extensions each run out-of-process;
Contacts/Location/Keychain access from your app is actually an XPC call to a
system daemon under the hood.

## What this demo does

The main app sends raw image bytes to a separate **XPC Service** process,
which decodes them and replies with the pixel dimensions. It also includes a
deliberate crash trigger to prove the isolation: crashing the service does
**not** crash the app.

```
MacOSConcepts.app (process 1)          ImageParserService.xpc (process 2)
─────────────────────────────          ──────────────────────────────────
ContentView                            ImageParserService
  │ pick image, load Data                │
  ▼                                      │
ImageParserClient ──── Data ──────────▶  parseImage(_:withReply:)
  │                                      │ CGImageSourceCreateWithData(...)
  ▼                                      │
completion(width, height) ◀── reply ───  reply(width, height)
```

Both sides agree on one contract — an `@objc` protocol — because XPC has no
shared memory; everything crossing the boundary is serialized.

## File map

| File | Process | Role |
|---|---|---|
| [`ImageParserService/ImageParserServiceProtocol.swift`](ImageParserService/ImageParserServiceProtocol.swift) | both | The shared contract: `parseImage(_:withReply:)`. Compiled into **both** targets (see Target Membership below) so they agree byte-for-byte on the interface. |
| [`ImageParserService/ImageParserService.swift`](ImageParserService/ImageParserService.swift) | service | Real implementation: decodes image bytes with ImageIO, replies with width/height. Also has the simulated crash trigger. |
| [`ImageParserService/main.swift`](ImageParserService/main.swift) | service | Boilerplate that starts `NSXPCListener.service()` — this is what makes the target a long-running service process. |
| [`MacOSConcepts/ImageParserXPC.swift`](MacOSConcepts/ImageParserXPC.swift) | app | `ImageParserClient`: opens the connection, sends the call, handles the reply and crash notification. |
| [`MacOSConcepts/ContentView.swift`](MacOSConcepts/ContentView.swift) | app | UI: pick an image file, show the parsed result or the crash message. |

## The normal flow (communication)

1. User picks an image in `ContentView` → file read into `Data`.
2. App calls `ImageParserClient.parseImage(data, ...)`.
3. `NSXPCConnection(serviceName: "ashi.com.newLearning.ImageParserService")`
   tells `launchd` to start the service process if it isn't already running.
   **This is the actual process boundary** — everything before this line
   just configures the connection.
4. The `Data` is serialized, sent across, and delivered to
   `ImageParserService.parseImage`, running in the other process.
5. The service decodes the image and calls `reply(width, height)`.
6. The reply is serialized back and arrives in the app's completion closure,
   which updates the UI.

## The crash flow (isolation)

1. User picks `crash-test.png` — its bytes start with the marker
   `"XPCCRASHDEMO"`.
2. `ImageParserService.parseImage` detects the marker and deliberately
   indexes out of bounds → **fatal error, service process dies.**
3. Real corrupt image bytes almost never crash ImageIO — Apple hardens it
   against exactly that — so this marker exists purely to make the crash
   reproducible on demand for the demo.
4. The app's `NSXPCConnection.interruptionHandler` fires because the peer
   process disconnected. The app process itself is untouched.
5. `ContentView` shows *"Parser service crashed — app kept running"*.
6. Picking a normal image afterward works again — `launchd` relaunches a
   fresh service process on demand.

## Key XPC concepts, and where to find them in the code

| Concept | Where |
|---|---|
| Shared wire contract (`@objc` protocol) | `ImageParserServiceProtocol.swift` |
| Service-side listener | `ImageParserService/main.swift` (`NSXPCListener.service()`) |
| Client-side connection | `ImageParserXPC.swift` (`NSXPCConnection(serviceName:)`) |
| Async request/reply | `parseImage(_:withReply:)` — reply is a closure, not a return value |
| Crash/disconnect detection | `connection.interruptionHandler` in `ImageParserXPC.swift` |
| Call-level failure (vs. process crash) | `remoteObjectProxyWithErrorHandler` in `ImageParserXPC.swift` |
| Process boundary | The **target boundary** — `ImageParserService` is a separate Xcode target that builds its own executable, embedded via the "Embed XPC Services" build phase |

## One setup detail worth remembering

`ImageParserServiceProtocol.swift` must be a member of **both** targets
(File Inspector → Target Membership → check `MacOSConcepts` in addition to
`ImageParserService`). Without that, the app target can't see the protocol
type, or the two sides could silently disagree on the interface — XPC has no
compiler to catch a mismatch across separately-compiled modules.

## Extending this

- Swap the crash marker for real defensive behavior: catch parse errors
  from untrusted files without a fake trigger.
- Add more methods to the protocol for other isolated work (e.g. a PDF
  parser using PDFKit, following the exact same pattern).
- Try killing the service manually with Activity Monitor while the app is
  running — same `interruptionHandler` fires.
