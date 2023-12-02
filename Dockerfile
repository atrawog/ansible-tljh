# syntax=docker/dockerfile:1.2

ARG BASE_IMAGE=debian:bookworm-slim

FROM --platform=$BUILDPLATFORM $BASE_IMAGE AS fetch
ARG VERSION=1.5.3

RUN  rm -f /etc/apt/apt.conf.d/docker-*
RUN --mount=type=cache,target=/var/cache/apt,id=aptdeb12 apt-get update && apt-get install -y --no-install-recommends bzip2 ca-certificates curl

RUN if [ "$BUILDPLATFORM" = 'linux/arm64' ]; then \
        export ARCH='aarch64'; \
    else \
        export ARCH='64'; \
    fi; \
    curl -L "https://micro.mamba.pm/api/micromamba/linux-${ARCH}/${VERSION}" | \
    tar -xj -C "/tmp" "bin/micromamba"


FROM $BASE_IMAGE as base

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
ENV MAMBA_ROOT_PREFIX="/opt/conda"
ENV MAMBA_EXE="/bin/micromamba"
ENV PATH="${PATH}:${MAMBA_ROOT_PREFIX}/bin"

COPY --from=fetch /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=fetch /tmp/bin/micromamba "$MAMBA_EXE"

FROM base AS micromamba

ARG MAMBA_USER=jovian
ARG MAMBA_USER_ID=1000
ARG MAMBA_USER_GID=1000
ENV MAMBA_USER=$MAMBA_USER
ENV MAMBA_USER_ID=$MAMBA_USER_ID
ENV MAMBA_USER_GID=$MAMBA_USER_GID

RUN groupadd -g "${MAMBA_USER_GID}" "${MAMBA_USER}" && \
    useradd -m -u "${MAMBA_USER_ID}" -g "${MAMBA_USER_GID}" -s /bin/bash "${MAMBA_USER}"
RUN mkdir -p "${MAMBA_ROOT_PREFIX}" && \
    chown "${MAMBA_USER}:${MAMBA_USER}" "${MAMBA_ROOT_PREFIX}" 
USER $MAMBA_USER
RUN micromamba shell init --shell bash --prefix=$MAMBA_ROOT_PREFIX
SHELL ["/bin/bash", "--rcfile", "/$MAMBA_USER/.bashrc", "-c"]


FROM micromamba AS ansible

COPY --chown=$MAMBA_USER:$MAMBA_USER env_ansible.yml /tmp/env_ansible.yml 
RUN --mount=type=cache,target=$MAMBA_ROOT_PREFIX/pkgs,id=mamba_pkgs  micromamba install -y -f /tmp/env_ansible.yml


FROM ansible as ansible-devel

USER root
ARG CONTAINER_WORKSPACE_FOLDER=/workspaces/ansible-tljh
RUN mkdir -p "${CONTAINER_WORKSPACE_FOLDER}"
WORKDIR "${CONTAINER_WORKSPACE_FOLDER}"


COPY packages.txt /tmp/packages.txt
RUN --mount=type=cache,target=/var/cache/apt,id=aptdeb12 apt-get update && xargs apt-get install -y < /tmp/packages.txt

RUN touch /var/lib/dpkg/status && install -m 0755 -d /etc/apt/keyrings
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    chmod a+r /etc/apt/keyrings/docker.gpg
RUN echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null && apt-get update
RUN --mount=type=cache,target=/var/cache/apt,id=aptdeb12 apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

RUN usermod -aG sudo $MAMBA_USER
RUN echo "$MAMBA_USER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers


USER $MAMBA_USER

RUN ansible-galaxy install geerlingguy.docker
RUN pip install molecule-qemu

USER root

# Copy the fix-permissions.sh script to /bin
COPY .devcontainer/fix-permissions.sh /bin/fix-permissions.sh

# Make the script executable
RUN chmod +x /bin/fix-permissions.sh

# Append the execution of the script to .bashrc of the user
RUN echo 'export MAMBA_USER_ID=$(id -u)' >> /home/$MAMBA_USER/.bashrc && \
    echo 'export MAMBA_USER_GID=$(id -g)' >> /home/$MAMBA_USER/.bashrc && \
    echo "/bin/fix-permissions.sh" >> /home/$MAMBA_USER/.bashrc && \
    echo "micromamba activate" >> /home/$MAMBA_USER/.bashrc


ARG DOCKER_GID=999
ARG KVM_GID=992

RUN getent group ${DOCKER_GID} || groupmod -g ${DOCKER_GID} docker
RUN usermod -aG docker $MAMBA_USER

RUN groupadd -g ${KVM_GID} kvm && usermod -aG kvm $MAMBA_USER


USER $MAMBA_USER