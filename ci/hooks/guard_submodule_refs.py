#!/usr/bin/env python3
"""Guard against accidental git submodule reference bumps.

Developers often bump submodule pointers unintentionally when switching
branches without running ``git submodule update --init --recursive --force``.
This script provides two operating modes so that both local pre-commit hooks
and CI workflows can catch these accidents early.

Local mode (pre-commit commit-msg stage)
----------------------------------------
  guard_submodule_refs.py <commit-msg-file>

  * Reads submodule paths from ``.gitmodules`` via ``git config``.
  * Checks whether any submodule path appears in ``git diff --cached``.
  * If a submodule changed, the commit is allowed **only** when:
      - the commit message contains ``[submodule-update]`` (case-insensitive), OR
      - the environment variable ``ALLOW_SUBMODULE_CHANGE=1`` is set.
  * Otherwise exits 1 with a human-friendly warning.

CI mode
-------
  guard_submodule_refs.py --ci --base-ref <ref>

  * Walks every commit in ``<base-ref>..HEAD``.
  * For each commit that touches a submodule path, checks its message
    for ``[submodule-update]``.
  * Reports **all** offending commits and exits 1 if any lack the marker.
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _run(cmd: list[str], **kwargs) -> subprocess.CompletedProcess[str]:
    """Run a command, returning its CompletedProcess (text mode)."""
    return subprocess.run(cmd, capture_output=True, text=True, check=False, **kwargs)


def get_submodule_paths() -> list[str] | None:
    """Return the list of submodule paths declared in ``.gitmodules``.

    Returns ``None`` when ``git config`` exits non-zero so that callers
    can distinguish "no submodules" (empty list) from "git failed" and
    fail closed.
    """
    result = _run(["git", "config", "--file", ".gitmodules", "--get-regexp", r"^submodule\..*\.path$"])
    if result.returncode != 0:
        # git config returns 1 when the key is not found (no submodules)
        # and >1 on actual errors (malformed file, missing file, etc.).
        if result.returncode == 1 and not result.stderr.strip():
            return []
        print(f"❌  Failed to read .gitmodules: {result.stderr.strip()}", file=sys.stderr)
        return None
    paths: list[str] = []
    for line in result.stdout.strip().splitlines():
        # Each line looks like: submodule.<name>.path <path>
        parts = line.split(None, 1)
        if len(parts) == 2:
            paths.append(parts[1])
    return paths


# ---------------------------------------------------------------------------
# Local (pre-commit) mode
# ---------------------------------------------------------------------------


def _changed_submodules_staged(submodule_paths: list[str]) -> list[str]:
    """Return submodule paths that appear in the staged diff."""
    result = _run(["git", "diff", "--cached", "--name-only"])
    if result.returncode != 0:
        return []
    changed_files = set(result.stdout.strip().splitlines())
    return [p for p in submodule_paths if p in changed_files]


def check_local(commit_msg_file: str, submodule_paths: list[str]) -> int:
    """Run the local pre-commit check. Returns 0 on success, 1 on failure."""
    changed = _changed_submodules_staged(submodule_paths)
    if not changed:
        return 0

    # --- Escape hatches ---
    if os.environ.get("ALLOW_SUBMODULE_CHANGE") == "1":
        print("✅  ALLOW_SUBMODULE_CHANGE=1 set — submodule change permitted.")
        return 0

    try:
        with open(commit_msg_file, encoding="utf-8") as fh:
            commit_msg = fh.read()
    except OSError as exc:
        print(f"❌  Cannot read commit-message file: {exc}", file=sys.stderr)
        return 1

    if re.search(r"\[submodule-update\]", commit_msg, re.IGNORECASE):
        print("✅  [submodule-update] marker found — submodule change permitted.")
        return 0

    # --- Block the commit ---
    paths_list = "\n".join(f"   • {p}" for p in changed)
    print(
        f"⚠️   Submodule reference change detected!\n"
        f"\n"
        f"{paths_list}\n"
        f"\n"
        f"This usually happens when you switch branches without running:\n"
        f"   git submodule update --init --recursive --force\n"
        f"\n"
        f"If this change is intentional, either:\n"
        f"   1. Add [submodule-update] anywhere in your commit message, or\n"
        f"   2. Re-run with:  ALLOW_SUBMODULE_CHANGE=1 git commit ...\n",
        file=sys.stderr,
    )
    return 1


# ---------------------------------------------------------------------------
# CI mode
# ---------------------------------------------------------------------------


def _commits_in_range(base_ref: str) -> list[str] | None:
    """Return the list of commit SHAs in *base_ref*..HEAD (oldest first).

    Returns ``None`` when ``git rev-list`` exits non-zero (e.g. the ref
    cannot be resolved) so that callers can distinguish "no commits"
    (empty list) from "git failed" and fail closed.
    """
    result = _run(["git", "rev-list", "--reverse", f"{base_ref}..HEAD"])
    if result.returncode != 0:
        print(f"❌  Failed to list commits: {result.stderr.strip()}", file=sys.stderr)
        return None
    return [s for s in result.stdout.strip().splitlines() if s]


def _commit_changed_files(sha: str) -> list[str]:
    """Return the files changed by a single commit."""
    result = _run(["git", "diff-tree", "-m", "--no-commit-id", "-r", "--name-only", sha])
    if result.returncode != 0:
        return []
    return result.stdout.strip().splitlines()


def _commit_message(sha: str) -> str:
    """Return the full commit message for *sha*, or ``""`` on failure."""
    result = _run(["git", "log", "-1", "--format=%B", sha])
    return result.stdout if result.returncode == 0 else ""


def check_ci(base_ref: str, submodule_paths: list[str]) -> int:
    """Run the CI check across all commits in the PR range."""
    commits = _commits_in_range(base_ref)
    if commits is None:
        # git rev-list failed — fail closed rather than silently passing.
        return 1
    if not commits:
        print("✅  No commits in range — nothing to check.")
        return 0

    submodule_set = set(submodule_paths)
    offenders: list[tuple[str, list[str]]] = []

    for sha in commits:
        changed = _commit_changed_files(sha)
        touched = [f for f in changed if f in submodule_set]
        if not touched:
            continue
        msg = _commit_message(sha)
        if re.search(r"\[submodule-update\]", msg, re.IGNORECASE):
            continue
        offenders.append((sha, touched))

    if not offenders:
        print("✅  All submodule changes (if any) are marked with [submodule-update].")
        return 0

    print("❌  The following commits change submodule references without", file=sys.stderr)
    print("   the [submodule-update] marker in their commit message:\n", file=sys.stderr)
    for sha, paths in offenders:
        short = sha[:10]
        subject = _commit_message(sha).split("\n", 1)[0].strip()
        print(f"   • {short}  {subject}", file=sys.stderr)
        for p in paths:
            print(f"        — {p}", file=sys.stderr)
    print("", file=sys.stderr)
    print(
        "If the submodule change is intentional, amend the commit(s) to include\n"
        "[submodule-update] in the message.  Otherwise, run:\n"
        "   git submodule update --init --recursive --force\n"
        "and amend the commit(s) to remove the submodule diff.\n",
        file=sys.stderr,
    )
    return 1


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def create_parser() -> argparse.ArgumentParser:
    """Build and return the CLI argument parser."""
    parser = argparse.ArgumentParser(
        description="Guard against accidental submodule reference bumps.",
    )
    parser.add_argument(
        "commit_msg_file",
        nargs="?",
        default=None,
        help="Path to the commit-message file (local/pre-commit mode).",
    )
    parser.add_argument(
        "--ci",
        action="store_true",
        help="Run in CI mode (check all commits in a PR range).",
    )
    parser.add_argument(
        "--base-ref",
        dest="base_ref",
        default=None,
        help="Base ref for CI mode (e.g. origin/main).",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = create_parser()
    args = parser.parse_args(argv)

    submodule_paths = get_submodule_paths()
    if submodule_paths is None:
        # git config failed unexpectedly — fail closed.
        return 1
    if not submodule_paths:
        print("✅  No submodules found in .gitmodules — nothing to guard.")
        return 0

    if args.ci:
        if not args.base_ref:
            parser.error("--base-ref is required in CI mode")
        return check_ci(args.base_ref, submodule_paths)

    if args.commit_msg_file is None:
        parser.error("commit_msg_file is required in local mode (or use --ci)")

    return check_local(args.commit_msg_file, submodule_paths)


if __name__ == "__main__":
    raise SystemExit(main())
