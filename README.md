# MQTT Desktop

A native macOS MQTT explorer, built with SwiftUI.

## Getting Started

Open `Package.swift` in Xcode, select the `MQTTDesktop` scheme, and run it.

From the terminal:

```sh
swift build
swift run MQTTDesktop
```

## Build a Finder App

```sh
Scripts/build-app.sh
open dist
```

Then double-click `MQTT Desktop.app`.

## First Milestone

- Manage broker connection profiles
- Connect and subscribe to MQTT topic filters
- Render incoming topics as a browsable tree
- Inspect latest payloads
- Publish messages to selected topics
