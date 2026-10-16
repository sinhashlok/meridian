#!/bin/zsh
# Relaunch the installed Debug build in a given state and screenshot it.
#
#   scripts/shoot.sh <name> <screen> [now] [zones]
#   scripts/shoot.sh planner planner 2026-10-15T15:32:00Z
#   UTC=1 scripts/shoot.sh plannerUTC planner
#
# <screen>: clocks | planner | plannerScrub | addZone | editZone | changes   (see Meridian/App/DebugLaunch.swift)
# [now]:    frozen clock, ISO 8601 (default 2026-10-15T15:32:00Z, the boards' Planner time)
# [zones]:  "Asia/Kolkata=Mumbai,Europe/London=London,..."; the first is home
# Env:      UTC=1 for UTC mode, WAIT=<seconds> before the shot, OUT=<dir> for the PNGs,
#           EXTRA="-MeridianDay 2026-10-25 -MeridianSelect 2026-10-15T15:00:00Z -MeridianWarn 1"
#
# Build and install first:
#   xcodebuild -project Meridian.xcodeproj -scheme Meridian \
#     -destination 'platform=iOS Simulator,name=iPhone 18 Pro' build
#   xcrun simctl install booted ~/Library/Developer/Xcode/DerivedData/Meridian-*/Build/Products/Debug-iphonesimulator/Meridian.app
# Large text: xcrun simctl ui booted content_size accessibility-extra-extra-extra-large  (reset: large)
set -e
OUT=${OUT:-${TMPDIR:-/tmp}/meridian-shots}
mkdir -p "$OUT"
NOW=${3:-2026-10-15T15:32:00Z}
ZONES=${4:-Asia/Kolkata=Mumbai,Europe/London=London,America/Los_Angeles=SF}
xcrun simctl terminate booted com.shloksinha.meridian >/dev/null 2>&1 || true
xcrun simctl launch booted com.shloksinha.meridian \
  -MeridianNow "$NOW" -MeridianZones "$ZONES" -MeridianScreen "$2" -MeridianUTC "${UTC:-0}" ${=EXTRA} >/dev/null
sleep ${WAIT:-3}
xcrun simctl io booted screenshot "$OUT/$1.png" >/dev/null 2>&1
echo "$OUT/$1.png"
