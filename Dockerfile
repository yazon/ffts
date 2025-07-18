# FFTS Build Environment
# Multi-stage Dockerfile for building FFTS with modern tooling

# Base stage with common dependencies
FROM ubuntu:22.04 AS base

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV CMAKE_VERSION=3.25.0
ENV PYTHON_VERSION=3.10

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    ninja-build \
    python3 \
    python3-pip \
    git \
    wget \
    curl \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Install cross-compilation toolchains
RUN apt-get update && apt-get install -y \
    gcc-aarch64-linux-gnu \
    g++-aarch64-linux-gnu \
    gcc-arm-linux-gnueabihf \
    g++-arm-linux-gnueabihf \
    gcc-riscv64-linux-gnu \
    g++-riscv64-linux-gnu \
    qemu-user-static \
    && rm -rf /var/lib/apt/lists/*

# Development stage with additional tools
FROM base AS development

# Install development tools
RUN apt-get update && apt-get install -y \
    clang \
    clang-tidy \
    cppcheck \
    valgrind \
    gdb \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip3 install --no-cache-dir \
    pytest \
    coverage \
    black \
    flake8

# Set up workspace
WORKDIR /workspace

# Copy source code
COPY . .

# Make build script executable
RUN chmod +x build.py

# Default command
CMD ["/bin/bash"]

# Build stage for x86_64
FROM base AS build-x86_64

WORKDIR /workspace
COPY . .
RUN chmod +x build.py

# Build with default settings
RUN ./build.py --preset release build

# Build stage for ARM64
FROM base AS build-arm64

WORKDIR /workspace
COPY . .
RUN chmod +x build.py

# Build for ARM64
RUN mkdir build-arm64 && cd build-arm64 && \
    cmake .. \
        -DCMAKE_SYSTEM_NAME=Linux \
        -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
        -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc \
        -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++ \
        -DENABLE_NEON=ON \
        -DENABLE_TESTS=OFF \
        -DENABLE_STATIC=ON \
        -DENABLE_SHARED=OFF && \
    cmake --build . --parallel

# Build stage for RISC-V
FROM base AS build-riscv64

WORKDIR /workspace
COPY . .
RUN chmod +x build.py

# Build for RISC-V
RUN mkdir build-riscv64 && cd build-riscv64 && \
    cmake .. \
        -DCMAKE_SYSTEM_NAME=Linux \
        -DCMAKE_SYSTEM_PROCESSOR=riscv64 \
        -DCMAKE_C_COMPILER=riscv64-linux-gnu-gcc \
        -DCMAKE_CXX_COMPILER=riscv64-linux-gnu-g++ \
        -DDISABLE_DYNAMIC_CODE=ON \
        -DENABLE_TESTS=OFF \
        -DENABLE_STATIC=ON \
        -DENABLE_SHARED=OFF && \
    cmake --build . --parallel

# Testing stage
FROM development AS testing

WORKDIR /workspace
COPY . .
RUN chmod +x build.py

# Build with tests and sanitizers
RUN ./build.py --preset debug build && \
    ./build.py test

# Production stage
FROM ubuntu:22.04 AS production

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libc6 \
    && rm -rf /var/lib/apt/lists/*

# Copy built libraries and headers
COPY --from=build-x86_64 /workspace/build/lib /usr/local/lib
COPY --from=build-x86_64 /workspace/build/include /usr/local/include

# Set up library path
ENV LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

# Create symlinks for pkg-config
RUN ldconfig

# Default command
CMD ["/bin/bash"]

# Multi-architecture build stage
FROM base AS multiarch

WORKDIR /workspace
COPY . .
RUN chmod +x build.py

# Build for multiple architectures
RUN ./build.py --preset release build && \
    mkdir build-arm64 && cd build-arm64 && \
    cmake .. \
        -DCMAKE_SYSTEM_NAME=Linux \
        -DCMAKE_SYSTEM_PROCESSOR=aarch64 \
        -DCMAKE_C_COMPILER=aarch64-linux-gnu-gcc \
        -DCMAKE_CXX_COMPILER=aarch64-linux-gnu-g++ \
        -DENABLE_NEON=ON \
        -DENABLE_TESTS=OFF \
        -DENABLE_STATIC=ON \
        -DENABLE_SHARED=OFF && \
    cmake --build . --parallel && \
    cd .. && \
    mkdir build-riscv64 && cd build-riscv64 && \
    cmake .. \
        -DCMAKE_SYSTEM_NAME=Linux \
        -DCMAKE_SYSTEM_PROCESSOR=riscv64 \
        -DCMAKE_C_COMPILER=riscv64-linux-gnu-gcc \
        -DCMAKE_CXX_COMPILER=riscv64-linux-gnu-g++ \
        -DDISABLE_DYNAMIC_CODE=ON \
        -DENABLE_TESTS=OFF \
        -DENABLE_STATIC=ON \
        -DENABLE_SHARED=OFF && \
    cmake --build . --parallel

# Create packages
RUN cd build && cmake --install . --prefix ../install-x86_64 && \
    cd ../install-x86_64 && tar -czf ../ffts-linux-x86_64.tar.gz . && \
    cd ../build-arm64 && cmake --install . --prefix ../install-arm64 && \
    cd ../install-arm64 && tar -czf ../ffts-linux-arm64.tar.gz . && \
    cd ../build-riscv64 && cmake --install . --prefix ../install-riscv64 && \
    cd ../install-riscv64 && tar -czf ../ffts-linux-riscv64.tar.gz .

# CI/CD stage
FROM base AS ci

WORKDIR /workspace
COPY . .
RUN chmod +x build.py

# Install CI dependencies
RUN apt-get update && apt-get install -y \
    clang-tidy \
    cppcheck \
    && rm -rf /var/lib/apt/lists/*

# Run CI checks
RUN ./build.py --preset debug build && \
    ./build.py test && \
    cd build && \
    cmake --build . --target clang-tidy && \
    cppcheck --enable=all --std=c99 --error-exitcode=1 ../src/ ../include/

# Documentation stage
FROM base AS docs

WORKDIR /workspace
COPY . .
RUN chmod +x build.py

# Install documentation tools
RUN apt-get update && apt-get install -y \
    doxygen \
    graphviz \
    && rm -rf /var/lib/apt/lists/*

# Build documentation
RUN ./build.py configure -DENABLE_DOCUMENTATION=ON && \
    ./build.py build

# Create documentation package
RUN cd build && \
    tar -czf ../ffts-docs.tar.gz docs/

# Usage instructions
LABEL maintainer="FFTS Development Team"
LABEL description="FFTS (Fastest Fourier Transform in the South) Build Environment"
LABEL version="0.9.0"

# Usage examples:
# 
# Development environment:
# docker run -it --rm -v $(pwd):/workspace ffts:development
#
# Build for x86_64:
# docker build --target build-x86_64 -t ffts:x86_64 .
#
# Build for ARM64:
# docker build --target build-arm64 -t ffts:arm64 .
#
# Multi-architecture build:
# docker build --target multiarch -t ffts:multiarch .
#
# Run tests:
# docker build --target testing -t ffts:testing .
#
# CI/CD:
# docker build --target ci -t ffts:ci .
#
# Build documentation:
# docker build --target docs -t ffts:docs .