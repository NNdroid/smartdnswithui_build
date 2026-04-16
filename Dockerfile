# syntax=docker/dockerfile:1
ARG BUILDPLATFORM=linux/arm64
FROM --platform=${BUILDPLATFORM} debian:trixie

ENV DEBIAN_FRONTEND=noninteractive

# 1. 安装基础工具
# 【修改建议】：明确安装 clang-19 和相关组件，杜绝版本盲盒
RUN apt-get update && apt-get install -y \
    build-essential libssl-dev git debhelper dh-make \
    fakeroot dpkg-dev curl pkg-config jq \
    clang-19 llvm-19 libclang-19-dev \
    wget unzip xz-utils && \
    rm -rf /var/lib/apt/lists/*

# 2. 直接安装 Node.js v24.14.1 (ARM64)
# (如果之前遇到 TLS 错误，可以把 nodejs.org 换成国内镜像源，没遇到则保持原样)
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
    tar -czf /output/smartdns-src-original.tar.gz . && \
    # --- 修复开始 (硬编码替换动态查找) ---
    # 强制建立指向 19 版本的软链接
    ln -sf /usr/lib/llvm-19/lib/libclang.so.1 /usr/lib/libclang.so && \
    # 显式指定路径环境变量
    export LIBCLANG_PATH=/usr/lib/llvm-19/lib && \
    export CLANG_PATH=/usr/bin/clang-19 && \
    # --- 修复结束 ---
    echo "Current LIBCLANG_PATH: $LIBCLANG_PATH" && \
    ./package/build-pkg.sh --platform linux --arch arm64 --with-ui --outputdir /output --ver "${VER}" && \
    ./package/build-pkg.sh --platform debian --arch arm64 --with-ui --outputdir /output --ver "${VER}"
