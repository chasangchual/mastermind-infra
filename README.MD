# Grit Local Infrastructure (Data Pipeline Stack)

This repository provisions a local infrastructure stack for development and testing.

## Services

### Core (docker-compose.yml)
- **PostgreSQL 17 + pgvector** (application database, vector search)
- **Authentik** (identity provider - server + worker)
- **RustFS** (S3-compatible object storage; `mastermind` and Langfuse buckets created on startup)
- **Neo4j 5** (graph database)
- **Redis 7** (caching)
- **RabbitMQ 4** (message broker)
- **Qdrant** (vector database)
- **ClickHouse** (analytics store for Langfuse)
- **Langfuse** (LLM observability - web + worker)

### Additional Stacks
- **docker-compose-full.yml**: Full stack with Airflow, SFTP, Mailserver
- **docker-compose-db.yml**: Database services only (PostgreSQL, Neo4j, Redis)
- **docker-compose-n8n.yml**: n8n workflow automation

---

## 1. Prerequisites

- **Docker Engine / Docker Desktop**
- **Docker Compose v2**
- **System Memory:** minimum 4 GB, 8 GB+ recommended
- **Mac users (Apple Silicon):** install **Rosetta 2** if needed for certain services
```bash
softwareupdate --install-rosetta
```

---

## 2. Files

### docker-compose.yml
Core services: PostgreSQL, Authentik, RustFS, Neo4j, Redis, RabbitMQ, Qdrant, ClickHouse, Langfuse

### docker-compose-full.yml
Full stack including:
- Airflow 2.8.1 (LocalExecutor, no Celery)
- SFTP (source data simulation)
- Docker Mailserver

### init-db.sh
PostgreSQL initialization script that:
- Creates the Authentik, Prefect, Mastermind, and Langfuse databases if they don't exist
- Enables `vector` extension in the primary database
- Enables `vector` extension in the Authentik database

### .env.dev / .env.prod
Per-environment configuration. Copy from `.env.example` and customize (see [Environments](#environments-dev--prod)).

---

## 3. Environment Variables

### Required (.env.example)

```dotenv
# Environment
COMPOSE_PROJECT_NAME=mastermind-dev
ENV_FILE=.env.dev

# PostgreSQL
POSTGRES_DB=grit
POSTGRES_USER=grit-admin
POSTGRES_PASSWORD=<db_password>
POSTGRES_PORT=5432

# RustFS
RUSTFS_ACCESS_KEY=mastermind
RUSTFS_SECRET_KEY=<rustfs_secret>
RUSTFS_SERVICE_PORT=9000
RUSTFS_CONSOLE_PORT=9001
RUSTFS_BUCKET=mastermind

# Neo4j
NEO4J_DATABASE=neo4j
NEO4J_USER=neo4j
NEO4J_PASSWORD=<neo4j_password>

# Redis
REDIS_PORT=6379
REDIS_PASSWORD=<redis_password>

# Authentik
AUTHENTIK_DB=authentik
AUTHENTIK_SECRET_KEY=<generated_secret_key>
COMPOSE_PORT_HTTP=9400
COMPOSE_PORT_HTTPS=9443

# RabbitMQ
RABBIT_MQ_USER=rabbit_admin
RABBIT_MQ_PASSWORD=<rabbitmq_password>
RABBIT_MQ_VHOST=mastermind
RABBIT_MQ_PORT=5672
RABBIT_MQ_MANAGEMENT_PORT=15672

# Qdrant
QDRANT_API_KEY=<qdrant_api_key>
QDRANT_REST_PORT=6333
QDRANT_GRPC_PORT=6334

# ClickHouse (Langfuse analytics store)
CLICKHOUSE_USER=clickhouse
CLICKHOUSE_PASSWORD=<clickhouse_password>
CLICKHOUSE_DB=default
CLICKHOUSE_HTTP_PORT=8123
CLICKHOUSE_TCP_PORT=9004

# Langfuse
LANGFUSE_DB=langfuse
LANGFUSE_SALT=<generated_salt>
LANGFUSE_ENCRYPTION_KEY=<generated_64_char_hex_key>
LANGFUSE_NEXTAUTH_SECRET=<generated_secret>
LANGFUSE_NEXTAUTH_URL=http://localhost:4000
LANGFUSE_S3_BUCKET=langfuse
LANGFUSE_WORKER_PORT=3030
LANGFUSE_WEB_PORT=4000
```

### Generating Secrets

**Authentik Secret Key:**
```bash
openssl rand -base64 50
```

**Langfuse Salt / Encryption Key / NextAuth Secret:**
```bash
openssl rand -hex 32
```

**For Airflow (if using docker-compose-full.yml):**
```bash
python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```

---

## Environments (dev / prod)

Dev and prod share the same `docker-compose.yml`; each has its own env file.
`COMPOSE_PROJECT_NAME` keeps their containers, network and volumes separate
(e.g. `mastermind-dev_postgres_data` vs `mastermind-prod_postgres_data`).

### Setup

```bash
cp .env.example .env.dev
cp .env.example .env.prod
```

In `.env.prod` set:

```dotenv
COMPOSE_PROJECT_NAME=mastermind-prod
ENV_FILE=.env.prod
```

and generate **different** secrets for every password/key. If dev and prod run on
the same host, also change every `*_PORT` in `.env.prod` so they don't collide.

`ENV_FILE` must match the file you pass to `--env-file`; some services load it
directly via `env_file:`. `.env.dev` and `.env.prod` are gitignored.

### Usage

Pass `--env-file` to **every** compose command:

```bash
# Dev
docker compose --env-file .env.dev up -d
docker compose --env-file .env.dev ps
docker compose --env-file .env.dev logs -f authentik
docker compose --env-file .env.dev down

# Prod
docker compose --env-file .env.prod up -d
docker compose --env-file .env.prod exec postgresql psql -U mastermind -d mastermind
docker compose --env-file .env.prod down
```

Tip: shell aliases avoid forgetting the flag:

```bash
alias dc-dev='docker compose --env-file .env.dev'
alias dc-prod='docker compose --env-file .env.prod'
```

> Plain `docker compose ...` (no `--env-file`) still works with a single `.env` file.

---

## 4. Quick Start

### Initial Setup

```bash
# Copy environment file (see Environments section for prod)
cp .env.example .env.dev

# Edit .env.dev with your values
nano .env.dev

# Create required directories
mkdir -p ./airflow/dags ./airflow/logs ./airflow/plugins ./sftp_upload

# Set permissions
chmod -R 777 ./airflow
chmod +x init-db.sh
```

### Start Services

**Core stack:**
```bash
docker compose --env-file .env.dev up -d
```

**With Airflow and additional services:**
```bash
docker compose -f docker-compose-full.yml up -d
```

**n8n only:**
```bash
docker compose -f docker-compose-n8n.yml up -d
```

### Check Status

```bash
docker compose ps
```

### View Logs

```bash
docker compose logs postgresql
docker compose logs authentik
docker compose logs -f authentik  # Follow logs
```

---

## 5. Service Endpoints

After startup, access these services:

| Service | Endpoint | Default Credentials |
|---------|----------|---------------------|
| PostgreSQL | `localhost:5432` | From `.env` |
| Authentik UI | `http://localhost:9400` | Configure on first run |
| RustFS S3 API | `http://localhost:9000` | From `.env` |
| RustFS Console | `http://localhost:9001` | From `.env` |
| Neo4j Browser | `http://localhost:7474` | From `.env` |
| Neo4j Bolt | `localhost:7687` | From `.env` |
| Redis | `localhost:6379` | N/A |
| RabbitMQ Management | `http://localhost:15672` | From `.env` |
| Qdrant API/UI | `http://localhost:6333` | From `.env` |
| ClickHouse HTTP | `http://localhost:8123` | From `.env` |
| Langfuse UI | `http://localhost:4000` | Sign up on first run |
| Airflow UI (full stack) | `http://localhost:8080` | From `.env` |
| SFTP (full stack) | `localhost:2222` | From `.env` |
| n8n (n8n stack) | `http://localhost:5678` | N/A |

---

## 6. Verification

### PostgreSQL

```bash
# Check connection
docker compose exec postgresql psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT 1;"

# List databases
docker compose exec postgresql psql -U "$POSTGRES_USER" -d postgres -c "\l"

# Verify pgvector extension
docker compose exec postgresql psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "SELECT extname FROM pg_extension WHERE extname='vector';"
```

### Redis

```bash
docker compose exec redis redis-cli ping
# Expected: PONG
```

### Authentik

Access `http://localhost:${COMPOSE_PORT_HTTP:-9400}` and complete initial setup.

---

## 7. Troubleshooting

### Database Not Created

If `postgres_data` volume exists, `init-db.sh` won't re-run:

```bash
# Option 1: Manual creation
docker compose exec postgresql psql -U "$POSTGRES_USER" -d postgres -c "CREATE DATABASE authentik;"
docker compose exec postgresql psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE EXTENSION IF NOT EXISTS vector;"
docker compose exec postgresql psql -U "$POSTGRES_USER" -d authentik -c "CREATE EXTENSION IF NOT EXISTS vector;"

# Option 2: Clean reset
docker compose down -v
docker compose up -d
```

### Missing Environment Variables

Authentik requires `AUTHENTIK_SECRET_KEY`:
```bash
# Check .env
grep AUTHENTIK_SECRET_KEY .env

# Generate if missing
echo "AUTHENTIK_SECRET_KEY=$(openssl rand -base64 50)" >> .env
```

### Service Dependencies

Services depend on PostgreSQL health. If services fail:
```bash
# Check PostgreSQL health
docker compose exec postgresql pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB"

# Restart dependent services
docker compose restart authentik
```

### Port Conflicts

If ports are in use, edit `.env`:
```bash
# Change ports
POSTGRES_PORT=5433
RUSTFS_SERVICE_PORT=9002
```

---

## 8. Data Persistence

All services use named Docker volumes:

```bash
# List volumes
docker volume ls | grep grit

# Remove all data (destructive)
docker compose down -v
```

---

## 9. Stop Services

```bash
# Stop all services
docker compose down

# Stop and remove volumes (deletes all data)
docker compose down -v

# Stop specific stack
docker compose -f docker-compose-full.yml down
```

---

## 10. Alternative Configurations

### Database Only
```bash
docker compose -f docker-compose-db.yml up -d
```

### n8n Workflow Automation
```bash
docker compose -f docker-compose-n8n.yml up -d
```

### Combine Multiple Files
```bash
docker compose -f docker-compose.yml -f docker-compose-n8n.yml up -d
```

---

## Related Documentation

- PostgreSQL pgvector: https://github.com/pgvector/pgvector
- Authentik: https://goauthentik.io/docs/
- RustFS: https://docs.rustfs.com/
- Neo4j: https://neo4j.com/docs/
- Langfuse: https://langfuse.com/docs
- ClickHouse: https://clickhouse.com/docs
- Airflow: https://airflow.apache.org/docs/
- n8n: https://docs.n8n.io/
