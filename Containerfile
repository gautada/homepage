ARG ALPINE_VERSION=latest

# │ STAGE: CONTAINER
# ╰――――――――――――――――――――――――――――――――――――――――――――――――――――――
FROM docker.io/gautada/alpine:$ALPINE_VERSION as CONTAINER

# ╭――――――――――――――――――――╮
# │ METADATA           │
# ╰――――――――――――――――――――╯
LABEL source="https://github.com/gautada/homepage-container.git"
LABEL maintainer="Adam Gautier <adam@gautier.org>"
LABEL description="A container for a homepage server"

# ╭―
# │ USER
# ╰――――――――――――――――――――
ARG USER=homepage
RUN /usr/sbin/usermod -l $USER alpine
RUN /usr/sbin/usermod -d /home/$USER -m $USER
RUN /usr/sbin/groupmod -n $USER alpine
RUN /bin/echo "$USER:$USER" | /usr/sbin/chpasswd

# ╭―
# │ PRIVILEGES
# ╰――――――――――――――――――――
# COPY privileges /etc/container/privileges

# ╭―
# │ BACKUP
# ╰――――――――――――――――――――
# COPY backup /etc/container/backup


# ╭―
# │ ENTRYPOINT
# ╰――――――――――――――――――――
COPY entrypoint /etc/container/entrypoint

# ╭―
# │ APPLICATION
# ╰――――――――――――――――――――

RUN /sbin/apk add --no-cache pnpm

WORKDIR /home/$USER
RUN git clone https://github.com/gethomepage/homepage.git server
WORKDIR /home/$USER/server
RUN pnpm install
RUN pnpm build

# ╭―
# │ CONFIGURATION
# ╰――――――――――――――――――――
RUN chown -R $USER:$USER /home/$USER

USER $USER
VOLUME /mnt/volumes/backup
VOLUME /mnt/volumes/configmaps
VOLUME /mnt/volumes/container
VOLUME /mnt/volumes/secrets
VOLUME /mnt/volumes/source

WORKDIR /home/$USER/server


 

