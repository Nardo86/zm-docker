# ZONEMINDER

This is a simple debian image with the ZoneMinder installed following the official instructions https://wiki.zoneminder.com/Debian_10_Buster_with_Zoneminder_1.34.x_from_ZM_Repo.

Because of the ssmtp deprecation the mail server installed is msmtp and a default configuration file prepared for GMail will be created in /config/msmtprc.

Furthermore the image is prepared for working with SWAG(let's encrypt) image or there is an environment for the self-signed certificate option.

Image available at https://hub.docker.com/r/nardo86/docker

Feel free to consider donating if my work helped you! https://paypal.me/ErosNardi

_Tested on my Raspberry Pi 4 with SWAG_


**USAGE**

Just run the image publishing the port and setting the ENV variables, the shm dedicated and mounting the folder you wish to map.

`docker run -d \`

`  --name=ZoneMinder \`

`  -p 443:443/tcp \`

`  -e TZ=Europe/Rome \`

`  -e SELFSIGNED=0 \`

`  -e FQDN=your.fqdn \`

`  --shm-size=1.5g \`

`  -v /mystorage/ZoneMinder/config:/config \`

`  -v /mystorage/ZoneMinder/zmcache:/var/cache/zoneminder \`

`  -v /mystorage/Swag/etc/letsencrypt/live:/sslcert/live \`

`  -v /mystorage/Swag/etc/letsencrypt/archive:/sslcert/archive \`

`  --restart unless-stopped \`

`  nardo86/zoneminder`

The SELFSIGNED flag will , the FQDN will be used for configuring Apache2 and, in case of using the SWAG certificate, find the correct folder and the /config folder will contain msmtp and mysql configuration.

The shm-size will be the quantity of RAM dedicated to /dev/shm.*

**be sure to not reserve too much RAM to this machine or the docker server wil start to paging and eventually becoming unresponsible**

To access the Zoneminder gui, browse to: https://your.fqdn:443/zm

If you need to transfer your data from another instance this method worked for me https://forums.zoneminder.com/viewtopic.php?t=17071:

Backup the old DB

`root@oldSystem# mysqldump -p zm > /config/zm-dbbackup.sql`

Restore into the new DB

`root@newSystem# mysql -p zm < /config/zm-dbbackup.sql`

Sync folders

`root@newSystem# rsync -r -t -p -o -g -v --progress --delete user@oldSystem:/var/cache/zoneminder/* /var/cache/zoneminder/`

Init / cleanup

`root@newSystem# zmaudit.pl`


**EXTRA OPTIONS**

Environment variable used for the configuration

Variable|Description|Default
--------|-----------|-------
SELFSIGNED|switch between using a self-signed certificate and the one in sslcert/live folder|0
FQDN|the FQDN Apache2 will be listening to, sslcert/live subfolder if SELFSIGNED is 0 |localhost