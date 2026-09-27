# CI failure triage (`rhoai-2.25`)

Short playbook for recurring GitHub Actions / hermetic-build failures on the
`rhoai-2.25` branch. Prefer this over one-off Dockerfile workarounds when the
symptom matches a known class below.

## Hermeto / DNF: RPM lock pins out of date

### Symptom

During a codeserver (or other hermetic) image build, `dnf install` fails with a
package conflict similar to:

```text
Error:
 Problem: cannot install both nodejs-1:22.23.1-1.module+… from ubi-9-for-*-appstream-rpms
 and nodejs-1:22.23.1-2.module+… from @System
  - package nodejs-devel-1:22.23.1-1.module+… requires nodejs(…) = 1:22.23.1-1.module+…
  - conflicting requests
(try to add '--allowerasing' …)
```

Repo IDs in the log often look like `ubi-9-for-x86_64-appstream-rpms` (hermeto /
cachi2 overlay), not the image’s default `ubi-9-appstream-rpms`.

### What it usually means

Build CI mounts locked Hermeto RPM repos over `/etc/yum.repos.d/` (from
`cachi2/output/deps/rpm/<arch>/repos.d/`, generated from committed
`rpms.lock.yaml`). Those locks pin exact NEVRs.

Meanwhile the floating base image (for example
`registry.access.redhat.com/ubi9/python-312:latest`) may already ship a **newer**
build of the same package (for example `nodejs` `22.23.1-2` on `@System`).

DNF then tries to install a locked `*-devel` (or related) package that requires
the **older** NEVR and refuses to replace the newer base package without
`--allowerasing`.

So this is usually **stale Hermeto RPM pins**, not a broken Dockerfile `dnf`
line and not a one-off “add `--allowerasing`” product fix.

### Fix

Relock RPMs so `rpms.lock.yaml` matches current UBI content, then merge that PR
before retrying the image build.

**Difference from `main`:** on `rhoai-2.25`, codeserver is the only
RPM-prefetch / Hermeto consumer and it uses public UBI — no RHEL subscription
is required for RHDS lock regen. On `main`, RHDS renewal can still need
subscription secrets.

1. Run the **RPM Lock Files Renewal Action** workflow
   (`.github/workflows/rpms-lock-renewal.yaml`) via **Actions → workflow_dispatch**.
2. Inputs for this branch:
   - `variant`: `rhds` (downstream / RHOAI)
   - `branch`: `rhoai-2.25`
   - Leave subscription / git-crypt secrets unset (public UBI path).
3. Review and merge the automated PR (label `automated-rpms-lockfile-update`).
   On `rhoai-2.25` today that typically updates
   `codeserver/ubi9-python-3.12/prefetch-input/rhds/rpms.lock.yaml`.

Local equivalent (from repo root, public UBI — no subscription required on this
branch):

```bash
./scripts/lockfile-generators/create-rpm-lockfile.sh \
  --rpm-input codeserver/ubi9-python-3.12/prefetch-input/rhds/rpms.in.yaml
```

Do **not** fold this into pylock / `piplock-renewal` PRs; keep RPM lock renewals
separate.

### Related reading

- Codeserver hermetic / prefetch notes:
  [`codeserver/ubi9-python-3.12/README.md`](../codeserver/ubi9-python-3.12/README.md)
- Lockfile generators:
  [`scripts/lockfile-generators/README.md`](../scripts/lockfile-generators/README.md)

## TrustyAI: PyArrow source builds

Read the first native-build error, not only uv's final missing-module hint.
On ppc64le, a failed Arrow C++ link (`cannot find -latomic`) previously skipped
the rest of an `&&` chain without stopping `devel_env_setup.sh`. The later
locked install then tried to build PyArrow again, masking the original error.
GCC toolset 13 needs `gcc-toolset-13-libatomic-devel` for the linker input.

PyArrow's CMake interpreter must match uv's `/opt/app-root` environment.
`ModuleNotFoundError: Cython` can mean CMake selected `/usr/bin/python3.12`,
even when Cython is installed in the virtual environment. Pass
`cmake.define.Python3_EXECUTABLE` through the build backend's config settings;
adding more build dependencies does not fix the interpreter mismatch.

The Arrow portion can be tested on AMD64 without building PyTorch. In a clean
UBI Python 3.12 container, install GCC toolset 13 (including its libatomic devel
package), uv 0.8.12, CMake and Ninja, activate the toolset, and run:

```bash
export CMAKE_POLICY_VERSION_MINIMUM=3.5
bash jupyter/trustyai/ubi9-python-3.12/build_pyarrow.sh /path/to/arrow-checkout /wheelsdir
```

Use the Arrow tag matching `pylock.toml`. Validate the resulting wheel in a
separate runtime container without the C++ install tree. Check Compute,
Dataset, Parquet compression and Hugging Face `datasets`, then apply the exact
Dockerfile locked-install commands and verify that they retain the wheel.
AMD64 validates this shared build sequence; ppc64le still needs native CI
validation for architecture-specific compiler and linker behavior.

Keep PyArrow's Python build dependencies in `whl-cache`. Installing LibCST
again in the final stage triggers a Rust build on ppc64le, where no public
wheel is available and the runtime has no Rust compiler. The final locked
install uses the explicit `/root/.cache/uv` cache; its inherited
`HOME` is `/opt/app-root/src`, unlike the builder's `/root`. Validate with a
runtime lacking Cython, LibCST and the Python build backends, not a copy of the
builder environment. The separate debugpy source rebuild remains intentional.
Do not add `--no-build` to this uv 0.8.12 pylock install: it rejects source-only
lock entries such as `kfp-server-api` even when their built wheels are cached.

## Other failure classes (pointers)

| Symptom | Likely cause | Direction |
| --- | --- | --- |
| Podman `runroot must be set` | Incomplete `storage.conf` in CI | Set explicit `runroot` in `ci/cached-builds/storage.conf` |
| Kind / papermill timeouts on qemu arches | Slow startup under emulation | Probe / wait timeouts (image or test harness) |

When unsure, treat hermetic `dnf` NEVR conflicts as **relock RPMs first**, then
re-evaluate.
