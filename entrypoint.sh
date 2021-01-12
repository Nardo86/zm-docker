#!/bin/bash

/etc/init.d/mysql start

RESULT=$(mysqlshow --user=zmuser --password=zmpass zm| grep -v Wildcard | grep -o Tables)
if [ "$RESULT" != "Tables" ]
then

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

#set timezone
echo "[mysqld]\n  default-time-zone=$(cat /etc/timezone)" >> /etc/mysql/my.cnf
/etc/init.d/mysql restart

fi

#start
/etc/init.d/apache2 start
/usr/bin/zmpkg.pl start
