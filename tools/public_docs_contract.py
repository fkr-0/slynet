#!/usr/bin/env python3
"""Fail when public SLYNET docs advertise symbols that the tree does not expose."""

from __future__ import annotations

import pathlib
import re
import sys
from urllib.parse import urlparse


ROOT = pathlib.Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def fail(message: str) -> None:
    print(f"public-docs-contract: ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def documented_emacs_commands() -> list[tuple[str, str]]:
    rows: list[tuple[str, str]] = []
    row_re = re.compile(r"^\| `([^`]+)` \| `([^`]+)` \|", re.MULTILINE)
    for key, command in row_re.findall(read("README.md")):
        if command.startswith("slynet-"):
            rows.append((key, command))
    return rows


def check_emacs_commands() -> None:
    source = read("emacs/slynet.el")
    rows = documented_emacs_commands()
    require(rows, "README.md contains no public SLYNET command table rows")
    for key, command in rows:
        require(
            re.search(rf"\(defun\s+{re.escape(command)}(?:\s|\()", source) is not None
            or re.search(rf"\(cl-defun\s+{re.escape(command)}(?:\s|\()", source) is not None,
            f"README command {command!r} has no defun in emacs/slynet.el",
        )
        suffix = key.removeprefix("C-c C-s ")
        if suffix != key:
            require(
                f'(define-key map (kbd "{suffix}") #\'{command})' in source,
                f"README key {key!r} does not match slynet-command-map for {command}",
            )


def documented_api_symbols() -> list[str]:
    table = read("docs/EMBEDDING_API.md")
    return re.findall(r"^\| `([^`]+)` \|", table, re.MULTILINE)


def check_embedding_api() -> None:
    source = read("slynet/api.janet")
    symbols = documented_api_symbols()
    require(symbols, "EMBEDDING_API.md contains no public API symbol rows")
    for symbol in symbols:
        pattern = rf"\((?:defn|def|var)\s+{re.escape(symbol)}(?:\s|\[|\")"
        require(
            re.search(pattern, source) is not None,
            f"documented Janet API symbol {symbol!r} is not defined in slynet/api.janet",
        )
        require(
            re.search(rf":{re.escape(symbol)}(?:\s|\n)", source) is not None,
            f"documented Janet API symbol {symbol!r} is not present in export-api",
        )


def check_pages_identity() -> None:
    cname = read("docs/CNAME").strip()
    config = read("docs/_config.yml")
    match = re.search(r"^url:\s*(\S+)\s*$", config, re.MULTILINE)
    require(match is not None, "docs/_config.yml has no url")
    host = urlparse(match.group(1)).hostname
    require(host == cname, f"Pages URL host {host!r} != docs/CNAME {cname!r}")
    require(
        "https://github.com/fkr-0/slynet" in read("README.md"),
        "README.md does not identify the canonical public repository",
    )


def main() -> None:
    check_emacs_commands()
    check_embedding_api()
    check_pages_identity()
    print(
        "public-docs-contract: "
        f"{len(documented_emacs_commands())} Emacs commands, "
        f"{len(documented_api_symbols())} Janet API symbols, and Pages identity passed"
    )


if __name__ == "__main__":
    main()
