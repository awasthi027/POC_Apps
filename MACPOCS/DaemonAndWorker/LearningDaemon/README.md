# LearningDaemon — a real launchd daemon, minimal on purpose

## The problem this solves

Say you have work that:

- needs to happen even when no app window is open,
- should be **shared** across multiple client processes instead of each one
  duplicating the logic,
- shouldn't die just because one caller crashed or quit,
- and shouldn't have to be relaunched by hand every time it falls over.

A daemon is the OS-level answer: one long-lived, UI-less process, supervised
by **launchd**, that clients connect to over IPC instead of each doing the
work themselves.

This demo makes that concrete with the smallest possible daemon: it just
counts "jobs" submitted by whichever client (worker) calls it, and answers
pings with its pid/uptime. The interesting part isn't the job logic — it's
watching launchd keep the thing alive.

## Architecture

```
DaemonAndWorker.app (client / "worker")      LearningDaemon (daemon)
──────────────────────────────────────       ─────────────────────────────
ContentView                                   RunLoop.main.run() — blocks
  │ tap "Ping" / "Submit Job"                 forever, this IS the daemon
  ▼                                            being a daemon
LearningDaemonClient
  NSXPCConnection(machServiceName:) ────────▶  NSXPCListener(machServiceName:)
  │                                             │
  ▼                                             ▼
remoteObjectProxy.ping / .submitJob ───────▶  LearningDaemonService
                                                 (one shared instance —
completion(pid, uptime, jobCount) ◀─────────    state is shared across
                                                 every connected client)
```

Both sides agree on one `@objc` contract (`LearningDaemonProtocol.swift`) —
there's no shared memory across the process boundary, so everything is
serialized through that interface, same as the sibling XPC demo in
`MacOSConcepts/`.

## Daemon vs. the sibling XPC Service demo

| | `ImageParserService` (XPC Service) | `LearningDaemon` (this demo) |
|---|---|---|
| Started by | launchd, lazily, on first connection | launchd, at load time (`RunAtLoad`) |
| Idles out when unused? | Yes — that's normal for an XPC Service | No — `KeepAlive` keeps it resident |
| Survives being killed? | launchd relaunches it lazily on next connect | launchd relaunches it immediately (`KeepAlive`) |
| Registered as | embedded `.xpc` bundle inside the app | a plain executable + a LaunchAgent plist |
| Talks to | one app at a time, effectively | any number of independent client processes |

Both use `NSXPCConnection`/`NSXPCListener` — the daemon/service distinction
is really about **how launchd is told to manage the process** (the plist),
not the IPC mechanism.

## Files

| File | Role |
|---|---|
| [`LearningDaemonProtocol.swift`](LearningDaemonProtocol.swift) | Shared contract. Duplicated (byte-for-byte) into `DaemonAndWorker/DaemonAndWorker/` so the app target sees the same interface. |
| [`main.swift`](main.swift) | The daemon: `NSXPCListener(machServiceName:)` + `RunLoop.main.run()`, plus a `LearningDaemonService` whose state (`jobCount`) is shared across every client connection. |
| [`build.sh`](build.sh) | Compiles the daemon to `.build/LearningDaemon` — no sudo, stays inside this folder. |
| [`ashi.newLearning.LearningDaemon.plist`](ashi.newLearning.LearningDaemon.plist) | The LaunchAgent job description: `RunAtLoad`, `KeepAlive`, the `MachServices` name, log paths. |
| `../DaemonAndWorker/DaemonAndWorker/LearningDaemonClient.swift` | The client wrapper the SwiftUI app uses. |
| `../DaemonAndWorker/DaemonAndWorker/ContentView.swift` | UI: Ping / Submit Job / Crash Daemon buttons + a log view. |

## Running it

This installs a **per-user LaunchAgent** (`~/Library/LaunchAgents`) — no
`sudo`, nothing written outside your home directory, and it's trivially
removable. Run these yourself in Terminal:

```bash
cd /Users/ashisha2/Desktop/DaemonAndWorker/LearningDaemon
./build.sh
```

```bash
mkdir -p ~/Library/LaunchAgents
cp ashi.newLearning.LearningDaemon.plist ~/Library/LaunchAgents/
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/ashi.newLearning.LearningDaemon.plist
```

Check it's up:

```bash
launchctl print gui/$(id -u)/ashi.newLearning.LearningDaemon
tail -f ~/Library/Logs/LearningDaemon.log
```

Then build and run `DaemonAndWorker.app` in Xcode and try, in order:

1. **Ping Daemon** — note the pid and uptime.
2. **Submit Job** a few times as Worker-A, switch the picker to Worker-B and
   submit again — the job counter keeps incrementing across both "workers,"
   proving it's shared daemon-side state, not per-client.
3. Quit and relaunch the app, then **Ping** again — same pid, same job
   count. **The daemon didn't restart or lose state just because the app
   quit** — that's daemon vs. app-lifetime independence.
4. **Crash Daemon**, then **Ping** again a second later — you'll get a
   **different pid** but everything still works. That's `KeepAlive`:
   launchd noticed the process exited and started a fresh one automatically.
   (`jobCount` resets to 0 here, since it only lives in that process's
   memory — a real daemon would persist it to disk/a database if it needed
   to survive restarts too.)

## Uninstalling

```bash
launchctl bootout gui/$(id -u)/ashi.newLearning.LearningDaemon
rm ~/Library/LaunchAgents/ashi.newLearning.LearningDaemon.plist
```

## Extending this

- Persist `jobCount` to a file so it survives a crash-restart, not just the
  app quitting.
- Add a second, independent CLI client (a tiny `swiftc`-compiled script that
  also connects by Mach service name) to see two *non-app* processes sharing
  the same daemon.
- Swap `KeepAlive = true` for `KeepAlive = { SuccessfulExit = false }` and
  compare: that only restarts on a crash, not a clean `exit(0)`.
