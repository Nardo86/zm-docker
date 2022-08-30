FROM debian:bullseye-slim

ENV TZ Etc/UTC
ENV FQDN localhost
ENV SELFSIGNED 0

RUN apt-get update 

RUN apt-get install -y \
apache2 \
mariadb-server \
php \
libapache2-mod-php \
php-mysql 

RUN apt-get install -y \
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
tzdata

RUN apt-get remove -y \
exim4* \
&& apt autoremove -y

RUN apt-get install -y \
msmtp \
msmtp-mta

RUN adduser www-data video

RUN  mkdir /config

COPY zoneminder_1.36.24~20220823.0-bullseye_arm64.deb /

COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

VOLUME /config
VOLUME /var/cache/zoneminder
VOLUME /sslcert

EXPOSE 443/tcp
