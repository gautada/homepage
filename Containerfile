<<<<<<< HEAD
ARG ALPINE_VERSION=3.22
FROM docker.io/gautada/alpine:$ALPINE_VERSION as CONTAINER

ARG IMAGE_NAME=homepage
ARG IMAGE_VERSION=1.4.6

# ╭――――――――――――――――――――╮
# │ METADATA           │
# ╰――――――――――――――――――――╯
LABEL org.opencontainers.image.title="${IMAGE_NAME}"
# LABEL maintainer="Adam Gautier <adam@gautier.org>"
LABEL org.opencontainers.image.description="A homepage dashboard container."
LABEL org.opencontainers.image.url="https://hub.docker.com/r/gautada/homepage"
LABEL org.opencontainers.image.source="https://github.com/gautada/homepage"
LABEL org.opencontainers.image.version="${IMAGE_VERSION}"
LABEL org.opencontainers.image.license="Upstream"

# ╭――――――――――――――――――――╮
# │ USER               │
# ╰――――――――――――――――――――╯
# SHELL ["/bin/ash", "-o", "pipefail", "-c"]
ARG USER=homepage
RUN /usr/sbin/usermod -l $USER alpine \
 && /usr/sbin/usermod -d /home/$USER -m $USER \
 && /usr/sbin/groupmod -n $USER alpine \
 && /bin/echo "$USER:$USER" | /usr/sbin/chpasswd

# ╭――――――――――――――――――――╮
# │ PRIVILEGE          │
# ╰――――――――――――――――――――╯
# COPY privileges /etc/container/privileges

# ╭――――――――――――――――――――╮
# │ BACKUP             │
# ╰――――――――――――――――――――╯
# COPY backup /etc/container/backup

# ╭――――――――――――――――――――╮
# │ ENTRYPOINT         │
# ╰――――――――――――――――――――╯
# COPY entrypoint /etc/container/entrypoint

# ╭――――――――――――――――――――╮
# │ CONTAINER          │
# ╰――――――――――――――――――――╯
RUN /sbin/apk add --no-cache pnpm yamllint
WORKDIR /
RUN echo "${IMAGE_VERSION}" && git config --global advice.detachedHead false \
 && git clone --branch "v${IMAGE_VERSION}" https://github.com/gethomepage/homepage.git app
WORKDIR /app
RUN pnpm install \
 && pnpm build \
 && mv config config~ \
 && mkdir config config/logs /etc/container/configmaps \
 && ln -fsv /etc/container/configmaps/bookmarks.yaml config/bookmarks.yaml \
 && ln -fsv /etc/container/configmaps/docker.yaml config/docker.yaml \
 && ln -fsv /etc/container/configmaps/kubernetes.yaml config/kubernetes.yaml \
 && ln -fsv /etc/container/configmaps/services.yaml config/services.yaml \
 && ln -fsv /etc/container/configmaps/settings.yaml config/settings.yaml \
 && ln -fsv /etc/container/configmaps/widgets.yaml config/widgets.yaml \
 && ln -fsv /etc/container/configmaps/custom.css config/custom.css \
 && ln -fsv /etc/container/configmaps/custom.js config/custom.js \
 && ln -fsv /mnt/volumes/configmaps/bookmarks.yaml /etc/container/configmaps/bookmarks.yaml \
 && ln -fsv /mnt/volumes/configmaps/docker.yaml /etc/container/configmaps/docker.yaml \
 && ln -fsv /mnt/volumes/configmaps/kubernetes.yaml /etc/container/configmaps/kubernetes.yaml \
 && ln -fsv /mnt/volumes/configmaps/services.yaml /etc/container/configmaps/services.yaml \
 && ln -fsv /mnt/volumes/configmaps/settings.yaml /etc/container/configmaps/settings.yaml \
 && ln -fsv /mnt/volumes/configmaps/widgets.yaml /etc/container/configmaps/widgets.yaml \
 && ln -fsv /mnt/volumes/configmaps/custom.css /etc/container/configmaps/custom.css \
 && ln -fsv /mnt/volumes/configmaps/custom.js /etc/container/configmaps/custom.js \
 && ln -fsv /mnt/volumes/container/images /app/public/images
RUN chown -R $USER:$USER /app /home/$USER
WORKDIR /app
