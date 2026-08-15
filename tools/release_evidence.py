#!/usr/bin/env python3
"""Write machine-readable local release evidence for the built SLYNET artifacts."""

from __future__ import annotations

import datetime as dt
import hashlib
import os
import pathlib
import re
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[1]
DIST = ROOT / "dist"


def project_version() -> str:
    text = (ROOT / "project.janet").read_text(encoding="utf-8")
    match = re.search(r':version\s+"([^"]+)"', text)
    if not match:
        raise SystemExit("release-evidence: cannot determine project version")
    return match.group(1)


def git(*args: str) -> str:
    result = subprocess.run(
        ["git", *args], cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, check=False
    )
    return result.stdout.strip() if result.returncode == 0 else ""


def sha256(path: pathlib.Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def yaml_quote(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def main() -> None:
    if os.environ.get("SLYNET_RELEASE_GATE_PASSED") != "1":
        raise SystemExit(
            "release-evidence: refusing to claim verification outside the completed release gate"
        )

    version = project_version()
    artifacts = [DIST / f"slynet-{version}.tar", DIST / f"slynet-{version}.tar.gz"]
    missing = [str(path) for path in artifacts if not path.is_file()]
    if missing:
        raise SystemExit(f"release-evidence: missing artifacts: {', '.join(missing)}")

    origin = git("remote", "get-url", "origin")
    status = git("status", "--porcelain", "--untracked-files=all")
    tracked_status = "\n".join(line for line in status.splitlines() if ".ws-bridge/" not in line)

    lines = [
        "schema_version: 1",
        "project: slynet",
        f"version: {yaml_quote(version)}",
        f"generated_at_utc: {yaml_quote(dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat())}",
        f"revision: {yaml_quote(git('rev-parse', 'HEAD'))}",
        f"branch: {yaml_quote(git('branch', '--show-current'))}",
        "tag_created: false",
        "publish_state: not_requested",
        f"origin_configured: {'true' if origin else 'false'}",
        f"origin: {yaml_quote(origin) if origin else 'null'}",
        f"working_tree_clean: {'true' if not tracked_status else 'false'}",
        "verification:",
        "  - name: release_integrity",
        "    result: passed",
        "  - name: protocol_warning_policy",
        "    result: passed",
        "  - name: protocol_inventory_freshness",
        "    result: passed",
        "  - name: janet_tests",
        "    result: passed",
        "  - name: emacs_tests",
        "    result: passed",
        "  - name: transport_fuzz",
        "    result: passed",
        "  - name: emacs_compile",
        "    result: passed",
        "  - name: direct_cli_e2e",
        "    result: passed",
        "  - name: extracted_artifact_start_connect_eval",
        "    result: passed",
        "artifacts:",
    ]
    for path in artifacts:
        lines.extend(
            [
                f"  - path: {yaml_quote(str(path.relative_to(ROOT)))}",
                f"    size_bytes: {path.stat().st_size}",
                f"    sha256: {yaml_quote(sha256(path))}",
            ]
        )
    warnings = []
    if not origin:
        warnings.append(
            "publication remote is not configured; publication-verify remains intentionally blocked"
        )
    if tracked_status:
        warnings.append(
            "evidence was generated from an intentionally dirty release-preparation tree; "
            "rerun after commit for final release evidence"
        )
    if warnings:
        lines.append("warnings:")
        lines.extend(f"  - {warning}" for warning in warnings)
    else:
        lines.append("warnings: []")

    DIST.mkdir(exist_ok=True)
    output = DIST / "release-evidence.yml"
    output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"release-evidence: wrote {output.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
