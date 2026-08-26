# PLAYWRIGHT_VERSION is required and must match @playwright/test in package.json5
# (see scripts/get_playwright_version.py). Example:
#   podman build --build-arg PLAYWRIGHT_VERSION="$(python3 scripts/get_playwright_version.py)" ...
ARG PLAYWRIGHT_VERSION
FROM mcr.microsoft.com/playwright:v${PLAYWRIGHT_VERSION}-noble
ARG PLAYWRIGHT_VERSION
LABEL org.opendatahub.playwright.version="${PLAYWRIGHT_VERSION}"

RUN npm install -g pnpm@10.8.0

WORKDIR /home/pwuser/tests/browser
USER pwuser

# This branch keeps package.json alongside package.json5; copy both so
# pnpm 10 resolves installs from package.json while version extraction uses json5.
COPY --chown=pwuser:pwuser package.json package.json5 pnpm-lock.yaml ./
RUN PNPM_CONFIG_fund=false pnpm install --frozen-lockfile

COPY --chown=pwuser:pwuser . .

# CI=true selects headless browser projects in playwright.config.ts.
ENV CI=true

ENTRYPOINT ["pnpm", "exec", "playwright", "test", "--project=chromium"]
