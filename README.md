# booking

Symfony booking API and Twig UI. Same Docker stack locally and on the VPS: `app`, `worker`, `db`, `rabbitmq`.

## Development cycle (local ↔ server)

```text
PC (Docker Desktop)              GitHub                 VPS (Docker)
─────────────────────            ──────                 ────────────
compose.yaml          ──push──►  compose.yaml  ──pull─► compose.yaml
compose.override.yaml (local only, not in git)
.env (local secrets)                                    .env (server secrets)
edit PHP / Twig → refresh                               rebuild image → up -d
```

| | Local PC | VPS |
|--|----------|-----|
| Compose files | `compose.yaml` + `compose.override.yaml` | **only** `compose.yaml` |
| Code | Bind-mounted from your disk (edit → refresh) | Baked into the image on `build` |
| `APP_ENV` | `dev` | `prod` |
| HTTP | `http://127.0.0.1:8080` | port `80` (or your `APP_HTTP_PORT`) |
| DB / Rabbit ports | Published (5432, 5672, 15672) | Not published |

**Rule:** never copy `compose.override.yaml` to the server. It is gitignored on purpose.

---

## Local setup (first time)

1. Install **Docker Desktop** and wait until it is running (`docker version` shows Server).
2. In the project folder:

```bash
cp .env.example .env
cp compose.override.yaml.example compose.override.yaml
```

3. Edit `.env` for local use (example values are fine for a laptop):

| Variable | Local suggestion |
|----------|------------------|
| `APP_SECRET` | any long random string |
| `APP_ENV` | `dev` (override also forces `dev`) |
| `APP_DEBUG` | `1` |
| `APP_HTTP_PORT` | `8080` |
| `DEFAULT_URI` | `http://127.0.0.1:8080` |
| passwords | can stay simple (`booking`) on a laptop |

4. Build and start:

```bash
docker compose build
docker compose up -d
```

5. Check:

```bash
docker compose ps
curl -s http://127.0.0.1:8080/check
```

Expected: `{"ok":true}`

RabbitMQ UI (local only): http://127.0.0.1:15672 (user/password from `.env`).

### Day-to-day local work

```bash
# start
docker compose up -d

# stop (DB data kept in volume)
docker compose down

# logs
docker compose logs -f app
docker compose logs -f worker

# Symfony console inside the container
docker compose exec app php bin/console debug:router

# after composer.json / Dockerfile / docker/* changes
docker compose build
docker compose up -d
```

Changing PHP/Twig/config under bind-mount usually needs **no rebuild** — refresh the browser.  
Changing `composer.json` / lock: either rebuild, or:

```bash
docker compose exec app composer install --ignore-platform-req=ext-amqp
```

---

## VPS deploy (production)

No `compose.override.yaml` on the server.

```bash
git clone <YOUR_REPO_URL> booking
cd booking
cp .env.example .env
nano .env   # strong passwords, APP_ENV=prod, APP_DEBUG=0, APP_HTTP_PORT=80, DEFAULT_URI=http://YOUR_IP
docker compose build
docker compose up -d
curl -s http://127.0.0.1/check
```

### Update after you push from the PC

```bash
cd booking
git pull
docker compose build
docker compose up -d
# when migrations exist:
# docker compose exec app php bin/console doctrine:migrations:migrate --no-interaction
```

### Useful on the server

```bash
docker compose ps
docker compose logs -f app
docker compose exec app php bin/console debug:router
docker compose down          # keep DB volume
docker compose down -v       # destroy DB volume
```

Do **not** publish Postgres `5432` or RabbitMQ `15672` to the public internet.

---

## Services

| Service | Role |
|---------|------|
| `app` | nginx + PHP-FPM |
| `worker` | `messenger:consume async` |
| `db` | PostgreSQL 16 |
| `rabbitmq` | AMQP (+ management plugin in the image) |

Memory limits in `compose.yaml` target a ~2 GB VPS. Local override raises them a bit for Docker Desktop.

---

## HTTPS / domain (later)

Stack is HTTP only. Later: Caddy/nginx on the host → proxy to `127.0.0.1:80`, set `DEFAULT_URI=https://your.domain`.

---

## Files you should know

| File | Role |
|------|------|
| `compose.yaml` | Shared stack (what runs on VPS) |
| `compose.override.yaml.example` | Template for local overrides |
| `compose.override.yaml` | Your local overrides (not in git) |
| `Dockerfile` | Image for `app` and `worker` |
| `.env.example` | Env template |
| `.env` | Real secrets (not in git) |
