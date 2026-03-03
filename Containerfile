ARG CONTAINER_VERSION=13.3
FROM docker.io/gautada/debian:${CONTAINER_VERSION} AS container

ARG IMAGE_NAME=homepage

# ╭――――――――――――――――――――╮
# │ METADATA           │
# ╰――――――――――――――――――――╯
LABEL org.opencontainers.image.title="${IMAGE_NAME}"
LABEL org.opencontainers.image.description="A homepage dashboard container."
LABEL org.opencontainers.image.url="https://hub.docker.com/r/gautada/homepage"
LABEL org.opencontainers.image.source="https://github.com/gautada/homepage"
LABEL org.opencontainers.image.license="Upstream"

# ╭――――――――――――――――――――╮
# │ PACKAGES           │
# ╰――――――――――――――――――――╯
# Install build dependencies and Node.js 22 via NodeSource.
# - git: required to clone the homepage source at build time
# - jq: required at runtime by version.sh and latest.sh health scripts
# - curl: already in base; used by NodeSource setup + latest.sh
# - nodejs (22.x): runtime and build tool for homepage (Next.js app)
# - corepack: bundled with Node 22; provides pnpm without a separate install
# hadolint ignore=DL3008
RUN apt-get update \
 && apt-get install -y --no-install-recommends git jq \
 && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && corepack enable \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

# ╭――――――――――――――――――――╮
# │ USER               │
# ╰――――――――――――――――――――╯
# Rename the base debian user to homepage.
# Follows the same pattern as other gautada containers.
ARG USER=homepage
RUN /usr/sbin/usermod -l $USER debian \
 && /usr/sbin/usermod -d /home/$USER -m $USER \
 && /usr/sbin/groupmod -n $USER debian \
 && /bin/echo "$USER:$USER" | /usr/sbin/chpasswd

# ╭――――――――――――――――――――╮
# │ CONTAINER          │
# ╰――――――――――――――――――――╯
# Clone homepage at the pinned release tag, build the Next.js app,
# then wire up all configmap symlinks so runtime config can be
# injected via volume mounts at /mnt/volumes/configmaps/.
WORKDIR /app
RUN IMAGE_VERSION=$(curl -sL "https://api.github.com/repos/gethomepage/homepage/releases/latest" \
    | jq -r '.tag_name' \
    | sed 's/^v//' \
    | tr -d '[:space:]') \
 && { [ -n "$IMAGE_VERSION" ] && [ "$IMAGE_VERSION" != "null" ] \
      || { echo "ERROR: failed to resolve latest homepage version from GitHub API" >&2; exit 1; }; } \
 && echo "Building with homepage ${IMAGE_VERSION}" \
 && git config --global advice.detachedHead false \
 && git clone --branch "v${IMAGE_VERSION}" \
              https://github.com/gethomepage/homepage.git . \
 && pnpm install \
 && pnpm build \
 && mv config config~ \
 && mkdir -p config config/logs /etc/container/configmaps \
 && ln -fsv /etc/container/configmaps/bookmarks.yaml   config/bookmarks.yaml \
 && ln -fsv /etc/container/configmaps/docker.yaml      config/docker.yaml \
 && ln -fsv /etc/container/configmaps/kubernetes.yaml  config/kubernetes.yaml \
 && ln -fsv /etc/container/configmaps/services.yaml    config/services.yaml \
 && ln -fsv /etc/container/configmaps/settings.yaml    config/settings.yaml \
 && ln -fsv /etc/container/configmaps/widgets.yaml     config/widgets.yaml \
 && ln -fsv /etc/container/configmaps/custom.css       config/custom.css \
 && ln -fsv /etc/container/configmaps/custom.js        config/custom.js \
 && ln -fsv /mnt/volumes/configmaps/bookmarks.yaml     /etc/container/configmaps/bookmarks.yaml \
 && ln -fsv /mnt/volumes/configmaps/docker.yaml        /etc/container/configmaps/docker.yaml \
 && ln -fsv /mnt/volumes/configmaps/kubernetes.yaml    /etc/container/configmaps/kubernetes.yaml \
 && ln -fsv /mnt/volumes/configmaps/services.yaml      /etc/container/configmaps/services.yaml \
 && ln -fsv /mnt/volumes/configmaps/settings.yaml      /etc/container/configmaps/settings.yaml \
 && ln -fsv /mnt/volumes/configmaps/widgets.yaml       /etc/container/configmaps/widgets.yaml \
 && ln -fsv /mnt/volumes/configmaps/custom.css         /etc/container/configmaps/custom.css \
 && ln -fsv /mnt/volumes/configmaps/custom.js          /etc/container/configmaps/custom.js \
 && ln -fsv /mnt/volumes/container/images              /app/public/images \
 && mkdir -p /mnt/volumes/configmaps
RUN chown -R $USER:$USER /app /home/$USER

# ╭――――――――――――――――――――╮
# │ CONFIG             │
# ╰――――――――――――――――――――╯
# Default configmap files. These are the minimum configs required to start
# the homepage server. In production, /mnt/volumes/configmaps/ is supplied
# by a k8s volume mount which replaces these defaults with live configs.
COPY configmaps/ /mnt/volumes/configmaps/

# ╭――――――――――――――――――――╮
# │ VERSION            │
# ╰――――――――――――――――――――╯
# Provides /usr/bin/container-version — returns the homepage app version
# by reading package.json. Used by CICD and appversion-check.sh.
COPY version.sh /usr/bin/container-version
RUN chmod +x /usr/bin/container-version

# ╭――――――――――――――――――――╮
# │ LATEST             │
# ╰――――――――――――――――――――╯
# Provides /usr/bin/container-latest — fetches the latest release tag
# from gethomepage/homepage on GitHub (strips 'v' prefix).
# Used by appversion-check.sh health drop-in.
COPY latest.sh /usr/bin/container-latest
RUN chmod +x /usr/bin/container-latest

# ╭――――――――――――――――――――╮
# │ HEALTH             │
# ╰――――――――――――――――――――╯
# appversion-check: verifies running version matches latest GitHub release.
# homepage-running: verifies homepage is responding on port 8080.
# Both drop into /etc/container/health.d/ (run by container-health from base).
COPY appversion-check.sh /etc/container/health.d/appversion-check
RUN chmod +x /etc/container/health.d/appversion-check
COPY homepage-running.sh /etc/container/health.d/homepage-running
RUN chmod +x /etc/container/health.d/homepage-running

# ╭――――――――――――――――――――╮
# │ ENTRYPOINT         │
# ╰――――――――――――――――――――╯
# s6 service definition: starts homepage via pnpm on container launch.
COPY homepage.s6 /etc/services.d/homepage/run
RUN chmod +x /etc/services.d/homepage/run

WORKDIR /app
