ARG BUILD_ARCH=amd64

# ----------------
# STEP 0:
# Download qemu
# All result files will be put in /dist folder
FROM alpine AS qemu
ARG QEMU_ARCH=x86_64
ARG QEMU_VERSION=v4.0.0-4
ADD https://github.com/multiarch/qemu-user-static/releases/download/${QEMU_VERSION}/x86_64_qemu-${QEMU_ARCH}-static.tar.gz /x86_64_qemu-${QEMU_ARCH}-static.tar.gz
RUN tar -xvf x86_64_qemu-${QEMU_ARCH}-static.tar.gz \
    && rm x86_64_qemu-${QEMU_ARCH}-static.tar.gz \
    && chmod +x /qemu-${QEMU_ARCH}-static

# ----------------
# STEP 1:
# Create images with nodejs and Openzwave
FROM ${BUILD_ARCH}/node:carbon-alpine
ARG QEMU_ARCH
ARG OPENZWAVE_VERSION
LABEL maintainer="mlankamp"

COPY --from=qemu /qemu-${QEMU_ARCH}-static /usr/bin/qemu-${QEMU_ARCH}-static

# Install required dependencies
RUN apk update && apk --no-cache add \
      gnutls \
      gnutls-dev \
      libusb \
      eudev \
      # Install build dependencies
    && apk --no-cache add \
      coreutils \
      eudev-dev \
      build-base \
      git \
      python \
      bash \
      libusb-dev \
      linux-headers \
      wget \
      tar  \
      openssl \
      make

# Build binaries and move them to /dist/lib
RUN cd /root \
    && wget --tries=5 http://old.openzwave.com/downloads/openzwave-${OPENZWAVE_VERSION}.tar.gz \
    && tar zxvf openzwave-*.gz \
    && cd openzwave-* \
    && make \
    && make install

# Get last config DB from main repo and move files to /dist/db
RUN cd /root \
    && git clone https://github.com/OpenZWave/open-zwave.git \
    && cd open-zwave \
    && rm -r /usr/local/etc/openzwave \
    && mkdir -p /usr/local/etc/openzwave \
    && mv config/* /usr/local/etc/openzwave/

# Clean up
RUN rm -R /root/*
