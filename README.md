# Webserver — Nginx + PHP-FPM + MariaDB + Postgres (Docker)

Local dev stack. Works on any machine with Docker Desktop / Docker Engine + Compose v2.

## Quick start

```bash
cp .env.example .env   # once per machine, then edit passwords
bash setup.sh          # build + start
open http://localhost:8080
```

| Task | Command |
|---|---|
| Start | `bash setup.sh` |
| Custom port | `bash setup.sh --port=8080` |
| Logs | `docker compose logs -f nginx php` |
| Stop (keep data) | `bash setup.sh --down` |
| Fresh reset (DELETES db data) | `bash setup.sh --reset` |

## Layout

```
docker-compose.yml   # static, committed — never generated
.env.example         # template with dummy values (committed)
.env                 # real secrets, per-machine (NOT committed)
nginx/default.conf   # nginx vhost
php/Dockerfile       # php:8.3-fpm + pdo_mysql/pdo_pgsql/mysqli/mbstring
www/                 # web root (put your app here)
setup.sh             # bootstrap .env + `docker compose up` (never overwrites source)
```

## Notes

- DB data lives in **named volumes** (`mariadb_data`, `postgres_data`), so there is
  nothing large to commit and no `db_data/` / `postgres_data/` directories in git.
  Legacy bind-mount directories are gitignored if present.
- `www/index.php` reads credentials via `getenv()` (wired through `env_file: [.env]`
  on the `php` service) — no hardcoded passwords in source.
- Default ports: web `${WEB_HTTP_PORT:-8080}`, MariaDB `3306`, Postgres `5432`.
- First run builds the PHP image; subsequent starts are fast.
