# Webserver

A containerized local development stack providing Nginx, PHP-FPM, MariaDB, and
PostgreSQL. It is a self-contained alternative to machine-wide environments such
as XAMPP or MAMP: no PHP or database server has to be installed on the host, and
the entire stack can be started, stopped, and reset with a single command.

## Overview

| Service | Image | Role |
|---|---|---|
| `nginx` | `nginx:alpine` | HTTP server and reverse proxy; the only exposed entry point |
| `php` | `php:8.3-fpm-alpine` (built from `php/Dockerfile`) | PHP-FPM application server |
| `mariadb` | `mariadb:11` | MySQL-compatible database |
| `postgres` | `postgres:17` | PostgreSQL database |

The stack is intended for local development and testing. It is not hardened for
production use.

## Why

Installing and maintaining PHP, Nginx, MariaDB, and PostgreSQL directly on a
development machine creates version drift between developers, pollutes the host
with services and configuration files, and makes clean resets difficult. This
stack addresses those problems by:

- Running each component in its own container with pinned image versions.
- Keeping the application code on the host through a bind mount, so edits are
  reflected immediately without rebuilding images.
- Keeping database data in Docker named volumes that survive container restarts
  and can be removed deliberately when a clean slate is required.
- Keeping credentials out of version control: secrets live in `.env`, which is
  git-ignored, while `.env.example` documents the required variables.
- Binding all published ports to `127.0.0.1`, so the services are not reachable
  from other machines on the network.

## Architecture

```
                    Docker network (Compose)
+-----------+       +------------------+       +-----------+
|  Browser  | ----> |  nginx  :80      | ----> |  php:9000 |
+-----------+  HTTP |  static + proxy  | FastCGI|  PHP-FPM  |
                    +------------------+       +-----------+
                                                      |
                                          +-----------+-----------+
                                          |                       |
                                    +-----------+           +------------+
                                    | mariadb   |           | postgres   |
                                    |  :3306    |           |   :5432    |
                                    +-----------+           +------------+
```

Request handling works as follows:

1. Nginx listens on port 80 inside the container, published on the host as
   `127.0.0.1:${WEB_HTTP_PORT}`, and serves files from `/var/www/html`.
2. Requests for `.php` files are passed to the `php` service over FastCGI on
   port 9000. The two services share the `./www` directory through bind mounts,
   so Nginx resolves the file and PHP executes the same file.
3. PHP connects to the databases using the Compose service names (`mariadb`,
   `postgres`) as hostnames. Both databases are also published on loopback for
   external tools such as DBeaver.
4. The Nginx configuration uses a front-controller fallback
   (`try_files $uri $uri/ /index.php`). Existing files are served directly;
   unknown paths are routed to the root `index.php`.

Database credentials are passed only to the `php` service through `env_file:
.env`, where they are read with `getenv()`. Nginx never receives database
credentials, and no passwords are hardcoded in the source tree.

## Requirements

- Docker Engine or Docker Desktop with Compose v2
- Bash (for `setup.sh`)
- A free host port for HTTP (default `8080`)

## Quick start

```bash
cp .env.example .env   # first run only; edit the passwords
bash setup.sh          # build images and start the stack
```

Then open <http://localhost:8080>. The root page reports the PHP version and the
connection status of both databases. A sample project is available at
<http://localhost:8080/hello/>.

`setup.sh` creates `.env` from `.env.example` automatically if it is missing; it
never overwrites existing files.

## Configuration

All configuration is read from `.env` at the repository root. The file is
git-ignored and must not be committed.

| Variable | Default | Purpose |
|---|---|---|
| `COMPOSE_PROJECT_NAME` | `webserver` | Prefix for container, network, and volume names |
| `WEB_HTTP_PORT` | `8080` | Host port for the Nginx service |
| `MARIADB_ROOT_PASSWORD` | required | MariaDB root password |
| `MARIADB_DATABASE` | `appdb` | Database created on first start |
| `MARIADB_USER` | `appuser` | MariaDB application user |
| `MARIADB_PASSWORD` | required | MariaDB application password |
| `POSTGRES_DB` | `appdb` | PostgreSQL database created on first start |
| `POSTGRES_USER` | `appuser` | PostgreSQL user |
| `POSTGRES_PASSWORD` | required | PostgreSQL password |

The web port can also be overridden for a single run without editing `.env`:

```bash
bash setup.sh --port=8080
```

## Repository layout

```
docker-compose.yml     Service definitions, networks, and volumes
.env.example           Template for environment variables (committed)
.env                   Local secrets (git-ignored, never committed)
nginx/default.conf     Nginx virtual host and FastCGI configuration
php/Dockerfile         PHP-FPM image with pdo_mysql, pdo_pgsql, mysqli, mbstring
www/                   Web root (bind-mounted into nginx and php)
setup.sh               Bootstrap and lifecycle helper
```

Applications are organized as one directory per project under `www/`, for
example `www/hello/index.php`, and are reachable at `/<project>/`.

## Usage

| Task | Command |
|---|---|
| Start the stack | `bash setup.sh` |
| Start on a different port | `bash setup.sh --port=8080` |
| Follow application logs | `docker compose logs -f nginx php` |
| Stop containers, keep data | `bash setup.sh --down` |
| Rebuild after image changes | `docker compose up -d --build` |
| Destroy containers and database data | `bash setup.sh --reset` |

Published ports:

| Service | Host address | Container port |
|---|---|---|
| Nginx | `127.0.0.1:${WEB_HTTP_PORT:-8080}` | `80` |
| MariaDB | `127.0.0.1:3306` | `3306` |
| PostgreSQL | `127.0.0.1:5432` | `5432` |

## Data persistence

MariaDB and PostgreSQL store their data in the named volumes `mariadb_data` and
`postgres_data`. These volumes are preserved by `setup.sh --down` and by
restarting the stack. `setup.sh --reset` runs `docker compose down -v` and
removes them, so all database contents are lost. The PHP and Nginx containers
are stateless; all application code lives in `www/` on the host.

## Operational notes

- Health checks use `healthcheck.sh --connect --innodb_initialized` for MariaDB
  and `pg_isready` for PostgreSQL. Containers report `healthy` once the
  databases accept connections.
- The first start builds the PHP image and can take a minute. Subsequent starts
  use the cached image.
- Nginx and PHP mount `./www` directly, so changes under `www/` take effect
  without restarting or rebuilding containers.
- The stack intentionally terminates no TLS and uses default database
  credentials for convenience in development. Replace all example passwords in
  `.env` and do not expose these services outside the local machine.
