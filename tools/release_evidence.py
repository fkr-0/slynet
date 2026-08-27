#!/usr/bin/env python3
"""Write machine-readable local release evidence for the built SLYNET artifacts."""

from __future__ import annotations

import datetime as dt
import hashlib
import os
import pathlib
import re
import subprocess
from collections import Counter

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


def command_output(*args: str) -> str:
    result = subprocess.run(
        list(args), cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=False
    )
    return result.stdout.strip().splitlines()[0] if result.stdout.strip() else ""


def protocol_inventory_counts() -> Counter[str]:
    text = (ROOT / "docs" / "generated" / "protocol-inventory.yml").read_text(encoding="utf-8")
    return Counter(re.findall(r"^    state: ([^\n]+)$", text, flags=re.MULTILINE))


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
    revision = git("rev-parse", "HEAD")
    tag = f"v{version}"
    tag_revision = git("rev-list", "-n", "1", tag)
    inventory = protocol_inventory_counts()
    status = git("status", "--porcelain", "--untracked-files=all")
    tracked_status = "\n".join(line for line in status.splitlines() if ".ws-bridge/" not in line)

    lines = [
        "schema_version: 1",
        "project: slynet",
        f"version: {yaml_quote(version)}",
        f"generated_at_utc: {yaml_quote(dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat())}",
        f"revision: {yaml_quote(revision)}",
        f"branch: {yaml_quote(git('branch', '--show-current'))}",
        f"tag: {yaml_quote(tag)}",
        f"tag_created: {'true' if tag_revision else 'false'}",
        f"tag_points_to_revision: {'true' if tag_revision == revision and tag_revision else 'false'}",
        "publish_state: not_requested",
        f"origin_configured: {'true' if origin else 'false'}",
        f"origin: {yaml_quote(origin) if origin else 'null'}",
        f"working_tree_clean: {'true' if not tracked_status else 'false'}",
        "toolchain:",
        f"  janet: {yaml_quote(command_output('janet', '--version'))}",
        f"  emacs: {yaml_quote(command_output('emacs', '--version'))}",
        f"  eldev: {yaml_quote(command_output('eldev', '--version'))}",
        "protocol_inventory:",
        f"  operation_count: {sum(inventory.values())}",
        f"  implemented_tested: {inventory.get('implemented', 0)}",
        f"  implemented_without_direct_test_mapping: {inventory.get('implemented_untested', 0)}",
        f"  missing: {inventory.get('missing', 0)}",
        "verification:",
        "  - name: lint",
        "    result: passed",
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
        "  - name: package",
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
    if tag_revision and tag_revision != revision:
        warnings.append(f"{tag} exists but does not point to the qualified revision")
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
