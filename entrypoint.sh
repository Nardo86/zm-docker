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

mysql -u root <<-EOSQL
UPDATE mysql.user SET Password=PASSWORD('root') WHERE User='root';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.db WHERE Db='test' OR Db='test_%';
CREATE USER 'zmuser'@localhost IDENTIFIED BY 'zmpass';
GRANT ALL PRIVILEGES ON zm.* TO 'zmuser'@localhost;
FLUSH PRIVILEGES;
EOSQL

echo 'Initializing ZM DB'
sudo -u www-data /usr/bin/zmpkg.pl version

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

echo "Check ZM config"
if [ ! -f /config/zm_extra.conf ]; then

echo "Creating /config/zm_extra.conf"
cat > /config/zm_extra.conf << EOF
# Custom ZoneMinder configuration
ZM_DB_HOST=localhost
ZM_DB_NAME=zm
ZM_DB_USER=zmuser
ZM_DB_PASS=zmpass
ZM_LOG_LEVEL_SYSLOG=3
ZM_LOG_LEVEL_FILE=3
ZM_LOG_LEVEL_WEBLOG=3
EOF

ln -sf /config/zm_extra.conf /etc/zm/conf.d/90-zm_extra.conf

else
	echo "ZM configuration already exists"
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
sed -i "s/#ServerName.*/ServerName $FQDN/" /etc/apache2/sites-available/default-ssl.conf

echo "Starting services"
service rsyslog start
/etc/init.d/mariadb start
/etc/init.d/apache2 start

echo "ZoneMinder configured and started"
echo "Access via: https://$FQDN:443/zm"

}

stop(){
	echo "Shutting down"
	/etc/init.d/apache2 stop
	/etc/init.d/mariadb stop
	service rsyslog stop
	exit 0
}

start

while :
do
	echo "Ready to accept connections at https://$FQDN:443/zm"
	sleep 30 &
	wait $!
done