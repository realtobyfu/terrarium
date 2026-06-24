#!/usr/bin/env python3
"""Compose and upsert a sticky CI summary comment on the PR.

Parses test counts from the .xcresult (best-effort), builds a markdown summary
with build/test status, simulator info, and a link to the run's artifacts
(screenshots + recording + xcresult), then creates or updates the single
comment tagged with MARKER.

Env: REPO, PR_NUMBER, RUN_URL, TEST_RESULT, RESULT_BUNDLE, SIM_NAME,
     SIM_RUNTIME, SCREENS_DIR, FEATURE_DIR, SCREENS_BRANCH, SCREENS_SHA,
     GH_TOKEN (consumed by gh).
"""

import json
import os
import subprocess
import sys

MARKER = "<!-- terrarium-ci -->"


def env(key: str, default: str = "") -> str:
    return os.environ.get(key, default)


def test_summary(bundle: str) -> dict | None:
    if not bundle or not os.path.isdir(bundle):
        return None
    try:
        out = subprocess.run(
            ["xcrun", "xcresulttool", "get", "test-results", "summary",
             "--path", bundle, "--format", "json"],
            capture_output=True, text=True, check=True,
        ).stdout
        return json.loads(out)
    except Exception as exc:  # tolerate format drift across Xcode versions
        print(f"::warning::could not parse xcresult: {exc}", file=sys.stderr)
        return None


def build_body() -> str:
    test_result = env("TEST_RESULT", "1")
    passed = test_result == "0"
    summary = test_summary(env("RESULT_BUNDLE"))

    status = "✅ Passed" if passed else "❌ Failed"
    lines = [
        MARKER,
        "## 🌱 Terrarium CI",
        "",
        f"**Build & test:** {status}",
        "",
    ]

    if summary:
        total = summary.get("totalTestCount", "?")
        ok = summary.get("passedTests", "?")
        failed = summary.get("failedTests", "?")
        skipped = summary.get("skippedTests", 0)
        lines += [
            "| Tests | Passed | Failed | Skipped |",
            "|------:|-------:|-------:|--------:|",
            f"| {total} | {ok} | {failed} | {skipped} |",
            "",
        ]
        failures = summary.get("testFailures") or []
        if failures:
            lines.append("<details><summary>Failures</summary>\n")
            for f in failures[:20]:
                name = f.get("testName", "unknown")
                msg = (f.get("failureText") or "").strip().replace("\n", " ")
                lines.append(f"- **{name}** — {msg}")
            lines.append("\n</details>")
            lines.append("")

    sim_name = env("SIM_NAME", "iOS Simulator")
    sim_rt = env("SIM_RUNTIME", "?")
    lines += [f"**Simulator:** {sim_name} · iOS {sim_rt}", ""]

    lines += feature_screens_section()
    lines += artifacts_section()

    lines += [f"[View full run →]({env('RUN_URL')})"]
    return "\n".join(lines)


def feature_screens_section() -> list[str]:
    """Render the captured feature screenshots inline via raw.githubusercontent
    URLs (pushed to a dedicated branch by publish-screens.sh). Falls back to a
    plain filename list if the publish step didn't produce a commit SHA."""
    feature_dir = env("FEATURE_DIR")
    if not feature_dir or not os.path.isdir(feature_dir):
        return []
    pngs = sorted(f for f in os.listdir(feature_dir) if f.lower().endswith(".png"))
    if not pngs:
        return []

    lines = ["**📸 Feature screens**", ""]

    repo = env("REPO")
    sha = env("SCREENS_SHA")
    pr = env("PR_NUMBER")
    if repo and sha and pr:
        base = f"https://raw.githubusercontent.com/{repo}/{sha}/pr-{pr}"
        # A simple table keeps the images side-by-side and reasonably sized.
        titles = [os.path.splitext(p)[0] for p in pngs]
        lines.append("| " + " | ".join(titles) + " |")
        lines.append("|" + "|".join([":---:"] * len(pngs)) + "|")
        cells = [f'<img src="{base}/{p}" width="240">' for p in pngs]
        lines.append("| " + " | ".join(cells) + " |")
    else:
        # Publish step unavailable (e.g. fork PR): list names, link artifacts.
        lines += [f"- `{p}`" for p in pngs]
    lines.append("")
    return lines


def artifacts_section() -> list[str]:
    """Point at the run's artifacts for the full set (raw frames + recording)."""
    screens_dir = env("SCREENS_DIR")
    shots = []
    if screens_dir and os.path.isdir(screens_dir):
        shots = sorted(f for f in os.listdir(screens_dir)
                       if f.lower().endswith((".png", ".mov")))
    if not shots:
        return []
    return [
        "**🎞 Recording & raw frames** — download from the run's "
        f"[**Artifacts**]({env('RUN_URL')}#artifacts):",
        "",
        *[f"- `{s}`" for s in shots],
        "",
    ]


def gh(*args: str) -> str:
    return subprocess.run(["gh", *args], capture_output=True, text=True, check=True).stdout


def upsert(body: str) -> None:
    repo = env("REPO")
    pr = env("PR_NUMBER")
    # Find an existing tagged comment.
    existing = json.loads(gh(
        "api", f"repos/{repo}/issues/{pr}/comments", "--paginate"
    ))
    comment_id = next((c["id"] for c in existing if MARKER in (c.get("body") or "")), None)

    if comment_id:
        gh("api", "--method", "PATCH",
           f"repos/{repo}/issues/comments/{comment_id}",
           "-f", f"body={body}")
        print(f"Updated comment {comment_id}")
    else:
        gh("api", "--method", "POST",
           f"repos/{repo}/issues/{pr}/comments",
           "-f", f"body={body}")
        print("Created new comment")


if __name__ == "__main__":
    upsert(build_body())
