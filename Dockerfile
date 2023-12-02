ARG BASE_IMAGE=debian:bookworm-slim

FROM --platform=$BUILDPLATFORM $BASE_IMAGE AS stage1
ARG VERSION=1.5.3

RUN apt-get update && apt-get install -y --no-install-recommends bzip2 ca-certificates curl

ARG TARGETARCH=amd64
RUN test "$TARGETARCH" = 'amd64' && export ARCH='64'; \
    test "$TARGETARCH" = 'arm64' && export ARCH='aarch64'; \
    test "$TARGETARCH" = 'ppc64le' && export ARCH='ppc64le'; \
    curl -L "https://micro.mamba.pm/api/micromamba/linux-${ARCH}/${VERSION}" | \
    tar -xj -C "/tmp" "bin/micromamba"

FROM $BASE_IMAGE as base

ENV LANG=C.UTF-8 LC_ALL=C.UTF-8
#ENV ENV_NAME="base"
ENV MAMBA_ROOT_PREFIX="/opt/conda"
#ENV CONDA_PREFIX="$MAMBA_ROOT_PREFIX"
#ENV CONDA_PROMPT_MODIFIER="(base)"
#ENV CONDA_SHLVL=1
ENV MAMBA_EXE="/bin/micromamba"
#ENV CONDA_DEFAULT_ENV=base
ENV PATH="${PATH}:${MAMBA_ROOT_PREFIX}/bin"

COPY --from=stage1 /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=stage1 /tmp/bin/micromamba "$MAMBA_EXE"
RUN ln -s $MAMBA_EXE /bin/conda

ARG MAMBA_USER=jovian
ARG MAMBA_USER_ID=1000
ARG MAMBA_USER_GID=1000
ENV MAMBA_USER=$MAMBA_USER
ENV MAMBA_USER_ID=$MAMBA_USER_ID
ENV MAMBA_USER_GID=$MAMBA_USER_GID

RUN groupadd -g "${MAMBA_USER_GID}" "${MAMBA_USER}" && \
    useradd -m -u "${MAMBA_USER_ID}" -g "${MAMBA_USER_GID}" -s /bin/bash "${MAMBA_USER}" && \
    mkdir -p "$MAMBA_ROOT_PREFIX" && \
    chown -R "${MAMBA_USER}" "$MAMBA_ROOT_PREFIX" && \
    chmod -R 777 "$MAMBA_ROOT_PREFIX"

# Create and set the workspace folder
ARG CONTAINER_WORKSPACE_FOLDER=/workspaces/ansible-tljh
RUN mkdir -p "${CONTAINER_WORKSPACE_FOLDER}"
WORKDIR "${CONTAINER_WORKSPACE_FOLDER}"

USER $MAMBA_USER
RUN micromamba shell init --shell bash --prefix=$MAMBA_ROOT_PREFIX
SHELL ["/bin/bash", "--rcfile", "/$MAMBA_USER/.bashrc", "-c"]

FROM base AS ansible
COPY --chown=$MAMBA_USER:$MAMBA_USER env_ansible.yml /tmp/env_ansible.yml 
RUN micromamba install -y -f /tmp/env_ansible.yml && micromamba clean --all --yes


FROM ansible as devel

USER root
RUN apt-get update && apt-get install -y build-essential openssh-client rsync sudo git apt-transport-https vim htop sysstat lsof nmap \
    ca-certificates curl gnupg lsb-release software-properties-common mkisofs qemu-system qemu-utils kmod apt-file util-linux iproute2 iputils-ping && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN touch /var/lib/dpkg/status && install -m 0755 -d /etc/apt/keyrings
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    chmod a+r /etc/apt/keyrings/docker.gpg
RUN echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null && apt-get update
RUN apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN usermod -aG sudo $MAMBA_USER && echo "$MAMBA_USER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

#USER $MAMBA_USER
#RUN ansible-galaxy install geerlingguy.docker
#RUN pip install molecule-qemu

USER root
ARG DOCKER_GID=999
ARG KVM_GID=992

RUN getent group ${DOCKER_GID} || groupmod -g ${DOCKER_GID} docker
RUN usermod -aG docker $MAMBA_USER

RUN groupadd -g ${KVM_GID} kvm && usermod -aG kvm $MAMBA_USER
USER $MAMBA_USER