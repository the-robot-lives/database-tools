# database-tools

**Repo:** https://github.com/the-robot-lives/database-tools

Liquibase migration shells, database provisioning, and TimescaleDB snapshot helpers for the Noizu Kubernetes fleet.

## What

Bash CLIs that wrap Liquibase and direct database administration against databases running in the cluster — reached through kubectl port-forwards with credentials pulled from Kubernetes Secrets. "Liquibase owns the schema" is a monorepo-wide rule; these tools are how agents and humans run it.

## Why

Every portfolio app's schema migrations go through Liquibase, but Liquibase itself is awkward to drive against a cluster-hosted Postgres/MySQL: you need a port-forward, the right secret keys, the right changelog path, and a container or local install. These tools encode that wiring per target in `infra-config.yaml` so a migration is one command (`liquibase-shell <target> -- update`) instead of a checklist. `provision-db` and the SQL templates cover the surrounding admin work (migration users, PgBouncer auth).

## Getting Started

Prerequisites:

- `kubectl` with cluster access
- `liquibase` CLI, or Docker Desktop (the `liquibase/liquibase:4.29` image is the fallback)
- `yq` for config parsing; `nc` for port-forward readiness checks
- `psql` / `mysql` for `--shell` direct-DB mode (optional)

```bash
make install    # liquibase-shell, liquibase-update, provision-db (symlinked),
                # tsdb-snapshot -> ~/.local/bin
make test       # placeholder (no-op)
```

Also installed by the monorepo root `make install-utilities`. Migrations land via this tooling in repos/changelogs — deployment itself is CI/CD-driven; run `liquibase-shell` after changelog changes merge.

## Usage

```bash
liquibase-shell                          # prompt for a target
liquibase-shell start-app                # interactive Liquibase menu
liquibase-shell start-app -- status      # pass through Liquibase commands
liquibase-shell start-app -- update-sql
liquibase-shell start-app --shell        # connection shell (env vars exported)
liquibase-shell shared-postgres -- --changelog-file=/path/to/changelog.yaml status

liquibase-update                         # legacy one-shot Liquibase update Job
tsdb-snapshot                            # create/manage TimescaleDB snapshots
```

Non-interactive / agent use:

```bash
liquibase-shell --yes therobotplans -- status          # skip destructive confirms
LIQUIBASE_ASSUME_YES=1 liquibase-shell therobotplans -- update
```

## Configuration

Targets come from the resolved `infra-config.yaml` / `.infra-config.yaml` (override with `LIQUIBASE_CONFIG`). First non-empty of `liquibase_targets` / `databases` wins. A target names the k8s service to port-forward, the secret keys for credentials, and optionally the changelog:

```yaml
liquibase_targets:
  start-app:
    namespace: data-ns
    service: svc/shared-postgres
    remote_port: 5432
    local_port: 54320
    db_type: postgresql
    db_name: startapp
    schema: public
    secret_name: data-postgres-secrets
    username_key: STARTAPP_DB_USER
    secret_key: STARTAPP_DB_PASSWORD
    safety: destructive
    changelog_dir: incubator/start-app/backend/db
    changelog_file: changelog/db.changelog-master.yaml
```

`username_key_fallbacks` / `secret_key_fallbacks` list alternates. Instance-level targets (e.g. `shared-postgres`) may omit a changelog and become connection shells unless `--changelog-file` is supplied.

## How It Works

- `liquibase-shell` opens the kubectl port-forward, waits on it (`nc`), pulls credentials from the named Secret, and either drives Liquibase (local CLI or Docker fallback) or exports `LB_DEFAULTS_FILE`, `PG*`/connection env, and `LB_CHANGELOG_PATH`/`LB_CHANGELOG_DIR` for `--shell` mode while keeping the forward alive.
- SQL templates — `bin/pgbouncer-auth-setup.sql` (PgBouncer auth) and `bin/sql/create-migrate-user.sql` (migration user) — are copy-and-customize, not auto-executed.

## Repo Layout

- `bin/` — the tools plus SQL templates
- `docs/` — PROJ-ARCH/HOWTO/LAYOUT notes
