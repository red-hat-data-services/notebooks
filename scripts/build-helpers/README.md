# Local workbench build helpers

Scripts to build and run workbench container images locally with **podman** and **gmake**, without pushing to a registry.

## Prerequisites

- `podman` (with podman machine running on macOS)
- `gmake` (GNU Make — use `gmake` on macOS, not BSD `make`)
- `go` (for `bin/buildinputs`, built automatically by the Makefile)
- `curl`

For **subscription-backed variants** (e.g. `rstudio rhel9`):

- Red Hat account with access to `registry.redhat.io`
- Activation key: set `RH_ORG` and `RH_ACTIVATION_KEY`

## Quick start

From the repository root:

```bash
# List registered workbenches
./scripts/build-helpers/build-local.sh --list

# RStudio on CentOS Stream 9 (no subscription)
./scripts/build-helpers/build-local.sh rstudio c9s build
./scripts/build-helpers/build-local.sh rstudio c9s run

# RStudio on RHEL 9 (subscription required, uses Dockerfile.konflux.cpu)
export RH_ORG="your-org-id"
export RH_ACTIVATION_KEY="your-activation-key"
./scripts/build-helpers/build-local.sh rstudio rhel9 all
./scripts/build-helpers/build-local.sh rstudio rhel9 run-nbprefix
```

Open in browser:

| Workbench | Variant | URL |
|-----------|---------|-----|
| rstudio | c9s / rhel9 | http://localhost:8888/rstudio/ |
| codeserver | ubi9 | http://localhost:8787/ (when enabled) |

## Commands

| Command | Description |
|---------|-------------|
| `setup` | Prepare environment (pull base image, or register RH subscription) |
| `verify` | Confirm prerequisites before build |
| `build` | Build the selected image |
| `run` | Start the built container interactively |
| `run-nbprefix` | Run with `NB_PREFIX` for ingress routing tests |
| `all` | `setup` → `verify` → `build` |
| `cleanup` | Remove local entitlement certs (subscription variants) |

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `IMAGE_REGISTRY` | `localhost/rhoai-local` | Image name prefix |
| `RELEASE` | `localtest` | Release tag segment |
| `HOST_PORT` | container port | Host port for `run` |
| `IMAGE` | auto-detect | Exact `repo:tag` to run (skips lookup) |
| `RH_ORG` | — | Red Hat org ID (subscription variants) |
| `RH_ACTIVATION_KEY` | — | Activation key name (subscription variants) |
| `REPO_ROOT` | auto | Path to notebooks repo root |

Built image tag pattern:

```text
${IMAGE_REGISTRY}:${MAKE_TARGET}-${RELEASE}_YYYYMMDD
```

Example: `localhost/rhoai-local:rstudio-rhel9-python-3.11-localtest_20260618`

## Layout

```text
scripts/build-helpers/
├── README.md                 # this file
├── build-local.sh            # CLI entry point
├── lib/
│   └── common.sh             # podman, gmake, subscription, build, run
└── workbenches/
    ├── rstudio.sh            # RStudio: c9s, rhel9
    └── codeserver.sh         # Code Server scaffold (ubi9)
```

## Registered workbenches

### `rstudio`

| Variant | Subscription | Dockerfile | Build path |
|---------|--------------|------------|------------|
| `c9s` | No | `Dockerfile.cpu` | `gmake rstudio-c9s-python-3.11` |
| `rhel9` | Yes | `Dockerfile.konflux.cpu` | Direct `podman build` via `sandbox.py` + `build-args/cpu.conf` |

RHEL9 builds match the Konflux pipeline layout:

- **Dockerfile:** `rstudio/rhel9-python-3.11/Dockerfile.konflux.cpu`
- **Build args:** `rstudio/rhel9-python-3.11/build-args/cpu.conf` (`BASE_IMAGE`, `RSTUDIO_SOURCE_CODE`)
- **Entitlements:** mounted into the build so `subscription-manager` can enable codeready-builder

When both RHEL subscription repos and injected UBI repos are visible, `Dockerfile.konflux.cpu` disables UBI for the flexiblas install step only.

### `codeserver` (scaffold)

| Variant | Subscription | Make target | Status |
|---------|--------------|-------------|--------|
| `ubi9` | No* | `codeserver-ubi9-python-3.12` | Not validated — `workbench_pre_build` blocks build until tested |

\* Set `NEEDS_SUBSCRIPTION=1` in `workbenches/codeserver.sh` if your build requires RH entitlements.

## Adding a new workbench

1. Create `workbenches/<name>.sh` with:

```bash
WORKBENCH_ID=mybench
WORKBENCH_DESCRIPTION="Short description"
WORKBENCH_VARIANTS="variant-a variant-b"

workbench_configure_variant() {
  local variant="$1"
  case "${variant}" in
    variant-a)
      VARIANT_PYTHON_VERSION=3.12
      MAKE_TARGET="mybench-variant-a-python-${VARIANT_PYTHON_VERSION}"
      BASE_IMAGE="..."
      VOLUME_NAME="mybench-variant-a-home"
      CONTAINER_PORT=8888
      RUN_PATH="/"
      NB_PREFIX_NOTEBOOK="my-notebook"
      NEEDS_SUBSCRIPTION=0   # or 1
      # For Konflux-style builds (optional):
      # USE_DIRECT_BUILD=1
      # DOCKERFILE="path/to/Dockerfile.konflux.cpu"
      # BUILD_ARGS_FILE="path/to/build-args/cpu.conf"
      ;;
  esac
}
```

2. Optional hooks (define any that you need):

| Hook | When |
|------|------|
| `workbench_pre_setup` | Before subscription / base image pull |
| `workbench_post_setup` | After setup |
| `workbench_pre_verify` | Before verify |
| `workbench_post_verify` | After verify |
| `workbench_pre_build` | Before build (use to gate unfinished workbenches) |
| `workbench_post_build` | After successful build |
| `workbench_extra_build_args` | Emit extra `--build-arg` lines for direct builds |

3. Verify it appears in `--list` and test:

```bash
./scripts/build-helpers/build-local.sh mybench variant-a verify
./scripts/build-helpers/build-local.sh mybench variant-a build
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `This system has no repositories available through subscriptions` | Run `rstudio rhel9 setup` first; re-run `verify` |
| flexiblas RHEL vs UBI conflict on rhel9 build | Ensure entitlements are mounted; Konflux Dockerfile disables UBI repos when `subscription-manager identity` succeeds |
| `gmake` target not found | Check `VARIANT_PYTHON_VERSION` matches an existing Makefile target (c9s only) |
| Slow build on Apple Silicon | Expected — images build for `linux/amd64` |

## Cleanup

```bash
./scripts/build-helpers/build-local.sh rstudio rhel9 cleanup
```

Removes `entitlement/` and `consumer/` under the repo root and resets podman VM mounts.
