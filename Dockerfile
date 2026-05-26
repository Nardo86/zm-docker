# syntax=docker/dockerfile:1.7

# ---- Stage 1: build the ZoneMinder .deb from source ----
# Mirrors the upstream CI exactly (debian:12 container, same build toolchain,
# same packaging driver). See:
# https://github.com/ZoneMinder/zoneminder/blob/master/.github/workflows/build-deb-packages.yml
FROM debian:bookworm AS builder
ARG ZM_VERSION=1.38.1
ENV DEBIAN_FRONTEND=noninteractive

# Build toolchain — same set upstream installs in their CI.
# We do NOT clean /var/lib/apt/lists/* here: the next RUN invokes
# do_debian_package.sh → mk-build-deps, which needs the apt index.
# The builder stage is discarded anyway.
RUN apt-get update && apt-get install -y --no-install-recommends \
        git ca-certificates gnupg lsb-release curl bash sudo \
        build-essential devscripts debhelper equivs fakeroot \
        cmake pkg-config sphinx-doc dh-linktree dh-apache2 \
        libavcodec-dev libavdevice-dev libavformat-dev libavutil-dev \
        libswresample-dev libswscale-dev libbz2-dev \
        libturbojpeg0-dev default-libmysqlclient-dev \
        libpolkit-gobject-1-dev libv4l-dev libvlc-dev libssl-dev \
        libvncserver-dev libjwt-gnutls-dev libgsoap-dev gsoap \
        libmosquittopp-dev

WORKDIR /build

# Make every apt-get invocation non-interactive. do_debian_package.sh and
# the mk-build-deps call inside it don't pass -y, so without this they'd
# block on apt's "Do you want to continue?" prompt and abort. Same effect
# as upstream's "set -eux" + interactive runner-attached TTY, but works
# in a Dockerfile.
RUN echo 'APT::Get::Assume-Yes "true";' > /etc/apt/apt.conf.d/90assumeyes

# Pre-install the build-deps explicitly. This is exactly what upstream's
# CI does before calling do_debian_package.sh: clone the source, then
# `mk-build-deps -ir -t "apt-get -y --no-install-recommends" debian/control`.
# Doing it here means the script's own (default-flagged) mk-build-deps call
# later finds everything already installed and is a no-op.
RUN git clone --depth=1 --branch=${ZM_VERSION} \
        https://github.com/ZoneMinder/zoneminder.git zm-deps-src \
    && cd zm-deps-src \
    && ln -sf distros/ubuntu2004 debian \
    && mk-build-deps -ir -t "apt-get -y" debian/control \
    && cd .. && rm -rf zm-deps-src

# Use ZoneMinder's own packaging driver, pulled from the same tag we want
# to build. Flags:
#   -b=<tag>      pin the checkout to this tag (overrides the script's
#                 default of `master`, which is what made the previous
#                 ZM_VERSION argument silently ineffective)
#   -t=binary     build .deb only, no source package
#   -i=no         non-interactive: skip the post-build "install/upload?"
#                 prompts and let the script clean up its working tree
#   -x="-us -uc"  passed through to debuild → skip gpg signing
RUN curl -fsSL -o do_debian_package.sh \
        "https://raw.githubusercontent.com/ZoneMinder/zoneminder/${ZM_VERSION}/utils/do_debian_package.sh" \
    && chmod +x do_debian_package.sh \
    && ./do_debian_package.sh -b=${ZM_VERSION} -t=binary -i=no -x="-us -uc"

# debuild drops the .deb next to the source tree, i.e. in /build/.
RUN mkdir -p /artifacts && cp /build/zoneminder_*.deb /artifacts/

# ---- Stage 2: runtime ----
FROM debian:bookworm-slim
ENV TZ=Etc/UTC \
    FQDN=localhost \
    SELFSIGNED=0 \
    DEBIAN_FRONTEND=noninteractive

COPY --from=builder /artifacts/zoneminder_*.deb /tmp/

# Install the ZoneMinder .deb via `apt install ./pkg.deb` (apt 1.0+ syntax):
# apt resolves all declared dependencies AND Recommends, which is what
# ZoneMinder's own install docs recommend. The postinst script also calls
# wget and a2enmod, so we install those plus a small set of operational
# tools (msmtp for outbound mail, rsyslog because ZM logs there).
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates curl wget openssl tzdata sudo rsyslog \
        msmtp msmtp-mta \
    && apt-get install -y /tmp/zoneminder_*.deb \
    && adduser www-data video \
    && a2enmod ssl rewrite headers expires \
    && a2enconf zoneminder \
    && a2ensite default-ssl.conf \
    && mkdir -p /config \
    && rm -f /tmp/zoneminder_*.deb \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --chmod=755 entrypoint.sh /entrypoint.sh

VOLUME /config
VOLUME /var/cache/zoneminder
VOLUME /sslcert

EXPOSE 443/tcp

HEALTHCHECK --interval=30s --timeout=5s --start-period=180s --retries=3 \
    CMD curl -kfsS https://localhost/zm/index.php >/dev/null || exit 1

ENTRYPOINT ["/entrypoint.sh"]
