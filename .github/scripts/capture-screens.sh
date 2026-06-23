#!/usr/bin/env bash
#
# Boot a simulator, install + launch the built app, and capture screenshots and
# a short screen recording. Best-effort: failures here never fail the build (the
# app/test result is what gates the PR), so every step is guarded.
#
# Env:
#   UDID       simulator UDID (from pick-simulator)
#   APP_PATH   path to the built .app
#   BUNDLE_ID  app bundle identifier
#   OUT_DIR    directory to write screens/recording into
#
set -uo pipefail

OUT_DIR="${OUT_DIR:-artifacts/screens}"
mkdir -p "$OUT_DIR"

echo "Booting $UDID..."
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b || true

if [ ! -d "$APP_PATH" ]; then
  echo "::warning::App not found at $APP_PATH — skipping capture."
  exit 0
fi

echo "Installing $APP_PATH..."
if ! xcrun simctl install "$UDID" "$APP_PATH"; then
  echo "::warning::Install failed — skipping capture."
  exit 0
fi

# Start a screen recording in the background.
REC="$OUT_DIR/recording.mov"
xcrun simctl io "$UDID" recordVideo --codec=h264 --force "$REC" &
REC_PID=$!

echo "Launching $BUNDLE_ID..."
xcrun simctl launch "$UDID" "$BUNDLE_ID" || echo "::warning::launch returned non-zero"

# Give the UI time to settle, grabbing a couple of frames.
sleep 6
xcrun simctl io "$UDID" screenshot "$OUT_DIR/01-launch.png" || true
sleep 3
xcrun simctl io "$UDID" screenshot "$OUT_DIR/02-app.png" || true

# Stop the recording cleanly so the .mov finalizes.
kill -INT "$REC_PID" 2>/dev/null || true
wait "$REC_PID" 2>/dev/null || true

echo "Captured:"
ls -la "$OUT_DIR" || true
