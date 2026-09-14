# APNS Notification Handling Instructions

## 🎯 CRITICAL: Background Mode Configuration

### ⭐ To Persist Notifications When App is QUIT/TERMINATED

You MUST enable:

1. **Background Modes in Capabilities**
   - ✅ `remote-notification` (Wake app from background/quit)
   - ✅ `fetch` (Background fetch for processing)

2. **Batch Processing Remote Notifications**
   - Add to Info.plist OR enable in Capabilities
   - Allows app to wake up and process notifications

### When Properly Configured:
```
Notification sent (with content-available: 1)
        ↓
App is quit/terminated
        ↓
didReceiveRemoteNotification() is called
        ↓
App wakes up (~30 seconds)
        ↓
Store data in CoreData
        ↓
Call completionHandler(.newData)
        ↓
App goes back to sleep
        ↓
Next app open → Data persisted ✅
```

---

## ⚙️ REQUIRED Configuration

### 1️⃣ Info.plist Setup (MUST HAVE)
```xml
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
    <string>fetch</string>
</array>
```

### 2️⃣ Xcode Capabilities Configuration
```
Project Settings
  ↓
Target: YourApp
  ↓
Signing & Capabilities
  ↓
+ Capability
  ↓
Background Modes
  ↓
✅ Remote notifications
✅ Background fetch
```

### 3️⃣ .entitlements File
Your `APNSLearning.entitlements` should have:
```xml
<key>aps-environment</key>
<string>development</string>

<key>com.apple.developer.aps-environment</key>
<string>development</string>
```

### 4️⃣ AppDelegate.swift (MUST IMPLEMENT)
```swift
class APNSDelegate: NSObject, UNUserNotificationCenterDelegate, UIApplicationDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Set delegate FIRST
        UNUserNotificationCenter.current().delegate = self
        
        // Register for remote notifications
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
        
        return true
    }
    
    // Handle device token
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        UserDefaults.standard.set(token, forKey: "apnsDeviceToken")
    }
    
    // CRITICAL: This is called when app is quit (with content-available)
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        // Store to CoreData HERE
        Task {
            await storeNotificationIfNeeded(payload: userInfo)
            completionHandler(.newData)  // MUST CALL!
        }
    }
}
```

---

## 📱 Notification Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                   APNS Payload Arrives                       │
│            (with "content-available": 1)                     │
└──────────────────────────┬──────────────────────────────────┘
                           │
            ┌──────────────┴──────────────┐
            │                             │
     ┌──────▼────────┐          ┌────────▼──────┐
     │ App Quit      │          │ App Running   │
     │ (Terminated)  │          │ (Any state)   │
     └──────┬────────┘          └────────┬──────┘
            │                             │
            ▼                             ▼
    Needs: Background          Needs: Background
    Modes enabled               Modes enabled
            │                             │
            ▼                             ▼
    App wakes up              App already running
    (system wakes it)              │
            │                      ▼
            ├─────────────────────→ didReceiveRemoteNotification()
                                   (ALWAYS called)
                                   │
                                   ▼
                            Store in CoreData
                                   │
                                   ▼
                        Call completionHandler(.newData)
                                   │
            App in background?     │
            or quit?               ▼
                 │            App goes to sleep
                 └────────→ OR continues running
                           ✅ Data persisted!
```

---

## 🔔 Three Notification Methods

### 1. `willPresent` - Foreground Only
**When called:**
- App in FOREGROUND
- Regular push (NO `content-available`)
- User can see app

**Code:**
```swift
func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
) {
    let userInfo = notification.request.content.userInfo
    log("✅ Notification received (foreground)")
    completionHandler([.banner, .sound, .badge])
}
```

---

### 2. `didReceive Response` - User Tap Only
**When called:**
- User TAPS notification
- Works in any app state

**Code:**
```swift
func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
) {
    let userInfo = response.notification.request.content.userInfo
    log("✅ Notification tapped")
    completionHandler()
}
```

---

### 3. `didReceiveRemoteNotification` - Silent Push ⭐ MAIN METHOD
**When called:**
- ✅ Payload has `"content-available": 1`
- ✅ ANY app state (quit/background/foreground) in App quit mode when user launch the method will call.
- ✅ **REQUIRES Background Modes enabled**

**Code:**
```swift
func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
) {
    log("✅ Silent notification (background)")
    Task {
        // STORE DATA HERE - This is the purpose!
        await storeNotificationIfNeeded(payload: userInfo)
        completionHandler(.newData)  // CRITICAL: Call this!
    }
}
```

---

## 📊 Comparison Table

| Method | Called When | App State | Stores Data | Requires Background Modes |
|--------|-------------|-----------|-------------|--------------------------|
| `willPresent` | Regular push arrives | Foreground only | ❌ No | ❌ No |
| `didReceive Response` | User taps | ANY | ✅ Optional | ❌ No |
| `didReceiveRemoteNotification` | `content-available: 1` | **ANY** 🔥 | ✅ **YES** | ✅ **YES** |

---

## 🎯 Real-World Scenarios

### Scenario 1: Background Fetch (App Quit)
**App State:** Terminated/Quit  
**Payload:**
```json
{
  "aps": {
    "content-available": 1
  },
  "sync": "email",
  "count": 5
}
```
**What Happens:**
1. Notification arrives
2. ✅ Background Modes enabled
3. System wakes app (~30 seconds)
4. `didReceiveRemoteNotification()` called
5. Stores email count in CoreData
6. Calls `completionHandler(.newData)`
7. App goes back to sleep
8. Next time user opens app → sees new data ✅

---

### Scenario 2: Chat Message (App Quit)
**App State:** Terminated  
**Payload:**
```json
{
  "aps": {
    "content-available": 1,
    "alert": {
      "title": "John",
      "body": "Hey!"
    },
    "sound": "default",
    "badge": 1
  }
}
```
**What Happens:**
1. Notification arrives
2. `didReceiveRemoteNotification()` called (due to background modes)
3. Stores message in CoreData
4. Also shows notification in center
5. User taps → `didReceive Response()` called
6. ✅ Data already in CoreData
7. Navigate to chat

---

### Scenario 3: Sync Without Notification (Silent)
**App State:** Quit  
**Payload:**
```json
{
  "aps": {
    "content-available": 1
  },
  "new_data": "important"
}
```
**What Happens:**
1. ❌ NO notification shown (no alert)
2. `didReceiveRemoteNotification()` called
3. Stores data
4. ✅ User never sees notification
5. Data is there when app opens

---

## 🚨 Critical Checklist

### Without Background Modes ❌
```
App Quit + "content-available": 1
        ↓
App does NOT wake up
        ↓
didReceiveRemoteNotification() NOT called
        ↓
❌ Data NOT stored
        ↓
Notification NOT delivered
```

### With Background Modes ✅
```
App Quit + "content-available": 1
        ↓
✅ App wakes up (system does this)
        ↓
✅ didReceiveRemoteNotification() called
        ↓
✅ Data stored in CoreData
        ↓
✅ Notification delivered
```

---

## 🧪 Testing

### ⚠️ SIMULATOR LIMITATION: Background Notifications NOT Supported

**The iOS Simulator CANNOT test background notifications.** It does not support:
- ❌ Waking a quit app with a push notification
- ❌ Calling `didReceiveRemoteNotification()` when app is terminated
- ❌ Full APNS infrastructure

**To test background notifications, you MUST use a real device.**

---

### Testing in Simulator (Foreground Only)

#### Step 1: Create JSON File

Create a file named `test_notification.json`:

```json
{
    "Simulator Target Bundle": "ashi.com.newLearning.CBAAuthentication",
    "aps": {
        "alert": {
            "title": "Test Notification",
            "body": "This is a test"
        },
        "badge": 1,
        "sound": "default"
    },
    "data": "test_data"
}
```

#### Step 2: Run App in Simulator

```bash
# Run your app in Xcode simulator
```

#### Step 3: Send Notification from Terminal

```bash
# List all simulators
xcrun simctl list devices available

# Send notification (replace SIMULATOR_ID with your simulator ID)
xcrun simctl push SIMULATOR_ID ashi.com.newLearning.CBAAuthentication test_notification.json
```

#### Step 4: Verify in Console

Check Xcode Console output:
```
✅ Notification received (foreground): {...}
🔢 Badge count: 1
```

#### ⚠️ Limitations:
- ❌ Only works when **app is running (foreground)**
- ❌ Does NOT test background/quit scenarios
- ❌ Does NOT call `didReceiveRemoteNotification()`
- ❌ Does NOT persist data to CoreData

---

### Testing Background Notifications (Real Device Only) ⭐ REQUIRED

**For true background notification testing, you MUST use a real iPhone:**

#### Step 1: Get Device Token
```
1. Run app on real device
2. Check Xcode Console for: "🎯 APNS Device Token: abc123..."
3. Copy the token
```

#### Step 2: Send Notification via Third-Party Tools
- Pusher (pusher.app) - Mac app
- Push Notifications Tester (web-based)
- Simply Push (Mac app)

**Steps:**
1. Upload APNS certificate from Apple Developer Portal
2. Enter device token
3. Create payload with `"content-available": 1`
4. Send notification
5. Verify data persisted in CoreData

---

## 📋 Payload Examples

### ✅ Correct: Silent Push (Will Store)
```json
{
  "aps": {
    "content-available": 1
  }
}
```
→ `didReceiveRemoteNotification()` called ✅

---

### ✅ Correct: Silent + Visible
```json
{
  "aps": {
    "content-available": 1,
    "alert": {
      "title": "New",
      "body": "Content"
    },
    "sound": "default",
    "badge": 1
  }
}
```
→ Both methods called ✅

---

### ❌ Wrong: Missing content-available
```json
{
  "aps": {
    "alert": {
      "title": "New",
      "body": "Content"
    }
  }
}
```
→ App must be foreground for `willPresent()`
→ If app quit, notification lost ❌

---

## 🎯 Key Methods Explained

### willPresent - Called when Notification Arrives (App Foreground)
- ✅ App is RUNNING and user can see it
- ✅ Payload does NOT contain `"content-available": 1`
- ✅ Regular notification with alert/sound/badge
- ❌ NOT called when app is background or quit
- **Purpose:** Display notification banner to user while app is active

### didReceive Response - Called when User Taps Notification
- ✅ User ACTIVELY TAPS the notification
- ✅ Works in ANY app state (foreground/background/quit)
- ❌ NOT called if notification is dismissed automatically
- **Purpose:** Handle user interaction and navigate to relevant content

### didReceiveRemoteNotification - Called for Silent Push (App Any State) ⭐
- ✅ Payload contains `"content-available": 1`
- ✅ **CALLED REGARDLESS of app state:**
  - App terminated/quit ✅
  - App in background ✅
  - App in foreground ✅
- ✅ **REQUIRES Background Modes enabled in Info.plist**
- ✅ Gets ~30 seconds to process and save data
- **Purpose:** Wake app and persist data in background

---

## 📚 Summary

### To Persist Notifications When App is Quit:

1. ✅ Add Background Modes to Info.plist
   - `remote-notification`
   - `fetch`

2. ✅ Enable in Xcode Capabilities
   - Project → Target → Signing & Capabilities
   - Add Background Modes capability
   - Check both options

3. ✅ Include in payload
   - `"content-available": 1`

4. ✅ Implement `didReceiveRemoteNotification()`
   - Store data in CoreData
   - Call `completionHandler(.newData)`

5. ✅ Call `registerForRemoteNotifications()`
   - In `didFinishLaunchingWithOptions`

---

## 🔑 Key Points

| Point | Detail |
|-------|--------|
| **Background Modes Required** | Yes, for app-quit notifications |
| **content-available Needed** | Yes, to wake app when quit |
| **Time Limit** | ~30 seconds after notification arrives |
| **Must Call completionHandler** | Yes, always call with `.newData` or `.noData` |
| **Storage Method** | CoreData (runs on MainThread) |
| **Works When App Quit** | ✅ YES (if background modes enabled) |
| **willPresent** | Only foreground, regular push |
| **didReceive Response** | User taps notification |
| **didReceiveRemoteNotification** | Silent push, any app state |

---

**Last Updated:** September 13, 2026  
**Status:** ✅ Complete APNS Configuration Guide  
**Critical Info:** Background Modes + `content-available: 1` + proper implementation = Notifications persist even when app is quit/terminated
