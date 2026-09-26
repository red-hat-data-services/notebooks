# Prefetched Code Server security tools

The Konflux PR and push pipelines fetch this RPM lockfile. It contains the
signed public UBI skopeo fix for CVE-2026-56853, containers-common, and the
runtime dependencies needed by the release base images. All four build
architectures are included. Repository IDs use the approved UBI names.

GHA already fetches the larger `../rhds/rpms.lock.yaml`. Keep skopeo and
containers-common versions, URLs and checksums synchronized between the two
lockfiles; other dependencies may use the release-specific GHA RPM versions.
The initial public UBI entries are taken from the rhoai-2.25 Code Server
RHDS lockfile. When updating skopeo, update the minimum version in
`Dockerfile.konflux.cpu` and test the installation with networking disabled.

The Dockerfile uses normal DNF dependency resolution. The build must expose
Hermeto-generated repository definitions pointing to the prefetched RPMs;
the Makefile mounts these definitions at `/etc/yum.repos.d`. RPM signature
checks remain enabled in those repositories. This does not make the
remaining hybrid Code Server build steps hermetic.
