# syntax=docker/dockerfile:1

FROM ubuntu:24.04
RUN apt update
RUN apt-get install -y wget
RUN apt-get install -y sudo

# ROCm
# We're installing a specific version of ROCm here
RUN wget https://repo.radeon.com/amdgpu-install/6.3/ubuntu/noble/amdgpu-install_6.3.60300-1_all.deb
RUN apt install -y ./amdgpu-install_6.3.60300-1_all.deb

# Specify usecases
RUN DEBIAN_FRONTEND=noninteractive amdgpu-install -y --usecase="graphics,opencl,hip,rocm,rocmdev,rocmdevtools,lrt,opencl,hiplibsdk" --no-dkms
# Setup system .so paths for the system dynamic linker
RUN cat <<EOF >> /etc/ld.so.conf.d/rocm.conf
/opt/rocm/lib
/opt/rocm/lib64
EOF
RUN ldconfig

# CUDA
RUN apt-get install -y libxml2
RUN wget https://developer.download.nvidia.com/compute/cuda/12.3.0/local_installers/cuda_12.3.0_545.23.06_linux.run
RUN sh cuda_12.3.0_545.23.06_linux.run --toolkit --no-drm --silent

# Development dependencies
RUN apt-get install -y software-properties-common
RUN add-apt-repository ppa:maveonair/helix-editor && apt update && apt install -y helix
RUN cd /tmp && wget https://github.com/Kitware/CMake/releases/download/v3.31.0/cmake-3.31.0-linux-x86_64.sh && bash cmake-3.31.0-linux-x86_64.sh --skip-license --prefix=/usr/local/ 
RUN apt-get install -y vim python3 git ninja-build
RUN wget https://github.com/zellij-org/zellij/releases/download/v0.41.2/zellij-x86_64-unknown-linux-musl.tar.gz &&  \
    tar -xvf zellij-x86_64-unknown-linux-musl.tar.gz && \
    rm zellij-x86_64-unknown-linux-musl.tar.gz && mv zellij /usr/bin/zellij

RUN apt-get install -y clangd
RUN apt-get install -y libblas-dev liblapack-dev
