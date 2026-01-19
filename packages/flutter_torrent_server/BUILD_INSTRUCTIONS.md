# Building the Native Torrent Server

Since `go` is not installed on the system where the core planning was done, you must compile the Go binaries yourself to jumpstart the Torrent Server integration.

## Prerequisites

1.  **Install Go**: [Download Go](https://go.dev/dl/) (version 1.20+ recommended).
2.  **Install Gomobile** (for Android/iOS):
    ```bash
    go install golang.org/x/mobile/cmd/gomobile@latest
    gomobile init
    ```
3.  **Android NDK** (for Android): Ensure you have the NDK installed via Android Studio.

## Build Script

Run the provided `build_libs.sh` script to generate the necessary libraries.

```bash
cd packages/flutter_torrent_server
chmod +x build_libs.sh
./build_libs.sh
```

## What this does
1.  **Android**: Generates `android/libs/torrentserver.aar` (contains Java bindings + native libs).
2.  **iOS**: Generates `ios/Frameworks/TorrServer.xcframework`.
3.  **Desktop**: Generates shared libraries (`.dylib`, `.dll`, `.so`) in `assets/`.

## Post-Build Setup
After running the script, the Flutter plugin will automatically attempt to link these libraries.
