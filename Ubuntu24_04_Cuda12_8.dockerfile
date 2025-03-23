# syntax=docker/dockerfile:1

FROM ubuntu:24.04

RUN apt update
RUN apt-get update

RUN DEBIAN_FRONTEND=noninteractive  apt-get install -y git ninja-build cmake curl wget lsb-release software-properties-common gnupg

WORKDIR /temp_build_dir
RUN wget  https://apt.llvm.org/llvm.sh && bash ./llvm.sh all

RUN wget https://developer.download.nvidia.com/compute/cuda/12.8.0/local_installers/cuda_12.8.0_570.86.10_linux.run && sh cuda_12.8.0_570.86.10_linux.run --toolkit --no-drm --silent
