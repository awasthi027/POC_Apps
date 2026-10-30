# Sample Shop (iOS)

A small SwiftUI shop that uses the `AnalyticsSDK` package and records product, cart, purchase and user events.
Open **SampleShop.xcodeproj** in Xcode 16 or newer (iOS 17+). The project links `../AnalyticsSDK` as a local package.

## Run it with the event service

```bash
cd ../EventService
podman kube play podman/pod.yaml      # Postgres + Kafka
mvn spring-boot:run                   # service on http://localhost:8080
```
Then run **SampleShop** in the iOS Simulator (the Simulator reaches your Mac as `localhost`), browse and buy something,
and open **http://localhost:8080/** to see the events in the chart page.

On a real iPhone, change `AnalyticsEndpoint` in `Info.plist` to your Mac's address, for example
`http://192.168.1.20:8080/v1/analytics/events`, and pick your team under *Signing & Capabilities*.

## What the app records

| User action | Event | Main properties |
|---|---|---|
| App starts | `app_opened` | |
| A screen appears | `screen_viewed` | `screen_name` (Shop, ProductDetail, Cart, Profile) |
| Opens a product | `product_viewed` | `product_id`, `product_name`, `category`, `price`, `currency`, `source` (list or search) |
| Searches | `search_performed` | `query`, `results_count` |
| Picks a category | `category_selected` | `category` |
| Adds to cart | `add_to_cart` | product info + `quantity`, `cart_item_count`, `cart_value` |
| Removes from cart | `remove_from_cart` | product info + `quantity`, `cart_value` |
| Checks out | `checkout_started`, `purchase_completed` | `order_id`, `revenue`, `currency`, `item_count`, `categories`, `payment_method` |
| Signs in as Alice, Bob or Carol | identify + `login` | user id `user-1001`..`1003`; traits `plan`, `country`, `age_group` |
| Logs out | `logout`, then the SDK resets the identity | |
| Turns "Allow analytics" off | nothing is recorded, unsent events are deleted | |

Events carry the user id (after sign-in), an anonymous id, a session id, and the device context (app version, iOS version,
device model, locale, time zone, network type), all added by the SDK.

**Privacy:** names and e-mail addresses are never sent. The user id is an opaque value, and the SDK rejects properties that look
like e-mail addresses or passwords. Payment details are never recorded (the checkout is a demo).

## Uploading
The SDK uploads by itself when 20 events are waiting, every 15 seconds, and when the app becomes active or goes to the background.
Try it: turn on Airplane Mode and tap around, then turn it off. The waiting events are sent and show up in the chart page.

## Files (Sources/)
| File | What it does |
|---|---|
| `SampleShopApp.swift` | App start and the 3 tabs |
| `AppAnalytics.swift` | The only code that talks to the SDK (`track`, `screen`, `identify`, consent) |
| `ShopStore.swift` | Cart and user, and which event each action records |
| `Models.swift` | Products and demo users |
| `ShopView.swift`, `CartView.swift`, `ProfileView.swift` | The screens |

## Notes
- Consent starts as granted so the demo works at once. A real app should ask first: the SDK's own default is "denied".
- Not built in Xcode here: the code was type-checked against the iOS 17 simulator SDK, but I could not run `xcodebuild` or the app,
  so open it in Xcode to build, and tell me about any signing or project-file problem.
