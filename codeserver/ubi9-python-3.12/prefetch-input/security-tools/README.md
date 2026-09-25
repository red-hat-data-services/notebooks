# Prefetched Code Server security tools

The Konflux PR and push pipelines fetch this RPM lockfile. It contains the
signed public UBI skopeo fix for CVE-2026-56853, containers-common, and the
runtime dependencies needed by the release base images. All four build
architectures are included. Repository IDs use the approved UBI names.

GHA already fetches the larger `../rhds/rpms.lock.yaml`. Keep skopeo and
containers-common versions, URLs and checksums synchronized between the two
lockfiles; other dependencies may use the release-specific GHA RPM versions.
The initial public UBI entries are taken from the rhoai-2.25 Code Server
RHDS lockfile. When updating skopeo, update its exact filename in
`Dockerfile.konflux.cpu` and test the installation with networking disabled.

The Dockerfile installs these local RPMs with remote repositories disabled
and `localpkg_gpgcheck=1`. Missing files, signatures or dependencies fail the
build instead of falling back to a network download. This does not make the
remaining hybrid Code Server build steps hermetic.
