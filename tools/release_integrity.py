#!/usr/bin/env python3
"""Fail-closed release metadata and documented-entrypoint checks for SLYNET."""

from __future__ import annotations

import argparse
import os
import pathlib
import re
import socket
import subprocess
import sys
import time
from typing import Iterable

ROOT = pathlib.Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def fail(message: str) -> None:
    print(f"release-integrity: ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def regex_value(path: str, pattern: str, label: str) -> str:
    match = re.search(pattern, read(path), re.MULTILINE)
    if not match:
        fail(f"could not read {label} from {path}")
    return match.group(1)


def project_version() -> str:
    return regex_value("project.janet", r':version\s+"([^"]+)"', "project version")


def assert_version_coherence(version: str) -> None:
    checks = {
        "slynet/version.janet": regex_value(
            "slynet/version.janet", r'\(def version\s+"([^"]+)"\)', "runtime version"
        ),
        "bundle/info.jdn": regex_value(
            "bundle/info.jdn", r':version\s+"([^"]+)"', "bundle version"
        ),
        "emacs/slynet.el": regex_value(
            "emacs/slynet.el", r'^;; Version:\s+([^\s]+)$', "Emacs package version"
        ),
        "emacs/slynet-client.el": regex_value(
            "emacs/slynet-client.el", r'^;; Version:\s+([^\s]+)$', "Emacs client version"
        ),
    }
    for path, actual in checks.items():
        require(actual == version, f"{path} version {actual!r} != project version {version!r}")

    for path in ("slynet/init.janet", "slynet/cli.janet"):
        text = read(path)
        require(
            "(import ./version :as release-version)" in text
            and "(def version release-version/version)" in text,
            f"{path} must consume slynet/version.janet instead of defining an independent release version",
        )

    require(
        re.search(rf'^## \[{re.escape(version)}\](?:\s+-\s+\d{{4}}-\d{{2}}-\d{{2}})?$', read("CHANGELOG.md"), re.MULTILINE)
        is not None,
        f"CHANGELOG.md has no {version} release section",
    )
    require(
        read("RELEASE_ANNOUNCEMENT.md").startswith(f"# SLYNET {version} —"),
        f"RELEASE_ANNOUNCEMENT.md does not describe {version}",
    )


def assert_no_release_placeholders(version: str) -> None:
    checks: dict[str, Iterable[str]] = {
        "README.md": ("REPOSITORY-URL", "yourusername", "1.0.1 release gate"),
        "docs/dev-guides/setup.md": ("<repository_url>", "Initial Placeholder", "early stages"),
        "docs/README.md": ('host "0.0.0.0"', ':host "0.0.0.0"', "implements all the contrib modules"),
        "bundle/info.jdn": ('version "0.0.0"', 'description "sly trans '),
    }
    for path, forbidden in checks.items():
        text = read(path)
        for needle in forbidden:
            require(needle not in text, f"release-facing placeholder/stale text {needle!r} remains in {path}")

    readme = read("README.md")
    require(
        f"SLYNET {version}" in readme,
        f"README.md does not identify the current {version} release",
    )


def run_checked(argv: list[str], *, timeout: float = 10.0) -> subprocess.CompletedProcess[str]:
    env = os.environ.copy()
    env["JANET_PATH"] = f"{env.get('JANET_PATH', '')}:{ROOT}"
    return subprocess.run(
        argv,
        cwd=ROOT,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        timeout=timeout,
        check=False,
    )


def assert_direct_cli(version: str) -> None:
    help_result = run_checked(["janet", "slynet/cli.janet", "--help"])
    require(help_result.returncode == 0, f"direct CLI --help failed:\n{help_result.stdout}")
    require("Usage:" in help_result.stdout, "direct CLI --help did not render usage")

    version_result = run_checked(["janet", "slynet/cli.janet", "--version"])
    require(version_result.returncode == 0, f"direct CLI --version failed:\n{version_result.stdout}")
    require(version in version_result.stdout, f"direct CLI --version did not report {version}")


def assert_embedding_example() -> None:
    example = ROOT / "examples/embed-server.janet"
    require(example.is_file(), "executable embedding example is missing")
    require(os.access(example, os.X_OK), "examples/embed-server.janet must be executable")
    result = run_checked([str(example), "--check"])
    require(result.returncode == 0, f"embedding example --check failed:\n{result.stdout}")
    require(
        "embedding check passed" in result.stdout,
        "embedding example did not report successful API-v1 check",
    )


def free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


def wait_for_tcp(port: int, process: subprocess.Popen[str], timeout: float = 8.0) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if process.poll() is not None:
            output = process.stdout.read() if process.stdout else ""
            fail(f"direct CLI server exited before becoming ready (exit={process.returncode}):\n{output}")
        try:
            with socket.create_connection(("127.0.0.1", port), timeout=0.2):
                return
        except OSError:
            time.sleep(0.05)
    fail(f"direct CLI server did not become connectable on 127.0.0.1:{port}")


def assert_direct_tcp_startup() -> None:
    port = free_port()
    env = os.environ.copy()
    env["JANET_PATH"] = f"{env.get('JANET_PATH', '')}:{ROOT}"
    process = subprocess.Popen(
        ["janet", "slynet/cli.janet", "--tcp", "--host", "127.0.0.1", "--port", str(port)],
        cwd=ROOT,
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )
    try:
        wait_for_tcp(port, process)
    finally:
        process.terminate()
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=3)


def assert_publication_remote() -> None:
    result = subprocess.run(
        ["git", "remote", "get-url", "origin"],
        cwd=ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    require(result.returncode == 0 and result.stdout.strip(), "publication requires a configured origin remote")
    remote = result.stdout.strip()
    require(
        remote.startswith(("https://", "ssh://", "git@")),
        f"origin must be a publishable repository URL, got {remote!r}",
    )
    readme = read("README.md")
    identity = remote.removesuffix(".git")
    if identity.startswith("git@") and ":" in identity:
        identity = identity.split("@", 1)[1].replace(":", "/", 1)
    elif "://" in identity:
        identity = identity.split("://", 1)[1]
    require(
        remote in readme or identity in readme,
        "README.md must contain the configured publication repository identity",
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--require-remote",
        action="store_true",
        help="also require a real origin URL and publication-ready README",
    )
    args = parser.parse_args()

    version = project_version()
    assert_version_coherence(version)
    assert_no_release_placeholders(version)
    assert_direct_cli(version)
    assert_embedding_example()
    assert_direct_tcp_startup()
    if args.require_remote:
        assert_publication_remote()

    print(f"release-integrity: SLYNET {version} metadata and direct CLI checks passed")
    if not args.require_remote:
        print("release-integrity: publication remote intentionally checked by the separate publication gate")


if __name__ == "__main__":
    main()
