#!/usr/bin/env bash
# Captures README screenshots of the example app's gallery on an iPhone simulator.
# Usage: scripts/screenshots.sh <Scheme> <bundle id> <scene> [<scene> ...]
# Writes docs/screenshots/iphone-<scene>.png, for example iphone-delivery.png and iphone-island.png.
# The app writes tmp/screenshot-ready once a scene is on screen; the script waits for that marker and
# exits with an error instead of keeping a blank, stale or home-screen capture.
set -euo pipefail

SCHEME="$1"; BUNDLE_ID="$2"; shift 2
if [ $# -eq 0 ]; then
  echo "No scenes given" >&2
  exit 1
fi
PROJECT="Example/$SCHEME.xcodeproj"
OUT="docs/screenshots"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$OUT"

# The gallery is mostly dark, so a file size threshold cannot tell a blank frame from a real one on
# its own. A small checker looks at the image size and colour variety as well.
xcrun swiftc -O scripts/check-screenshot.swift -o "$TMP/check-screenshot"

# Newest iOS runtime, used only when a simulator has to be created.
RUNTIME=$(xcrun simctl list runtimes available -j | jq -r '
  [.runtimes[] | select(.identifier | test("iOS"))]
  | sort_by(.version | split(".") | map(tonumber)) | last | .identifier // empty')

# pick_iphone: an iPhone Pro (it has a Dynamic Island) on the newest iOS runtime, then any iPhone.
# Creates one when none exists.
pick_iphone() {
  local devices udid pattern type
  devices=$(xcrun simctl list devices available -j | jq -c '
    [.devices | to_entries | sort_by(.key) | reverse | .[]
     | select(.key | test("iOS")) | .value[] | select(.name | test("^iPhone"))]')
  for pattern in "^iPhone [0-9]+ Pro$" "Pro$" "^iPhone [0-9]+$"; do
    udid=$(jq -r --arg pattern "$pattern" 'map(select(.name | test($pattern))) | .[0].udid // empty' <<< "$devices")
    if [ -n "$udid" ]; then echo "$udid"; return; fi
  done
  udid=$(jq -r '.[0].udid // empty' <<< "$devices")
  if [ -z "$udid" ]; then
    type=$(xcrun simctl list devicetypes -j | jq -r '
      [.devicetypes[] | select(.name | test("^iPhone"))] | last | .identifier // empty')
    if [ -z "$type" ] || [ -z "$RUNTIME" ]; then
      echo "No iPhone simulator, device type or iOS runtime available" >&2
      exit 1
    fi
    udid=$(xcrun simctl create "Screenshots iPhone" "$type" "$RUNTIME")
  fi
  echo "$udid"
}

UDID="$(pick_iphone)"
echo "Using iPhone simulator $UDID"
xcrun simctl list devices -j | jq -r --arg udid "$UDID" '.devices[][] | select(.udid == $udid) | "Device: \(.name)"'

# Builds the app and its widget extension.
xcodebuild build \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -destination "id=$UDID" \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO DEVELOPMENT_TEAM= | tail -n 5

APP="$(find build/Build/Products -maxdepth 2 -name "$SCHEME.app" | head -n 1)"
if [ -z "$APP" ]; then
  echo "Build product $SCHEME.app not found" >&2
  exit 1
fi

# valid_capture <file> <home screen capture> <previous capture or empty>
# Rejects blank or launching frames (the checker), a capture identical to the home screen (the app
# never came to the front) and one identical to the previous scene (the app never switched).
valid_capture() {
  local file="$1" home="$2" previous="$3"
  [ -s "$file" ] || return 1
  "$TMP/check-screenshot" "$file" || return 1
  if cmp -s "$file" "$home"; then
    return 1
  fi
  if [ -n "$previous" ] && cmp -s "$file" "$previous"; then
    return 1
  fi
  return 0
}

xcrun simctl shutdown all > /dev/null 2>&1 || true
xcrun simctl boot "$UDID" || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
xcrun simctl ui "$UDID" appearance dark
xcrun simctl install "$UDID" "$APP"
CONTAINER="$(xcrun simctl get_app_container "$UDID" "$BUNDLE_ID" data)"

# A first boot can still be setting up the home screen; give it time, then keep a capture of it so a
# frame where the app never came to the front is rejected.
sleep 15
HOME_CAPTURE="$TMP/home.png"
xcrun simctl io "$UDID" screenshot "$HOME_CAPTURE"

previous=""
for scene in "$@"; do
  file="$OUT/iphone-$scene.png"
  capture="$TMP/iphone-$scene.png"
  ok=""
  for attempt in 1 2 3; do
    xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
    sleep 1
    rm -f "$CONTAINER/tmp/screenshot-ready"
    if ! xcrun simctl launch "$UDID" "$BUNDLE_ID" -screenshot "$scene"; then
      echo "Could not launch the app for $scene (attempt $attempt), retrying"
      continue
    fi
    # The app writes this marker once the scene is on screen.
    waited=0
    while [ ! -f "$CONTAINER/tmp/screenshot-ready" ] && [ "$waited" -lt 90 ]; do
      sleep 1
      waited=$((waited + 1))
    done
    if [ ! -f "$CONTAINER/tmp/screenshot-ready" ]; then
      echo "The app did not show $scene (attempt $attempt), retrying"
      continue
    fi
    # Nothing in the gallery animates, but the system can still be fading the app in after a launch.
    sleep $((3 + attempt * 2))
    rm -f "$capture"
    xcrun simctl io "$UDID" screenshot "$capture"
    if valid_capture "$capture" "$HOME_CAPTURE" "$previous"; then
      ok=1
      break
    fi
    echo "Blank, stale or home screen capture for $scene (attempt $attempt), retrying"
  done
  if [ -z "$ok" ]; then
    echo "Capture for iphone-$scene is still broken; refusing to commit a bad screenshot." >&2
    exit 1
  fi
  mv "$capture" "$file"
  previous="$file"
  echo "Captured $file ($(wc -c < "$file") bytes)"
done

xcrun simctl shutdown "$UDID" || true
