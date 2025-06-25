FROM debian:bullseye-slim

ENV TZ Etc/UTC
ENV FQDN localhost
ENV SELFSIGNED 0

# Install build dependencies and runtime dependencies
RUN apt-get update && apt-get install -y \
    # Build dependencies
    git \
    build-essential \
    cmake \
    devscripts \
    equivs \
    # Runtime dependencies
    apache2 \
    mariadb-server \
    php \
    libapache2-mod-php \
    php-mysql \
    libavcodec58 \
    libavdevice58 \
    libavformat58 \
    libavutil56 \
    libcurl3-gnutls \
    libjpeg62-turbo \
    libswresample3 \
    libswscale5 \
    sudo \
    javascript-common \
    ffmpeg \
    libcurl4-gnutls-dev \
    libdatetime-perl \
    libdate-manip-perl \
    libmime-lite-perl \
    libmime-tools-perl \
    libdbd-mysql-perl \
    libphp-serialization-perl \
    libnet-sftp-foreign-perl \
    libarchive-zip-perl \
    libdevice-serialport-perl \
    libimage-info-perl \
    libjson-maybexs-perl \
    libsys-mmap-perl \
    liburi-encode-perl \
    libwww-perl \
    libdata-dump-perl \
    libclass-std-fast-perl \
    libsoap-wsdl-perl \
    libio-socket-multicast-perl \
    libsys-cpu-perl \
    libsys-meminfo-perl \
    libdata-uuid-perl \
    libnumber-bytes-human-perl \
    libfile-slurp-perl \
    php-gd \
    php-apcu \
    php-intl \
    policykit-1 \
    rsyslog \
    zip \
    libcrypt-eksblowfish-perl \
    libdata-entropy-perl \
    libvncclient1 \
    libjwt-gnutls0 \
    libgsoap-2.8.104 \
    tzdata \
    && rm -rf /var/lib/apt/lists/*

# Remove exim4 and install msmtp
RUN apt-get update && apt-get remove -y exim4* && apt-get autoremove -y \
    && apt-get install -y msmtp msmtp-mta \
    && rm -rf /var/lib/apt/lists/*

# Add www-data to video group
RUN adduser www-data video

# Create config directory
RUN mkdir /config

# Copy ZoneMinder packages
COPY zoneminder_*.deb /tmp/

# Install the appropriate package based on architecture
ARG TARGETARCH
RUN if [ "$TARGETARCH" = "arm64" ]; then \
        echo "Installing ARM64 package" && \
        dpkg -i /tmp/zoneminder_*arm64.deb || (apt-get update && apt-get install -f -y); \
    else \
        echo "Installing AMD64 package" && \
        dpkg -i /tmp/zoneminder_*amd64.deb || (apt-get update && apt-get install -f -y); \
    fi \
    && rm /tmp/zoneminder_*.deb \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Configure Apache
RUN a2enmod ssl \
    && a2enmod rewrite \
    && a2enmod headers \
    && a2enmod expires \
    && a2enconf zoneminder \
    && a2ensite default-ssl.conf

# Copy entrypoint script
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh

VOLUME /config
VOLUME /var/cache/zoneminder
VOLUME /sslcert

EXPOSE 443/tcp

ENTRYPOINT ["/entrypoint.sh"]