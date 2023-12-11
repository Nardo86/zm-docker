# ZONEMINDER - DOCKER ARM64

This is a simple debian image with the ZoneMinder installed following the official instructions https://wiki.zoneminder.com/Debian_10_Buster_with_Zoneminder_1.36.x_from_ZM_Repo; due to the fact that there is no official arm64 package it has been build directly from the sources https://zoneminder.readthedocs.io/en/stable/installationguide/packpack.html via `OS=debian DIST=bullseye ARCH=aarch64 utils/packpack/startpackpack.sh`

Because of the ssmtp deprecation the mail server installed is msmtp and a default configuration file prepared for GMail will be created in /config/msmtprc, be sure to set the correct path /usr/bin/msmtp in zoneminder options.

Furthermore the image is prepared for working with [SWAG from LinuxServer.io](https://docs.linuxserver.io/general/swag/) image or there is an environment for the self-signed certificate option.

Image available at https://hub.docker.com/r/nardo86/zoneminder

Feel free to consider donating if my work helped you! https://paypal.me/ErosNardi

_Tested on my MiniPC Intel x64 and SWAG_


**USAGE**

Just run the image publishing the port and setting the ENV variables, the shm dedicated and mounting the folder you wish to map.

```
docker run -d \
  --name=zoneMinder \
  -p 443:443 \
  -e TZ=Europe/Rome \
  -e SELFSIGNED=0 \
  -e FQDN=your.fqdn \
  --shm-size=1g \
  -v /mystorage/ZoneMinder/config:/config \
  -v /mystorage/ZoneMinder/zmcache:/var/cache/zoneminder \
  -v /mystorage/Swag/etc/letsencrypt/live:/sslcert/live \
  -v /mystorage/Swag/etc/letsencrypt/archive:/sslcert/archive \
  --restart unless-stopped \
  nardo86/zoneminder
```

Or add to your docker compose

```
zoneminder:
    image: nardo86/zoneminder
    container_name: zoneminder
    ports:
    - "443:443"
    environment:
    - "TZ=Europe/Rome"
    - "SELFSIGNED=0"
    - "FQDN=your.fqdn"
    volumes:
    - "/mystorage/ZoneMinder/config:/config"
    - "/mystorage/ZoneMinder/zmcache:/var/cache/zoneminder"
    - "/mystorage/Swag/etc/letsencrypt/live:/sslcert/live"
    - "/mystorage/Swag/etc/letsencrypt/archive:/sslcert/archive"
    shm_size: '1gb'
    restart: unless-stopped
```

The FQDN will be used for configuring Apache2; the SELFSIGNED flag will generate a selfsigned certificate if needed else, in case of using the SWAG certificate, the system find the correct folder.
The /config folder will contain msmtp and mysql configuration.

The shm-size will be the quantity of RAM dedicated to /dev/shm, the size depends on the number and settings of the video sources to monitor, check ZoneMinder configuration for further information.*

**be sure to not reserve too much RAM to this machine or the docker server will start to paging and eventually becoming unresponsible**

To access the Zoneminder gui, browse to: https://your.fqdn:443/zm

**TIPS - RESTORE CONFIGURATION**

If you need to transfer your data from another instance this method worked for me https://forums.zoneminder.com/viewtopic.php?t=17071:

Backup the old DB

`root@oldSystem# mysqldump -p zm > /config/zm-dbbackup.sql`

Restore into the new DB

`root@newSystem# mysql -p zm < /config/zm-dbbackup.sql`

Sync folders

`root@newSystem# rsync -r -t -p -o -g -v --progress --delete user@oldSystem:/var/cache/zoneminder/* /var/cache/zoneminder/`

Init / cleanup

`root@newSystem# zmaudit.pl`

**TIPS - STUCK WITH Waiting mysql**

If the mysql service fails to start for some problem the script will stay in an infinite loop waiting mysql xxxx..

You can then log in to the machine and investigate for example starting the db with the command 

`/usr/bin/mysqld_safe --skip-syslog`

this will generate a detailed logfile of the startup possibly with some hints you can search to restore the db.

**EXTRA OPTIONS**

Environment variable used for the configuration

Variable|Description|Default
--------|-----------|-------
SELFSIGNED|switch between using a self-signed certificate and the one in sslcert/live folder|0
FQDN|the FQDN Apache2 will be listening to, sslcert/live subfolder if SELFSIGNED is 0 |localhost
