#!/bin/bash

# Configuration
MODULE_NAME="github.com/Diegopyl1209/torrentserver-aniyomi"
SRC_DIR="go_src"
OUTPUT_ANDROID="android/libs/torrentserver.aar"
OUTPUT_IOS="ios/Frameworks/TorrServer.xcframework"

# EXPLICIT SDK PATHS
export ANDROID_HOME="/Users/akash/Library/Android/sdk"
export ANDROID_NDK_HOME="/Users/akash/Library/Android/sdk/ndk/27.0.12077973"
export PATH=$PATH:~/go/bin

echo "Building Torrent Server Libraries..."

# 1. Update Dependencies
cd $SRC_DIR
go mod tidy
cd ..

# 2. Build for Android (aar)
echo "Building for Android..."
mkdir -p android/libs
cd $SRC_DIR
# Bind the 'bindings' package which contains the public API (TorrServer class)
~/go/bin/gomobile bind -target=android -androidapi 21 -o ../$OUTPUT_ANDROID ./bindings
cd ..
echo "Android build complete: $OUTPUT_ANDROID"

# 3. Build for iOS (xcframework)
echo "Building for iOS..."
mkdir -p ios/Frameworks
cd $SRC_DIR
# Note: Requires Xcode and macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    ~/go/bin/gomobile bind -target=ios -o ../$OUTPUT_IOS ./bindings
    echo "iOS build complete: $OUTPUT_IOS"
else
    echo "Skipping iOS build (not on macOS)"
fi
cd ..

# 4. Build for Desktop (Shared Libraries)
echo "Building for Desktop (Host Platform)..."
mkdir -p assets
cd $SRC_DIR

if [[ "$OSTYPE" == "darwin"* ]]; then
    go build -buildmode=c-shared -o ../assets/libtorrentserver.dylib ./bindings
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    go build -buildmode=c-shared -o ../assets/libtorrentserver.so ./bindings
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    go build -buildmode=c-shared -o ../assets/libtorrentserver.dll ./bindings
fi
cd ..
echo "Desktop build complete."

echo "All builds finished."
