# booking

Symfony booking API and Twig UI. Runs on Docker Compose (app, PostgreSQL, RabbitMQ, worker).

## Requirements (VPS)

- Linux VPS with about **2 GB RAM**
- Docker Engine + Docker Compose plugin (`docker compose version`)
- Git
- Open inbound port **80** (HTTP). Do not expose Postgres (`5432`) or RabbitMQ management (`15672`) to the public internet.

Install Docker on Ubuntu/Debian if needed:

```bash
# Official convenience script or your distro packages, then:
sudo apt-get update
sudo apt-get install -y docker.io docker-compose-v2
sudo usermod -aG docker "$USER"
# log out and back in so the docker group applies
```

## Deploy after clone

### 1. Clone

```bash
git clone <YOUR_REPO_URL> booking
cd booking
```

### 2. Create environment file

```bash
cp .env.example .env
nano .env   # or vim / whatever you use
```

Change at least:

| Variable | What to set |
|----------|-------------|
| `APP_SECRET` | Long random string (e.g. `openssl rand -hex 32`) |
| `POSTGRES_PASSWORD` | Strong DB password |
| `DATABASE_URL` | Same user/password/db as `POSTGRES_*`, host must stay `db` |
| `RABBITMQ_PASSWORD` | Strong RabbitMQ password |
| `MESSENGER_TRANSPORT_DSN` | Same RabbitMQ user/password, host `rabbitmq` |
| `MESSENGER_TRANSPORT_FAILED_DSN` | Same credentials, queue `failed` |
| `DEFAULT_URI` | `http://YOUR_SERVER_IP` (or domain later) |
| `APP_HTTP_PORT` | `80` unless you map another host port |

Keep `APP_ENV=prod` and `APP_DEBUG=0` on the server.

### 3. Build and start

```bash
docker compose build
docker compose up -d
```

First build can take several minutes (PHP extensions, Composer).

Check containers:

```bash
docker compose ps
```

You should see `app`, `worker`, `db`, `rabbitmq` as running / healthy.

### 4. Smoke test

```bash
curl -s http://127.0.0.1/check
# or from your PC: http://YOUR_SERVER_IP/check
```

Expected body:

```json
{"ok":true}
```

Logs:

```bash
docker compose logs -f app
docker compose logs -f worker
```

The worker runs `messenger:consume async` and may stay quiet until messages exist — that is normal.

### 5. Database migrations

When Doctrine migrations exist in the project:

```bash
docker compose exec app php bin/console doctrine:migrations:migrate --no-interaction
```

Until then you can skip this step.

### 6. Useful commands

```bash
# Shell inside the app container
docker compose exec app sh

# Symfony console
docker compose exec app php bin/console debug:router

# Restart after config changes
docker compose up -d --build

# Stop everything (DB data volume is kept)
docker compose down

# Stop and remove DB volume (destroys data)
docker compose down -v
```

### 7. Update the app from git

```bash
cd booking
git pull
docker compose build
docker compose up -d
# when migrations exist:
# docker compose exec app php bin/console doctrine:migrations:migrate --no-interaction
```

## Services

| Service | Role |
|---------|------|
| `app` | nginx + PHP-FPM (HTTP on `APP_HTTP_PORT`) |
| `worker` | Messenger consumer (`async` transport) |
| `db` | PostgreSQL 16 |
| `rabbitmq` | AMQP broker (management plugin inside the image) |

Memory limits in `compose.yaml` are tuned for a ~2 GB VPS. Avoid running extra heavy services on the same host.

## RabbitMQ management UI (optional)

Ports `5672` / `15672` are **not** published by default. To open the UI safely via SSH tunnel from your PC:

```bash
ssh -L 15672:127.0.0.1:15672 user@YOUR_SERVER_IP
```

Then temporarily publish management in `compose.yaml` only bound to localhost, or `docker compose exec rabbitmq …`. Prefer tunnel + localhost bind; never expose `15672` to `0.0.0.0` on a public VPS.

## HTTPS and domain (later)

This stack speaks **HTTP only**. When you have a domain:

1. Point DNS A-record to the VPS.
2. Install Caddy or nginx **on the host** (or another compose service).
3. Terminate TLS there and reverse-proxy to `http://127.0.0.1:80` (or the `APP_HTTP_PORT` you chose).
4. Set `DEFAULT_URI=https://your.domain`.

Until then, use `http://YOUR_SERVER_IP`.

## Local development without Docker

You can still run PHP built-in server for quick checks (`php -S 127.0.0.1:8000 -t public`), but Postgres/RabbitMQ/worker match production only via Compose. On a machine with Docker:

```bash
cp .env.example .env
# adjust secrets if you want
docker compose up -d --build
curl -s http://127.0.0.1/check
```
