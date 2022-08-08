#!/bin/bash
#echo $TZ > /etc/timezone
ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

echo "Configuring MariaDBPath"
if [ ! -d /config/mysql ]; then
	mkdir -p /config/mysql
	rsync -a -v -q --ignore-existing /var/lib/mysql/ /config/mysql/
	echo "MariaDBPath configuration done"
else
	echo "MariaDBPath already configured"
fi
sed -i -e 's,/var/lib/mysql,/config/mysql,g' /etc/mysql/mariadb.conf.d/50-server.cnf
echo 'innodb_file_per_table = ON' >> /etc/mysql/mariadb.conf.d/50-server.cnf
echo 'innodb_buffer_pool_size = 256M' >> /etc/mysql/mariadb.conf.d/50-server.cnf
echo 'innodb_log_file_size = 32M' >> /etc/mysql/mariadb.conf.d/50-server.cnf

echo "Check MariaDB config"
/etc/init.d/mysql start
while ! mysqladmin ping --silent; do
	echo "Waiting mysql startup..."
    sleep 3
done

RESULT=$(mysqlshow --user=zmuser --password=zmpass zm| grep -v Wildcard | grep -o Tables)
if [ "$RESULT" != "Tables" ]; then

#configure mysql
echo "USE mysql;" > timezones.sql &&  mysql_tzinfo_to_sql /usr/share/zoneinfo >> timezones.sql
mysql -u root < timezones.sql
rm timezones.sql
mysql -u root < /usr/share/zoneminder/db/zm_create.sql
mysql -u root -e "grant all on zm.* to 'zmuser'@localhost identified by 'zmpass';"
mysqladmin -u root reload

#secure mysql
secret=$(openssl rand -base64 14)
mysql_secure_installation <<EOF

y
$secret
$secret
y
y
y
y
EOF

/etc/init.d/mysql restart
while ! mysqladmin ping --silent; do
	echo "Waiting mysql restart"
    sleep 3
done
echo "MariaDB configuration done"
else
echo "MariaDB already configured"
fi

#echo "Checking Timezones"
#RESULT=$(cat /etc/mysql/my.cnf| grep default-time-zone)
#if [ "$RESULT" != "default-time-zone=$(cat /etc/timezone)" ]; then
#	echo "Set Mysql timezone"
#	printf  "[mysqld]\n  default-time-zone=$(cat /etc/timezone)" >> /etc/mysql/my.cnf
#	/etc/init.d/mysql restart
#	while ! mysqladmin ping --silent; do
#		echo "Waiting mysql restart..."
#		sleep 3
#	done
#fi

RESULT=$(cat /etc/php/*/apache2/php.ini| grep "date.timezone =")
if [ "$RESULT" != "date.timezone = $(sed 's/\\/\//' /etc/timezone)" ]; then
	echo "Set Php timezone"
	sed -i "s/;date.timezone =/date.timezone = $(sed 's/\\/\//' /etc/timezone)/g" /etc/php/*/apache2/php.ini
fi

echo "Checking MSMTP configuration"
if [ ! -f /config/msmtprc ]; then
printf  "defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        ~/.msmtp.log
account        gmail
host           smtp.gmail.com
port           587
from           username@gmail.com
user           username
password       password
account default : gmail
" > /config/msmtprc
fi

if [ ! -f /etc/msmtprc ]; then
ln -s /config/msmtprc /etc/msmtprc
fi

if [ "$SELFSIGNED" = "0" ]; then
echo "Linking to SWAG"
sed -i -e 's,/etc/ssl/certs/ssl-cert-snakeoil.pem,/sslcert/live/'$FQDN'/cert.pem,g' /etc/apache2/sites-available/default-ssl.conf
sed -i -e 's,/etc/ssl/private/ssl-cert-snakeoil.key,/sslcert/live/'$FQDN'/privkey.pem,g' /etc/apache2/sites-available/default-ssl.conf
fi

RESULT=$(cat /etc/apache2/apache2.conf| grep ServerName)
if [ "$RESULT" = "" ]; then
	echo "Set ServerName"
	echo "ServerName "$FQDN >> /etc/apache2/apache2.conf
fi

echo "Seting /var/cache subfolders"
mkdir -p /var/cache/zoneminder/cache && chown www-data:www-data /var/cache/zoneminder/cache
mkdir -p /var/cache/zoneminder/events && chown www-data:www-data /var/cache/zoneminder/events
mkdir -p /var/cache/zoneminder/images && chown www-data:www-data /var/cache/zoneminder/images
mkdir -p /var/cache/zoneminder/temp && chown www-data:www-data /var/cache/zoneminder/temp

echo "Starting"
#start
/etc/init.d/apache2 start
/usr/bin/zmpkg.pl start

RESULT=$(tail -n1  /var/log/zm/zmpkg.log |grep "Version mismatch")
if [ "$RESULT" != "" ]; then
echo "WARNING: DB version mismatch found!"
echo "auto align.."
/usr/bin/zmpkg.pl stop
/usr/bin/zmupdate.pl -nointeractive
/usr/bin/zmpkg.pl start
echo "done"
fi

tail -f /var/log/apache2/error.log
