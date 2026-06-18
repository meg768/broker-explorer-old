# Broker Explorer

A native macOS MQTT explorer, built with SwiftUI.

## Getting Started

Open `Package.swift` in Xcode, select the `BrokerExplorer` scheme, and run it.

From the terminal:

```sh
swift build
swift run BrokerExplorer
```

## Build a Finder App

```sh
Scripts/build-app.sh
open dist
```

Then double-click `Broker Explorer.app`.

## First Milestone

- Manage broker connection profiles
- Connect and subscribe to MQTT topic filters
- Render incoming topics as a browsable tree
- Inspect latest payloads
- Publish messages to selected topics
