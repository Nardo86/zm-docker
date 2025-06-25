# ZoneMinder Docker Container

A containerized ZoneMinder surveillance system built on Debian Bullseye, providing a complete video surveillance solution with web interface, database, and SSL support.

## ⚠️ Project Status

This project is **community-maintained** and no longer actively used by the original author. While functional, please note:

- **AMD64 builds**: Available with latest ZoneMinder versions
- **ARM64 builds**: Fully supported via automated builds
- **Testing**: Limited testing is performed on new versions - use at your own risk
- **Support**: Community-based support only

**⚠️ Important**: Always backup your configuration and recordings before upgrading versions.

## Features

- 🔒 **SSL/TLS Support** - Self-signed certificates or custom SSL certificates
- 🗄️ **Persistent Storage** - Configuration and recordings stored in mounted volumes
- 📧 **Email Notifications** - Integrated msmtp for email alerts
- 🔧 **Easy Configuration** - Environment variable based setup
- 🌐 **Multi-Architecture** - Support for both AMD64 and ARM64 platforms
- 🔗 **SWAG Integration** - Compatible with LinuxServer.io SWAG reverse proxy

## Quick Start

### Docker Run
```bash
docker run -d \
  --name=zoneMinder \
  -p 443:443 \
  -e TZ=Europe/Rome \
  -e SELFSIGNED=0 \
  -e FQDN=your.fqdn \
  --shm-size=1g \
  -v /mystorage/ZoneMinder/config:/config \
  -v /mystorage/ZoneMinder/zmcache:/var/cache/zoneminder \
  --restart unless-stopped \
  nardo86/zoneminder
```

### Docker Compose
```yaml
version: '3.8'
services:
  zoneminder:
    image: nardo86/zoneminder
    container_name: zoneminder
    ports:
      - "443:443"
    environment:
      - TZ=Europe/Rome
      - SELFSIGNED=0
      - FQDN=your.fqdn
    volumes:
      - /mystorage/ZoneMinder/config:/config
      - /mystorage/ZoneMinder/zmcache:/var/cache/zoneminder
    shm_size: '1gb'
    restart: unless-stopped
```

## Technical Details

This container is built following the [official ZoneMinder installation guide](https://wiki.zoneminder.com/Debian_10_Buster_with_Zoneminder_1.36.x_from_ZM_Repo). 

**ARM64 builds** are compiled from source using the official build process due to lack of pre-built ARM64 packages.

**Email Configuration**: Uses msmtp (replacing deprecated ssmtp) with Gmail-ready configuration template created at `/config/msmtprc`.

## Image Repository

Available at: https://hub.docker.com/r/nardo86/zoneminder


## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `TZ` | Timezone setting | `Etc/UTC` |
| `FQDN` | Fully Qualified Domain Name for Apache2 configuration | `localhost` |
| `SELFSIGNED` | Use self-signed certificates (1) or custom SSL certificates (0) | `0` |

### SSL Certificate Options

**Self-signed certificates** (`SELFSIGNED=1`):
- Automatically generated on first run
- Suitable for testing and internal use

**Custom SSL certificates** (`SELFSIGNED=0`):
- Mount your certificates to `/sslcert/live` and `/sslcert/archive`
- Compatible with Let's Encrypt certificates from SWAG

### SWAG Integration Example

```yaml
version: '3.8'
services:
  zoneminder:
    image: nardo86/zoneminder
    container_name: zoneminder
    ports:
      - "443:443"
    environment:
      - TZ=Europe/Rome
      - SELFSIGNED=0
      - FQDN=your.domain.com
    volumes:
      - /mystorage/ZoneMinder/config:/config
      - /mystorage/ZoneMinder/zmcache:/var/cache/zoneminder
      - /mystorage/Swag/etc/letsencrypt/live:/sslcert/live
      - /mystorage/Swag/etc/letsencrypt/archive:/sslcert/archive
    shm_size: '1gb'
    restart: unless-stopped
```

### Memory Configuration

The `shm-size` parameter allocates shared memory for ZoneMinder:
- Size depends on number of cameras and recording settings
- Start with 1GB and adjust based on performance
- **Warning**: Don't over-allocate as it may cause system instability

### Access

Once running, access ZoneMinder at: `https://your.fqdn:443/zm`

## Migration & Troubleshooting

### Data Migration

To transfer data from another ZoneMinder instance ([reference](https://forums.zoneminder.com/viewtopic.php?t=17071)):

1. **Backup database** on old system:
   ```bash
   mysqldump -p zm > /config/zm-dbbackup.sql
   ```

2. **Restore database** on new system:
   ```bash
   mysql -p zm < /config/zm-dbbackup.sql
   ```

3. **Sync recordings**:
   ```bash
   rsync -r -t -p -o -g -v --progress --delete user@oldSystem:/var/cache/zoneminder/* /var/cache/zoneminder/
   ```

4. **Cleanup and audit**:
   ```bash
   zmaudit.pl
   ```

### Common Issues

#### MySQL Startup Problems

If the container gets stuck on "Waiting mysql startup..." message:

1. **Access container**:
   ```bash
   docker exec -it zoneminder bash
   ```

2. **Manual database start** with detailed logging:
   ```bash
   /usr/bin/mysqld_safe --skip-syslog
   ```

3. **Check logs** for specific error messages to diagnose database issues

#### Performance Issues

- Monitor shared memory usage: `df -h /dev/shm`
- Adjust `shm-size` based on camera count and recording settings
- Check system memory usage to prevent swapping

## Security Considerations

- 🔒 Use strong passwords for ZoneMinder admin account
- 🌐 Consider using a reverse proxy with proper SSL certificates
- 🔄 Keep container updated with security patches
- 📋 Regularly backup your configuration and recordings
- 🚫 Avoid exposing directly to internet without additional security layers

## Contributing

This is a community-maintained project. Contributions are welcome:

- 🐛 **Bug Reports**: Please include container logs and system information
- 🔧 **Pull Requests**: Test thoroughly before submitting
- 📚 **Documentation**: Help improve this README
- 🧪 **Testing**: Help test new versions on different architectures

## ⚠️ AI Disclaimer

This project was developed with the assistance of Claude AI (Anthropic). While functional, please be aware that:

- **Security considerations**: The configuration may not be optimized for production environments
- **Best practices**: Some settings might not follow enterprise-grade security standards  
- **Testing required**: Thoroughly test in your environment before production use
- **No warranty**: Use at your own risk - review all configurations before deployment
- **Community input welcome**: Issues and improvements are encouraged via GitHub issues/PRs

**Recommendation**: Have a security professional review the setup before production deployment.

## Support & Donations

This is a community project maintained on a volunteer basis. 

**If this project helped you:**
- ⭐ Star the repository on GitHub
- 🐛 Report issues and bugs
- 🔧 Contribute improvements
- ☕ Feel free to consider donating if my work helped you! https://paypal.me/ErosNardi

**For issues:**
1. Check existing GitHub issues
2. Review security considerations
3. Test in isolated environment
4. Provide detailed reproduction steps
5. Be patient - this is maintained on volunteer basis

## Version Information

- **AMD64**: Latest ZoneMinder version (automatically updated)
- **ARM64**: Latest ZoneMinder version (fully supported)
- **Base Image**: Debian Bullseye Slim
- **Web Server**: Apache2 with SSL
- **Database**: MariaDB
- **Mail**: msmtp (replaces deprecated ssmtp)
