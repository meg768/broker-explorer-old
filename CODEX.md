# Codex Context

## Project

`Broker Explorer` is a native macOS SwiftUI MQTT explorer.

It connects to an MQTT broker, subscribes to retained/live topics, renders topics as a tree, shows payloads, and can publish retained or live messages back to selected topics.

This is a local macOS app, not the retired web-based `mqtt-explorer.egelberg.se` service.

## Repository

- Local path: `/Users/magnus/Documents/GitHub/broker-explorer`
- GitHub repository: `meg768/broker-explorer`
- Swift package product: `BrokerExplorer`
- Minimum platform: macOS 13
- App bundle output: `dist/Broker Explorer.app`
- Main dependencies:
  - `mqtt-nio`
  - `swift-nio`

## Build

Useful commands:

```bash
swift build
swift run BrokerExplorer
Scripts/build-app.sh
Scripts/build-app.sh debug
```

`Scripts/build-app.sh` builds the Swift package, assembles a Finder-launchable `.app` under `dist/`, copies `Resources/Info.plist`, copies `Resources/BrokerExplorerIcon.icns`, and marks the executable as runnable.

As of 2026-06-30, there is no DMG build script and no signing/notarization flow in this repo.

Verification run on 2026-06-30:

```bash
swift build -c debug
```

passed locally.

## App Structure

- `Package.swift`: Swift package configuration and dependencies
- `Scripts/build-app.sh`: app bundle builder
- `Resources/Info.plist`: app metadata
- `Resources/BrokerExplorerIcon.*`: app icon sources
- `Sources/BrokerExplorer/BrokerExplorerApp.swift`: app entrypoint
- `Sources/BrokerExplorer/ContentView.swift`: main UI
- `Sources/BrokerExplorer/ExplorerStore.swift`: app/session state and publish/delete behavior
- `Sources/BrokerExplorer/MQTTService.swift`: MQTT connection, subscribe, publish, disconnect
- `Sources/BrokerExplorer/Models.swift`: connection, message, topic-tree models
- `Sources/BrokerExplorer/SettingsStore.swift`: persisted UserDefaults settings
- `Sources/BrokerExplorer/AppearanceSettings.swift`: theme/surface settings
- `Sources/BrokerExplorer/JSONTextEditor.swift`: payload editor/viewer helper

## MQTT Behavior

- Connection URL supports `mqtt://` and `mqtts://`.
- Default URL is `mqtt://localhost`; default port is `1883`.
- `mqtts://` defaults to port `8883`.
- On connect, the app subscribes to `#` with QoS 1.
- Incoming messages are stored by topic; later messages replace earlier messages for the same topic.
- Empty payloads remove the topic locally, matching retained-message deletion behavior.
- Publishing supports retain and QoS selection.
- `deleteTree(topic:)` publishes retained empty payloads to each known topic under the selected tree path.

## Persistence

`SettingsStore` stores at most five recent `BrokerConnection` values as Codable
JSON data in UserDefaults, plus UI search text, topic panel width, and surface theme.
Passwords remain in UserDefaults; no Keychain or legacy connection migration.
Recents are updated after MQTT login succeeds, independently of subscription success.
Identity is the trimmed URL, port, and username; password changes replace the entry.

The app has one window, no tabs, and one optional logical open connection. It
launches without an open connection. Connection → New Connection… edits a fresh
in-memory draft; Cancel leaves the current broker untouched. Open Recent connects
directly. Close Connection clears the session without deleting recents.
Unexpected network loss preserves the logical connection and existing reconnect
behavior. Connect/close operations are serialized and old callbacks are rejected
using the connection generation.

## Visual Design

Broker Explorer should prefer native macOS/SwiftUI presentation and system
appearance. Topic, Message, and Connection inputs use rounded borders
and native focus rings consistently. Connection fields use standard SwiftUI
controls. The AppKit payload editor retains its behavior; its scroll-view frame
has rounded corners and a matching mask for the system-rendered focus ring.
It no longer shares the tennis-derived visual palette or panel
styling of `lan-scanner`. Delegate ordinary control chrome, typography, and
light/dark appearance to the system; keep custom color only for semantic uses
such as syntax highlighting and errors.

The first presentation pass keeps the existing recursive MQTT tree and custom
split container, their interactions, and the AppKit JSON editor unchanged.
Connection configuration is presented in a SwiftUI sheet with live bindings,
an in-memory draft and Return-to-connect. Connect dismisses the sheet and opens
the requested broker. No connection open shows a native empty state with New
Connection… and directions to Open Recent. Failed connection attempts show
a Connection Failed state; unrelated operation errors do not trigger it. Connection actions remain in the native toolbar.
Legacy F3 syntax-theme cycling and F6 appearance switching are retained for
compatibility; the surrounding UI uses system colors regardless of surface theme.

## Distribution Notes

README intentionally teaches local build as the recommended path. Sharing unsigned prebuilt macOS apps with non-technical users hits the same Gatekeeper/notarization wall seen in `lan-scanner`.

For polished external distribution, add Developer ID signing and Apple notarization before publishing a `.dmg` or `.zip`.

## Related Context

The old web-based `mqtt-explorer.egelberg.se` service was retired on `pi-kato` on 2026-06-19. Do not confuse that retired web deployment with this native local macOS app.

Global retirement note lives in `/Users/magnus/Documents/GitHub/codex-chat/CONTEXT.md`.

## Gotchas

- The app reads the broker by subscribing to `#`; this can be noisy on a busy broker.
- The "read complete" status is timer-based after messages quiet down, not a protocol-level retained-topic completion event.
- Topic deletion only targets topics already known in the current in-memory tree.
- If renaming the app, update `Package.swift`, `Resources/Info.plist`, `Scripts/build-app.sh`, README, and the `Sources/BrokerExplorer` target/folder coherently.
- `MultiThreadedEventLoopGroup.singleton` is used through MQTTNIO; ensure disconnect/shutdown paths remain clean to avoid MQTT client shutdown traps.
