#!/usr/bin/env python3
"""Pick (or create) an available iOS simulator and emit its UDID.

Hosted macOS runner images don't always ship the newest iOS simulator runtime
(see actions/runner-images#13435, #13853), so we never hardcode an OS version.
This script finds the highest available iOS runtime, picks an iPhone device on
it, and creates one if none exist. Outputs `udid`, `name`, and `runtime` to
$GITHUB_OUTPUT.
"""

import json
import os
import subprocess
import sys


def sh(*args: str) -> str:
    return subprocess.run(args, capture_output=True, text=True, check=True).stdout


def version_key(v: str) -> tuple:
    parts = []
    for chunk in v.split("."):
        try:
            parts.append(int(chunk))
        except ValueError:
            parts.append(0)
    return tuple(parts)


def newest_ios_runtime() -> dict | None:
    runtimes = json.loads(sh("xcrun", "simctl", "list", "runtimes", "--json"))["runtimes"]
    ios = [
        r for r in runtimes
        if r.get("isAvailable") and (r.get("platform") == "iOS" or r.get("name", "").startswith("iOS"))
    ]
    ios.sort(key=lambda r: version_key(r.get("version", "0")))
    return ios[-1] if ios else None


# iPhone device preference, best first.
PREFERRED = ["iPhone 17 Pro", "iPhone 17", "iPhone 16 Pro", "iPhone 16", "iPhone"]


def device_score(name: str) -> int:
    for i, p in enumerate(PREFERRED):
        if name.startswith(p):
            return i
    return len(PREFERRED)


def main() -> int:
    runtime = newest_ios_runtime()
    if runtime is None:
        # No runtime present — download one, then re-query.
        print("No iOS runtime available; downloading via xcodebuild...", file=sys.stderr)
        subprocess.run(["xcodebuild", "-downloadPlatform", "iOS"], check=True)
        runtime = newest_ios_runtime()
        if runtime is None:
            print("Still no iOS runtime after download.", file=sys.stderr)
            return 1

    rt_id = runtime["identifier"]
    rt_version = runtime.get("version", "unknown")

    devices = json.loads(sh("xcrun", "simctl", "list", "devices", "--json"))["devices"]
    candidates = [d for d in devices.get(rt_id, []) if d.get("isAvailable")]

    if candidates:
        candidates.sort(key=lambda d: device_score(d["name"]))
        udid, name = candidates[0]["udid"], candidates[0]["name"]
    else:
        # Create a fresh iPhone on this runtime.
        devtypes = json.loads(sh("xcrun", "simctl", "list", "devicetypes", "--json"))["devicetypes"]
        chosen = None
        for want in PREFERRED[:-1]:
            for t in devtypes:
                if t["name"] == want:
                    chosen, name = t["identifier"], want
                    break
            if chosen:
                break
        if not chosen:
            iphones = [t for t in devtypes if "iPhone" in t["name"]]
            if not iphones:
                print("No iPhone device type available.", file=sys.stderr)
                return 1
            chosen, name = iphones[-1]["identifier"], iphones[-1]["name"]
        udid = sh("xcrun", "simctl", "create", "terrarium-ci", chosen, rt_id).strip()

    out = os.environ.get("GITHUB_OUTPUT")
    if out:
        with open(out, "a") as f:
            f.write(f"udid={udid}\n")
            f.write(f"name={name}\n")
            f.write(f"runtime={rt_version}\n")
    print(f"Selected {name} ({udid}) on iOS {rt_version}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
