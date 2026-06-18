# Broker Explorer

A native macOS MQTT explorer, built with SwiftUI.

## What It Does

- Manage broker connection profiles
- Connect and subscribe to MQTT topic filters
- Render incoming topics as a browsable tree
- Inspect latest payloads
- Publish messages to selected topics

## Requirements

- A Mac running macOS 13 Ventura or newer
- Xcode
- Git
- Internet access the first time you build, because Swift Package Manager downloads dependencies

## 1. Install Xcode

Install Xcode from the Mac App Store:

<https://apps.apple.com/app/xcode/id497799835>

After installing Xcode, open it once. macOS may ask you to install extra components. Let it finish.

Then open Terminal. You can find it in:

```text
Applications -> Utilities -> Terminal
```

Run:

```sh
sudo xcodebuild -license accept
```

If command-line tools are missing, install them with:

```sh
xcode-select --install
```

Check that Swift is available:

```sh
swift --version
```

## 2. Clone the Repository

Choose a folder where you keep projects, then clone Broker Explorer. This example uses `~/Documents/GitHub`:

```sh
mkdir -p ~/Documents/GitHub
cd ~/Documents/GitHub
git clone https://github.com/meg768/broker-explorer.git
cd broker-explorer
```

## 3. Build and Run from Terminal

For a quick test, run:

```sh
swift build
swift run BrokerExplorer
```

The first build can take a while because Swift downloads and compiles dependencies.

## 4. Build the Mac App

To create a normal Finder-launchable `.app`, run:

```sh
Scripts/build-app.sh
open dist
```

This creates:

```text
dist/Broker Explorer.app
```

Double-click `Broker Explorer.app` to launch it.

## 5. Build from Xcode

You can also build and run the app from Xcode:

1. Open `Package.swift` in Xcode.
2. Select the `BrokerExplorer` scheme.
3. Select **My Mac** as the run destination.
4. Press **Run**.

## Updating Later

To get the latest version:

```sh
cd ~/Documents/GitHub/broker-explorer
git pull
Scripts/build-app.sh
open dist
```

## Troubleshooting

### `swift` is not found

Install Xcode and the command-line tools:

```sh
xcode-select --install
```

Then check again:

```sh
swift --version
```

### Xcode says the license has not been accepted

Run:

```sh
sudo xcodebuild -license accept
```

### The first build is slow

That is normal. Swift Package Manager downloads and compiles dependencies on the first build. Later builds are much faster.

### macOS says the downloaded app cannot be verified

If you build the app yourself from this repository, the app should normally run without the same download quarantine warning that appears when someone sends you a prebuilt app.

This is the reason the recommended path is to build locally instead of downloading a prebuilt `.app` or `.dmg`. Building locally does not require an Apple Developer account.

If macOS still blocks the locally built app, rebuild it:

```sh
rm -rf dist
Scripts/build-app.sh
open dist
```

Then launch `Broker Explorer.app` from the `dist` folder.
