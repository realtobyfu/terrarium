#!/usr/bin/env python3
"""Extract named screenshot attachments from a UI-test .xcresult bundle.

The feature-capture UI test (FeatureScreenshotTests) attaches screenshots with
stable, ordered names like "01-Onboarding-Transport". `xcresulttool export
attachments` writes them with opaque filenames plus a manifest.json that maps
each exported file to its `suggestedHumanReadableName`. We read that manifest and
copy the screenshots we care about into OUT_DIR under their human-readable names
so the PR-comment step can render them.

Best-effort: any failure prints a warning and exits 0 so it never gates the build.

Env:
  XCRESULT  path to the UI-test .xcresult
  OUT_DIR   directory to write named PNGs into
"""

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

# Only keep attachments whose human-readable name follows our "NN-Name" capture
# convention — filters out automatic system/failure attachments.
NAME_RE = re.compile(r"^\d{2}-")

# Xcode decorates the attachment name we set as
# "<name>_<index>_<UUID>.<ext>"; strip that decoration back to "<name>".
DECORATION_RE = re.compile(
    r"_\d+_[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-"
    r"[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$"
)


def clean_name(name: str) -> str:
    """Turn '01-Settings_0_<UUID>.png' into '01-Settings'."""
    stem = os.path.splitext(name)[0]
    return DECORATION_RE.sub("", stem)


def warn(msg: str) -> None:
    print(f"::warning::{msg}", file=sys.stderr)


def main() -> int:
    xcresult = os.environ.get("XCRESULT", "")
    out_dir = os.environ.get("OUT_DIR", "artifacts/feature-screens")

    if not xcresult or not os.path.isdir(xcresult):
        warn(f"xcresult not found at {xcresult!r} — nothing to extract")
        return 0

    os.makedirs(out_dir, exist_ok=True)
    tmp = tempfile.mkdtemp(prefix="attachments-")

    try:
        subprocess.run(
            ["xcrun", "xcresulttool", "export", "attachments",
             "--path", xcresult, "--output-path", tmp],
            check=True, capture_output=True, text=True,
        )
    except Exception as exc:  # tolerate xcresulttool drift across Xcode versions
        warn(f"xcresulttool export attachments failed: {exc}")
        return 0

    manifest_path = os.path.join(tmp, "manifest.json")
    if not os.path.isfile(manifest_path):
        warn("no manifest.json produced by export — nothing to extract")
        return 0

    try:
        manifest = json.loads(open(manifest_path).read())
    except Exception as exc:
        warn(f"could not parse manifest.json: {exc}")
        return 0

    # manifest is a list of per-test objects, each with an "attachments" list.
    count = 0
    for test in manifest if isinstance(manifest, list) else []:
        for att in test.get("attachments", []):
            name = att.get("suggestedHumanReadableName") or ""
            exported = att.get("exportedFileName") or ""
            if not exported or not NAME_RE.match(name):
                continue
            src = os.path.join(tmp, exported)
            if not os.path.isfile(src):
                continue
            ext = os.path.splitext(exported)[1] or ".png"
            safe = re.sub(r"[^A-Za-z0-9._-]", "_", clean_name(name))
            dst = os.path.join(out_dir, f"{safe}{ext}")
            shutil.copyfile(src, dst)
            count += 1
            print(f"Extracted {name} -> {dst}")

    if count == 0:
        warn("no matching named attachments found in xcresult")
    else:
        print(f"Extracted {count} screenshot(s) to {out_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
