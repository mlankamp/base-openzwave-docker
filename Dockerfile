ARG BUILD_ARCH=amd64
ARG TARGET_ARCH=amd64

# ----------------
# STEP 0:
# Download qemu
# All result files will be put in /dist folder
FROM alpine AS qemu
ARG QEMU_ARCH=x86_64
ARG QEMU_VERSION=v4.0.0-4
ARG OPENZWAVE_VERSION=1.6.784
ADD https://github.com/multiarch/qemu-user-static/releases/download/${QEMU_VERSION}/qemu-${QEMU_ARCH}-static /qemu-${QEMU_ARCH}-static
RUN chmod +x /qemu-${QEMU_ARCH}-static

# ----------------
# STEP 1:
# Build Openzwave and nodejs
# All result files will be put in /dist folder
FROM ${BUILD_ARCH}/node:carbon-alpine AS build
ARG QEMU_ARCH

COPY --from=qemu /qemu-${QEMU_ARCH}-static /usr/bin/qemu-${QEMU_ARCH}-static

# Install required dependencies
RUN apk update && apk --no-cache add \
      gnutls \
      gnutls-dev \
      libusb \
      eudev \
      # Install build dependencies
    && apk --no-cache --virtual .build-deps add \
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
    && wget http://old.openzwave.com/downloads/openzwave-${OPENZWAVE_VERSION}.tar.gz \
    && tar zxvf openzwave-*.gz \
    && cd openzwave-* \
    && make \
    && make install \
    && mkdir -p /dist/lib \
    && mv libopenzwave.so* /dist/lib/

# Get last config DB from main repo and move files to /dist/db
RUN cd /root \
    && git clone https://github.com/OpenZWave/open-zwave.git \
    && cd open-zwave \
    && mkdir -p /dist/db \
    && mv config/* /dist/db

# Clean up
RUN rm -R /root/* && apk del .build-deps

# ----------------
# STEP 3:
# Run a minimal alpine image
FROM ${TARGET_ARCH}/alpine:latest

LABEL maintainer="mlankamp"

RUN apk update && apk add --no-cache \
    libstdc++  \
    libgcc \
    libusb \
    tzdata \
    eudev

# Copy files from previous build stage
COPY --from=build /dist/lib/ /lib/
COPY --from=build /dist/db/ /usr/local/etc/openzwave/

# Set enviroment
ENV LD_LIBRARY_PATH /lib
