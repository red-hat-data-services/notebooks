# Road not taken: a node:22-slim base + `npx playwright install --with-deps chromium`
# would cut the image from ~2.9 GB to ~600 MB. We keep the full Playwright base so browser
# versions stay in sync with @playwright/test, and so GHA (@codeserver via
# build-notebooks-TEMPLATE) and Jenkins (quay.io/opendatahub/workbench-images-tests) share
# one image definition.
#
# PLAYWRIGHT_VERSION is required and must match @playwright/test in package.json5
# (see scripts/get_playwright_version.py). Example:
#   podman build --build-arg PLAYWRIGHT_VERSION="$(python3 scripts/get_playwright_version.py)" ...
ARG PLAYWRIGHT_VERSION
FROM mcr.microsoft.com/playwright:v${PLAYWRIGHT_VERSION}-noble
ARG PLAYWRIGHT_VERSION
LABEL org.opendatahub.playwright.version="${PLAYWRIGHT_VERSION}"

# Keep in sync with packageManager in package.json5 on this branch.
RUN npm install -g pnpm@10.8.0

WORKDIR /home/pwuser/tests/browser
USER pwuser

# This branch keeps a generated package.json alongside package.json5; copy both so
# pnpm 10 resolves installs from package.json while version extraction still uses json5.
COPY --chown=pwuser:pwuser package.json package.json5 pnpm-lock.yaml ./
RUN PNPM_CONFIG_fund=false pnpm install --frozen-lockfile

COPY --chown=pwuser:pwuser . .

# CI=true selects headless browser projects (chromium, firefox, webkit) in playwright.config.ts.
# Without it, the config falls back to a "Google Chrome" project that expects a branded Chrome
# binary at /opt/google/chrome/chrome, which is not present in this image.
ENV CI=true

ENTRYPOINT ["pnpm", "exec", "playwright", "test", "--project=chromium"]
