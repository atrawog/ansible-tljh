#!/bin/sh
sudo chown -R $(id -u):$(id -g) /opt/conda
#sudo groupmod -g ${DOCKER_GID} docker
#sudo usermod -aG docker $MAMBA_USER
#sudo groupadd -g ${KVM_GID} kvm
#sudo usermod -aG kvm $MAMBA_USER

