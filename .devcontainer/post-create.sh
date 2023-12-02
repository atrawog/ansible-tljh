#!/bin/sh
sudo chown -R $(id -u):$(id -g) /opt/conda
#source ~/.bashrc 
#micromamba shell init --shell bash -p $MAMBA_ROOT_PREFIX
#eval "$(micromamba shell hook --shell bash)"
#sudo groupmod -g ${DOCKER_GID} docker
#sudo usermod -aG docker $MAMBA_USER
#sudo groupadd -g ${KVM_GID} kvm
#sudo usermod -aG kvm $MAMBA_USER
#newgrp docker
#newgrp kvm
