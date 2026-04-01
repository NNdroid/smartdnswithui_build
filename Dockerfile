# syntax=docker/dockerfile:1
ARG BUILDPLATFORM=linux/arm64
FROM --platform=${BUILDPLATFORM} debian:trixie

ENV DEBIAN_FRONTEND=noninteractive

# 1. 安装基础工具
RUN apt-get update && apt-get install -y \
    build-essential libssl-dev git debhelper dh-make \
    fakeroot dpkg-dev curl pkg-config jq clang llvm libclang-dev wget unzip xz-utils && \
    rm -rf /var/lib/apt/lists/*

# 2. 【核心修复】直接安装 Node.js v24.14.1 (ARM64)
# 不使用 nvm，直接下载二进制文件并解压到 /usr/local
RUN NODE_VERSION=v24.14.1 && \
    ARCH=arm64 && \
    curl -fsSL https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-linux-${ARCH}.tar.xz | tar -xJ -C /usr/local --strip-components=1 && \
    node -v && npm -v

# 3. 安装 Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# 定义外部传入的变量
ARG LATEST_SHA
ARG VER

WORKDIR /workspace

# 4. 执行克隆与编译
RUN git clone --recursive https://github.com/pymumu/smartdns . && \
    git checkout ${LATEST_SHA} && \
    mkdir -p /output && \
    # 打包源码
    tar -czf /output/smartdns-src-original.tar.gz . && \
    # 显式指定 libclang 路径
    export LIBCLANG_PATH=/usr/lib/llvm-14/lib && \
    # 执行编译 (此时 node v24 已在 PATH 中)
    ./package/build-pkg.sh --platform linux --arch arm64 --with-ui --outputdir /output --ver "${VER}" && \
    ./package/build-pkg.sh --platform debian --arch arm64 --with-ui --outputdir /output --ver "${VER}"
