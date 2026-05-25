# ZoneMinder Docker Container

Containerized [ZoneMinder](https://zoneminder.com/) on Debian, built from
upstream source using the official Debian packaging path. Multi-arch:
`linux/amd64`, `linux/arm64`. Tested on Raspberry Pi 4 (64-bit OS).

> **Status:** community-maintained, no active testing by the original author.
> Functional and stable for personal use. Issues and PRs welcome.

## Why this image

- ZoneMinder's official image hasn't been updated in years.
- Other popular images (e.g. dlandon's) bundle Event Notification Server and
  ML add-ons. This image stays focused: just ZoneMinder.
- Built on Debian bookworm, the same base as current Raspberry Pi OS 64-bit.

## Quick Start

```yaml
services:
  zoneminder:
    image: nardo86/zoneminder:latest
    container_name: zoneminder
    ports:
      - "443:443"
    environment:
      TZ: Europe/Rome
      FQDN: zm.example.local
      SELFSIGNED: "1"
    volumes:
      - ./config:/config                       # MariaDB data + msmtp config
      - ./zmcache:/var/cache/zoneminder        # events + recordings
    shm_size: 1gb
    restart: unless-stopped
```

Access at `https://<FQDN>:443/zm` once the container reports `healthy`.

## Configuration

| Variable     | Description                                              | Default     |
|--------------|----------------------------------------------------------|-------------|
| `TZ`         | Timezone (also written to ZM's `ZM_TIMEZONE`)            | `Etc/UTC`   |
| `FQDN`       | Server hostname for Apache `ServerName` and SSL          | `localhost` |
| `SELFSIGNED` | `1` → generate a self-signed cert on first run, `0` → expect certs under `/sslcert/live/$FQDN/` | `0` |

### Shared memory

ZoneMinder uses `/dev/shm` for live capture buffers. Start with `shm_size: 1gb`
and bump if you have many cameras at high resolution — don't over-allocate,
the host will swap.

### Volumes

| Path                        | What's inside                          |
|-----------------------------|----------------------------------------|
| `/config`                   | MariaDB data dir + `msmtprc`           |
| `/var/cache/zoneminder`     | Events, images, temp                   |
| `/sslcert`                  | Mount your Let's Encrypt live/archive  |

### Custom SSL (e.g. SWAG / Let's Encrypt)

Set `SELFSIGNED=0` and mount certs:

```yaml
volumes:
  - /path/to/swag/etc/letsencrypt/live:/sslcert/live
  - /path/to/swag/etc/letsencrypt/archive:/sslcert/archive
```

Apache reads `/sslcert/live/$FQDN/fullchain.pem` and `privkey.pem`.

### Email (msmtp)

A template config is written to `/config/msmtprc` on first run. Edit it with
your SMTP credentials and restart the container.

## Upgrading from 1.36 → 1.38

ZoneMinder 1.38 introduces major changes (RBAC, monitor Function field split
into `Capturing`/`Analysing`/`Recording`, new tables). Database migrations
run automatically via `zmupdate.pl` on container start when a version
mismatch is detected.

**Back up `/config/mysql` before the first start on 1.38** — the migration is
one-way. See the [upstream 1.38.0 release notes](https://github.com/ZoneMinder/zoneminder/releases/tag/1.38.0)
for details.

## Migrating data from another instance

[Reference thread](https://forums.zoneminder.com/viewtopic.php?t=17071).

```bash
# On the old system
mysqldump -p zm > zm-dbbackup.sql

# On the new system, after first container start
docker exec -i zoneminder mysql -u root zm < zm-dbbackup.sql
rsync -avP --delete /path/to/old/events/* zmcache/events/
docker exec zoneminder zmaudit.pl
```

## Troubleshooting

- **Container stuck "Waiting for MariaDB startup..."**: open a shell with
  `docker exec -it zoneminder bash` and run
  `/usr/bin/mysqld_safe --skip-syslog` to see the actual error.
- **HTTPS not responding**: check `docker logs` for Apache errors and verify
  `FQDN` matches the cert subject when using custom SSL.
- **DB version mismatch warning**: the entrypoint will run `zmupdate.pl`
  automatically. If it fails repeatedly, restore your backup and check the
  ZoneMinder logs under `/var/log/zm/` inside the container.

## Image

[hub.docker.com/r/nardo86/zoneminder](https://hub.docker.com/r/nardo86/zoneminder)

Tags published by the workflow:

- `latest` — last successful build from `master`
- `zm-<version>` — the ZoneMinder version that was built
- `YYYY.MM` — monthly cron snapshot
- `1.34`, `amd64-1.34`, `arm32v7-1.34`, `arm64v8-1.34` — frozen 2021 images
  on ZoneMinder 1.34, kept for users who pinned them. **Not updated.**

## Notes

- Built with help from Claude (Anthropic). Review the configuration before
  exposing to anything beyond your LAN — defaults are convenient, not hardened.
- Not affiliated with the ZoneMinder project. See
  [ZoneMinder/zoneminder](https://github.com/ZoneMinder/zoneminder) for the upstream.
- No warranty. Back up your recordings.

## Support

⭐ Star • 🐛 Issue • 🔧 PR • ☕ <https://paypal.me/ErosNardi>
