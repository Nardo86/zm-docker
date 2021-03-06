FROM debian:buster-slim

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
apt-transport-https \
gnupg \
wget \
&& wget -O - https://zmrepo.zoneminder.com/debian/archive-keyring.gpg | apt-key add - \
&& echo 'deb https://zmrepo.zoneminder.com/debian/release-1.34 buster/' >> /etc/apt/sources.list

RUN apt-get update 

RUN apt-get install -y \
zoneminder \
msmtp \
msmtp-mta

RUN adduser www-data video

RUN a2enmod ssl \
&& a2enmod rewrite \
&& a2enconf zoneminder \
&& a2ensite default-ssl.conf

RUN  mkdir /config

COPY entrypoint.sh /
run chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

VOLUME /config
VOLUME /var/cache/zoneminder
VOLUME /sslcert

EXPOSE 443/tcp
