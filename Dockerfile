FROM debian:buster-slim
#https://wiki.zoneminder.com/Debian_10_Buster_with_Zoneminder_1.34.x_from_ZM_Repo
ENV TZ=UTC

RUN apt-get update 

RUN apt-get install -y \
apt-transport-https \
gnupg \
wget \
&& wget -O - https://zmrepo.zoneminder.com/debian/archive-keyring.gpg | apt-key add - \
&& echo 'deb https://zmrepo.zoneminder.com/debian/release-1.34 buster/' >> /etc/apt/sources.list

RUN apt-get update 

RUN apt-get install -y \
apache2 \
mariadb-server \
php \
libapache2-mod-php \
php-mysql \
zoneminder

RUN adduser www-data video

RUN a2enmod ssl \
&& a2enmod rewrite \
&& a2enconf zoneminder \
&& a2ensite default-ssl.conf

RUN sed -i "s/;date.timezone =/date.timezone = $(sed 's/\//\\\//' /etc/timezone)/g" /etc/php/*/apache2/php.ini

COPY entrypoint.sh /
ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 443/tcp
EXPOSE 9000/tcp
