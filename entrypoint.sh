#!/usr/bin/env bash

trap stop SIGTERM SIGINT SIGQUIT SIGHUP ERR

start(){

ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone
dpkg-reconfigure --frontend noninteractive tzdata

echo "ZoneMinder is already installed from build process"

echo "Configuring MariaDBPath"
if [ ! -d /config/mysql ]; then
	mkdir -p /config/mysql
	rsync -a -v -q --ignore-existing /var/lib/mysql/ /config/mysql/
	echo "MariaDBPath configuration done"
else
	echo "MariaDBPath already configured"
fi

# Ensure correct permissions for mysql data directory
echo "Fixing MySQL permissions"
chown -R mysql:mysql /config/mysql/
sed -i -e 's,/var/lib/mysql,/config/mysql,g' /etc/mysql/mariadb.conf.d/50-server.cnf
echo 'innodb_file_per_table = ON' >> /etc/mysql/mariadb.conf.d/50-server.cnf
echo 'innodb_buffer_pool_size = 256M' >> /etc/mysql/mariadb.conf.d/50-server.cnf
echo 'innodb_log_file_size = 32M' >> /etc/mysql/mariadb.conf.d/50-server.cnf

echo "Check MariaDB config"
/etc/init.d/mariadb start
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

/etc/init.d/mariadb restart
while ! mysqladmin ping --silent; do
	echo "Waiting mysql restart"
    sleep 3
done
	echo "MariaDB configuration done"

else
echo "ZM Database already configured"
fi

echo "Check MSMTP config"
if [ ! -f /config/msmtprc ]; then

echo "Creating /config/msmtprc"
cat > /config/msmtprc << EOF
defaults
auth           on
tls            on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile        ~/.msmtp.log

account        gmail
host           smtp.gmail.com
port           587
from           username@gmail.com
user           username@gmail.com
password       password

account default : gmail
EOF

chown www-data:www-data /config/msmtprc
chmod 600 /config/msmtprc

else
	echo "MSMTP already configured"
fi

# Link msmtp config if not exists
if [ ! -f /etc/msmtprc ]; then
	ln -s /config/msmtprc /etc/msmtprc
fi

echo "Check SSL Certificates"
if [ "$SELFSIGNED" = "1" ]; then
    echo "Generating self-signed certificate"
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /etc/ssl/private/apache-selfsigned.key \
        -out /etc/ssl/certs/apache-selfsigned.crt \
        -subj "/C=US/ST=State/L=City/O=Organization/OU=OrgUnit/CN=$FQDN"
    
    # Configure Apache for self-signed
    sed -i "s/SSLCertificateFile.*/SSLCertificateFile \/etc\/ssl\/certs\/apache-selfsigned.crt/" /etc/apache2/sites-available/default-ssl.conf
    sed -i "s/SSLCertificateKeyFile.*/SSLCertificateKeyFile \/etc\/ssl\/private\/apache-selfsigned.key/" /etc/apache2/sites-available/default-ssl.conf
else
    echo "Using custom SSL certificates"
    if [ -d "/sslcert/live/$FQDN" ]; then
        sed -i "s/SSLCertificateFile.*/SSLCertificateFile \/sslcert\/live\/$FQDN\/fullchain.pem/" /etc/apache2/sites-available/default-ssl.conf
        sed -i "s/SSLCertificateKeyFile.*/SSLCertificateKeyFile \/sslcert\/live\/$FQDN\/privkey.pem/" /etc/apache2/sites-available/default-ssl.conf
    else
        echo "SSL certificate directory not found, using defaults"
    fi
fi

# Configure Apache ServerName
RESULT=$(cat /etc/apache2/apache2.conf| grep ServerName)
if [ "$RESULT" = "" ]; then
	echo "Set ServerName"
	echo "ServerName "$FQDN >> /etc/apache2/apache2.conf
fi

# Configure PHP timezone
RESULT=$(cat /etc/php/*/apache2/php.ini| grep "date.timezone =")
if [ "$RESULT" = ";date.timezone =" ]; then
	echo "Set Php timezone"
        printf  "date.timezone = $(cat /etc/timezone)" >> /etc/php/*/apache2/php.ini
fi

echo "Setting /var/cache subfolders"
mkdir -p /var/cache/zoneminder/cache && chown www-data:www-data /var/cache/zoneminder/cache
mkdir -p /var/cache/zoneminder/events && chown www-data:www-data /var/cache/zoneminder/events
mkdir -p /var/cache/zoneminder/images && chown www-data:www-data /var/cache/zoneminder/images
mkdir -p /var/cache/zoneminder/temp && chown www-data:www-data /var/cache/zoneminder/temp

echo "Starting services"
service rsyslog start
/etc/init.d/apache2 start
/usr/bin/zmpkg.pl start

# Check for version mismatch and auto-update if needed
RESULT=$(tail -n2  /var/log/zm/zmpkg.log |grep "Version mismatch")
if [ "$RESULT" != "" ]; then
	echo "WARNING: DB version mismatch found!"
	echo "auto align.."
	/usr/bin/zmpkg.pl stop
	/usr/bin/zmupdate.pl -nointeractive
	/usr/bin/zmupdate.pl -f
	/usr/bin/zmpkg.pl start
	echo "done"
fi

# Set timezone in ZoneMinder config
mysql -e "update zm.Config set Value = '$TZ' where Name = 'ZM_TIMEZONE';"

echo "ZoneMinder configured and started"
echo "Access via: https://$FQDN:443/zm"

}

stop(){
	echo "Shutdown requested"
	kill ${!};

	echo "Stopping apache"
	/etc/init.d/apache2 stop
	echo "Stopping zoneminder"
	/usr/bin/zmpkg.pl stop
	echo "Stopping mariadb"
	/etc/init.d/mariadb stop

	echo "Shutdown completed"
	exit
}

start

tail -f /var/log/apache2/error.log & wait ${!}