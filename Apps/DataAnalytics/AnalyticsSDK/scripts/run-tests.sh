#!/bin/bash
# Builds the SDK + Swift Testing tests with plain swiftc and runs them.
# `swift test` is the normal way; this exists for environments where SwiftPM cannot start its own sandbox.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${1:-${TMPDIR:-/tmp}/analyticssdk-build}"
DEV=/Applications/Xcode.app/Contents/Developer
PLUGINS="$DEV/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/plugins/testing"
FW="$DEV/Platforms/MacOSX.platform/Developer/Library/Frameworks"
mkdir -p "$OUT/mc"

swiftc -swift-version 5 -Onone -g -enable-testing -parse-as-library -module-name AnalyticsSDK \
  -module-cache-path "$OUT/mc" -target arm64-apple-macosx14.0 \
  -emit-library -emit-module -emit-module-path "$OUT/AnalyticsSDK.swiftmodule" \
  -Xlinker -install_name -Xlinker "@rpath/libAnalyticsSDK.dylib" \
  -o "$OUT/libAnalyticsSDK.dylib" $(find Sources -name '*.swift')

swiftc -swift-version 5 -Onone -g -parse-as-library -module-name AnalyticsSDKTests -module-cache-path "$OUT/mc" \
  -target arm64-apple-macosx14.0 -plugin-path "$PLUGINS" -I "$OUT" -L "$OUT" -lAnalyticsSDK -F "$FW" -framework Testing \
  -Xlinker -rpath -Xlinker "$OUT" -Xlinker -rpath -Xlinker "$FW" \
  -o "$OUT/run-tests" scripts/TestRunner.swift $(find Tests -name '*.swift')

"$OUT/run-tests"
