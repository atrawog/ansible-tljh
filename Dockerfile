FROM docker.io/mambaorg/micromamba:1.5-bullseye AS base
ARG NEW_MAMBA_USER=jovian
ARG NEW_MAMBA_USER_ID=1000
ARG NEW_MAMBA_USER_GID=1000
ARG MAMBA_DOCKERFILE_ACTIVATE=1 
USER root

RUN if grep -q '^ID=alpine$' /etc/os-release; then \
      # alpine does not have usermod/groupmod
      apk add --no-cache --virtual temp-packages shadow; \
    fi && \
    usermod "--login=${NEW_MAMBA_USER}" "--home=/home/${NEW_MAMBA_USER}" \
        --move-home "-u ${NEW_MAMBA_USER_ID}" "${MAMBA_USER}" && \
    groupmod "--new-name=${NEW_MAMBA_USER}" \
        "-g ${NEW_MAMBA_USER_GID}" "${MAMBA_USER}" && \
    if grep -q '^ID=alpine$' /etc/os-release; then \
      # remove the packages that were only needed for usermod/groupmod
      apk del temp-packages; \
    fi && \
    # Update the expected value of MAMBA_USER for the
    # _entrypoint.sh consistency check.
    echo "${NEW_MAMBA_USER}" > "/etc/arg_mamba_user" && \
    :

# Create and set the workspace folder
ARG CONTAINER_WORKSPACE_FOLDER=/workspaces/ecovoyage
RUN mkdir -p "${CONTAINER_WORKSPACE_FOLDER}"
WORKDIR "${CONTAINER_WORKSPACE_FOLDER}"

ENV MAMBA_USER=$NEW_MAMBA_USER
ENV MAMBA_GID=$NEW_MAMBA_USER_GID
USER $MAMBA_USER


FROM base AS core
#ARG MAMBA_DOCKERFILE_ACTIVATE=1 
COPY --chown=$MAMBA_USER:$MAMBA_USER env/env_core.yaml /tmp/env_core.yaml
RUN micromamba install -y -f /tmp/env_core.yaml && micromamba clean --all --yes

FROM core AS ansible
#ARG MAMBA_DOCKERFILE_ACTIVATE=1 
#COPY --from=spatial /opt/conda /opt/conda
COPY --chown=$MAMBA_USER:$MAMBA_USER env/env_ansible.yaml /tmp/env_ansible.yaml
RUN micromamba install -y -f /tmp/env_ansible.yaml && micromamba clean --all --yes

FROM ansible as devel
#ARG MAMBA_DOCKERFILE_ACTIVATE=1 

ARG DOCKER_GID=999
ARG KVM_GID=992

#COPY --from=testing /opt/conda /opt/conda
USER root
RUN apt-get update && apt-get install -y build-essential openssh-client rsync sudo git apt-transport-https vim htop sysstat lsof nmap \
    ca-certificates curl gnupg lsb-release software-properties-common mkisofs qemu qemu-system qemu-utils kmod apt-file util-linux iproute2 iputils-ping && \
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

RUN usermod -aG sudo $MAMBA_USER && echo 'jovian ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
RUN groupmod -g ${DOCKER_GID}  docker && sudo usermod -aG docker jovian
RUN groupadd -g ${KVM_GID} kvm && sudo usermod -aG kvm jovian
RUN ln -s /bin/micromamba /bin/conda

USER $MAMBA_USER
RUN ansible-galaxy install geerlingguy.docker
RUN pip install molecule-qemu
