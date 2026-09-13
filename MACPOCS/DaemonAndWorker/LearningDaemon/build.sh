#!/bin/bash
# Builds LearningDaemon into ./.build/LearningDaemon.
# No sudo, no system directories touched — the binary stays inside this
# project folder; only the LaunchAgent plist you install separately needs to
# point at this path.
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p .build
swiftc main.swift LearningDaemonProtocol.swift -o .build/LearningDaemon
echo "Built .build/LearningDaemon"
