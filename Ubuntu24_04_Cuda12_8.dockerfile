# syntax=docker/dockerfile:1

FROM ubuntu:24.04

RUN apt update
RUN apt-get update

RUN DEBIAN_FRONTEND=noninteractive  apt-get install -y git ninja-build curl wget lsb-release software-properties-common gnupg g++

WORKDIR /temp_build_dir
RUN wget  https://apt.llvm.org/llvm.sh && bash ./llvm.sh all

RUN wget https://developer.download.nvidia.com/compute/cuda/12.8.0/local_installers/cuda_12.8.0_570.86.10_linux.run
RUN sh cuda_12.8.0_570.86.10_linux.run --toolkit --no-drm --silent --override

RUN wget https://github.com/Kitware/CMake/releases/download/v3.30.8/cmake-3.30.8-linux-x86_64.sh
RUN chmod +x ./cmake-3.30.8-linux-x86_64.sh && ./cmake-3.30.8-linux-x86_64.sh --skip-license --prefix=/usr/local
RUN apt-get install -y cmake-curses-gui clang-format fish eza
RUN rm -rf /temp_build_dir
