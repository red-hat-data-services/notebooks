# Python CVE Resolution Guide

This guide documents the workflow for resolving CVEs in Python packages within the
OpenDataHub / RHOAI Notebooks images on the `rhoai-3.3` release branch.

> **Acknowledgment**: This workflow was contributed by Adriana Theodorakopoulou.
>
> **Note (rhoai-3.3):** On `main`, global floors live in `dependencies/constraints.txt`
> (plus optional `dependencies/overrides.txt`). This branch still uses
> `dependencies/cve-constraints.txt` and image-local `[tool.uv.override-dependencies]`
> only — there is no `overrides.txt` here yet.

## Overview

Python CVEs in notebook images can come from:
- **Direct dependencies**: Packages explicitly listed in `pyproject.toml`
- **Transitive dependencies**: Packages pulled in by direct dependencies

The resolution strategy differs based on which type is affected.

## Centralized dependency rules

Global lock floors live under `dependencies/` and are passed to `uv pip compile`
during `make refresh-lock-files`:

| File | uv flag | Purpose |
|------|---------|---------|
| `dependencies/cve-constraints.txt` | `--constraints` | Global version **floors** (`package>=X`) |
| `pyproject.toml` `[tool.uv.override-dependencies]` | (from pyproject) | **Image-specific** overrides when a floor loses resolver conflicts |

**Prefer `cve-constraints.txt` first.** Put shared floors in that file; put
subset-specific forced pins in individual `pyproject.toml` files.

### `cve-constraints.txt` structure

```text
# RHAIENG-XXXX: CVE-YYYY-ZZZZ short description
package>=fixed_version
```

Keep **one line and one comment per package** (most restrictive floor only).
Do not maintain a historical ledger of superseded CVE fixes.

### Branch policy

| Repo / branch | When to update `cve-constraints.txt` |
|---------------|--------------------------------------|
| `opendatahub-io/notebooks` `main` | Uses `constraints.txt` / lock-renewal; see upstream docs. |
| `red-hat-data-services/notebooks` `rhoai-x.y` | Audit proof of what the release enforces. **Keep updating** when backporting CVE fixes. |

### How it works

1. **Constraints file format** (requirements.txt style):
   ```text
   # RHAIENG-XXXX: CVE-YYYY-ZZZZ description
   package>=fixed_version
   ```

2. **Automatic application**: `scripts/pylocks_generator.py` (and the legacy
   `scripts/pylocks_generator.sh` for `aipcc-index`) pass `--constraints` for
   `dependencies/cve-constraints.txt` to lock generations.

3. **Override for conflicts**: When a floor is insufficient or loses resolver
   conflicts, use `override-dependencies` in a specific image's `pyproject.toml`.

### Adding a new CVE constraint

1. Add the constraint to `dependencies/cve-constraints.txt`:
   ```text
   # RHAIENG-XXXX: CVE-YYYY-ZZZZZ package_name vulnerability description
   # Upstream: https://github.com/...
   package_name>=fixed_version
   ```

2. Regenerate all lock files:
   ```bash
   make refresh-lock-files
   # or
   uv run scripts/pylocks_generator.py public-index
   ```

3. If resolution fails due to conflicts, add `override-dependencies` to the
   affected image's `pyproject.toml`.

## CVE Resolution Workflow

### Step 1: Identify the Package and Affected Images

1. Open the Jira ticket and identify the package name (e.g., "tornado")
2. Check which images are affected
3. Open linked ProdSec Jiras for the summary

### Step 2: Determine the Fixed Version

From the CVE summary, identify:
- **Affected versions**: e.g., "version 6.5.2 and below"
- **Fixed version**: e.g., "fixed in version 6.5.3"

### Step 3: Search for the Package in the Repository

```bash
# Search in pyproject.toml files
grep -r "tornado" --include="pyproject.toml" .

# Search in pylock.toml files
grep -r "tornado" --include="pylock.toml" .
```

Determine if it's a:
- **Direct dependency**: Found in `pyproject.toml`
- **Transitive dependency**: Only found in `pylock.toml`

### Step 4: Identify the Source of Transitive Dependencies

```bash
uv tree | grep -A5 -B5 tornado
uv tree --invert tornado
```

### Step 4.5: Verify Package Availability on the RH Index

Before attempting to fix the CVE, check that the fixed version is available on
the RH index (a version may exist on PyPI but not on AIPCC).

```bash
curl -sL "https://packages.redhat.com/api/pypi/public-rhai/rhoai/3.0/cpu-ubi9/simple/<package>/?format=json" \
  | python3 -c "
import json,sys
data = json.load(sys.stdin)
versions = sorted({f['filename'].split('-')[1] for f in data.get('files',[])})
print('\n'.join(versions))
"
```

If the fixed version is not on the RH index, request it via the
[AIPCC dashboard](https://dashboard.aipcc.redhat.com/package-request) and revisit
once it is available.

### Step 5: Resolve the CVE

#### Option A: Upgrade the Direct Dependency

Update the version in the image `pyproject.toml` when the direct dependency can
carry the fixed transitive version.

#### Option B: Use Centralized CVE Constraints

```text
# RHAIENG-XXXX: CVE-YYYY-ZZZZ description
package>=fixed_version
```

Add to `dependencies/cve-constraints.txt`, then regenerate locks.

#### Option C: Use Override Dependencies (Last Resort)

```toml
[tool.uv]
override-dependencies = [
    # RHAIENG-XXXX: CVE-YYYY-ZZZZ - override needed due to version conflict
    "package>=fixed_version",
]
```

Use sparingly — overrides force the version even against conflicting upper bounds.

### Step 6: Regenerate Lock Files and Build

```bash
make refresh-lock-files
make jupyter-datascience-ubi9-python-3.12
```

### Step 7: Validate the Fix

- **Downstream (Konflux):** clair-scan task logs — CVE absent after fix
- **Upstream (GHA):** Trivy vulnerability report — CVE absent after fix

Trivy is often more sensitive than Clair; validate production images against Konflux.

## Example: urllib3 conflict with odh-elyra

1. **Identify**: urllib3 CVE, affects workbench images with Elyra
2. **Conflict**: odh-elyra → appengine-python-standard requires `urllib3<2`
3. **Solution**: floor in `cve-constraints.txt` (when present) **and**
   `override-dependencies` on affected jupyter images so the resolver can ignore
   the transitive upper bound

## Best Practices

1. Always add to `cve-constraints.txt` first so the floor applies on every lock regen.
2. Use `override-dependencies` only for genuine conflicts constraints cannot resolve.
3. Document RHAIENG ticket, CVE ID, and rationale in comments.
4. Validate in both Trivy and Clair.
5. Prefer upgrading a direct dependency when that alone fixes the transitive CVE.

## Related Files

- `dependencies/cve-constraints.txt` — Global version floors for this branch
- `scripts/pylocks_generator.py` — Lock file generator (default Make/CI path)
- `scripts/pylocks_generator.sh` — Legacy generator kept for `INDEX_MODE=aipcc-index`
- `pyproject.toml` — Direct dependencies and override-dependencies
- `pylock.toml` — Generated public-index lock files

## Useful Commands

```bash
# Regenerate all lock files (public-index default → Python generator)
make refresh-lock-files

# Explicit public-index
uv run scripts/pylocks_generator.py public-index

# Targeted directory
uv run scripts/pylocks_generator.py public-index jupyter/datascience/ubi9-python-3.12

# Legacy AIPCC hardcoded indexes (still shell)
make refresh-lock-files INDEX_MODE=aipcc-index

# Check dependency tree
uv tree
uv tree --invert package-name
```
