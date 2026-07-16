# How to: provision a database + role on an already-running instance

**Goal:** create the Postgres database/login role (and optionally a Valkey/Redis ACL user) for an app on a Postgres/Valkey instance that's already running — the case `initdb.d/` scripts can't cover since those only run on first init of an empty data dir.

**Prereqs:**
- `yq` (v4+), `kubectl`, `dc` on `$PATH`; `psql` for the DB step, `redis-cli` for the Redis step
- App's connection info already present under `liquibase_targets.<target>` in `.infra-config.yaml`
- Provisioning fields added to that same target block (see below)
- Role/ACL-user password already set in `dc` (it's the source of truth these creds sync from — same value Infisical pushes into the app's K8s secret)

## 1. Add provisioning fields to the target

Extend the existing `liquibase_targets.<target>` entry — don't create a new section:

```yaml
liquibase_targets:
  ddi:
    namespace: apps-ns
    service: svc/app-timescaledb
    remote_port: 5432
    local_port: 55432
    db_type: postgresql
    db_name: ddi
    username: ddi
    # --- provisioning fields ---
    role_password_dc: "services apps.ddi_db_password"   # required for the DB step
    role_user_dc:     "services apps.ddi_db_user"        # optional; defaults to `username`
    admin_secret:     app-timescaledb-secrets             # default; superuser creds live here
    admin_user_key:   POSTGRES_USER                       # default
    admin_password_key: POSTGRES_PASSWORD                 # default
    # --- optional Valkey/Redis ACL user ---
    redis_password_dc: "auto ddi_valkey_password"         # setting this enables the redis step
    redis_user:       ddi                                 # default: target `username`
    redis_acl_rules:  "~* &* +@all"                       # default: full access
```

Two credential sources are deliberate, not accidental:
- **Role/ACL-user creds** come from `dc` — the same value that syncs into the app's K8s secret via Infisical, so the role you create matches what the app will actually authenticate with.
- **Superuser/admin creds** come from the *live* K8s admin secret, because the instance's auto-generated superuser password is not (and should not be) pinned in `dc` — it drifts, and the live secret is the only reliable source.

## 2. Provision it

```bash
provision-db --list                 # confirm the target name and see what's configured
provision-db ddi --dry-run          # preview what would run — no changes made
provision-db ddi                    # create the DB + role, and the Redis ACL user if configured
```

Narrower runs:
```bash
provision-db ddi --skip-redis       # DB/role only (alias: --db-only)
provision-db ddi --redis-only       # Redis ACL user only, DB already provisioned
```

**Verify:**
```bash
liquibase-shell ddi --shell
# then, inside the shell:
psql -c "\l" | grep ddi     # database exists
psql -c "\du" | grep ddi    # role exists
```
For Redis: `redis-cli -h <host> -p <redis_local_port> --user ddi --pass <pw> ACL WHOAMI`

## Gotchas

- **A live `ACL SETUSER` on app-valkey does not survive a pod restart.** The Redis ACL user this tool creates via `--redis-only`/the redis step takes effect immediately but is *runtime-only* — app-valkey's users are re-applied from the deployment's `--user` args at pod start, which wipes anything set live. For a durable fix, add the user to the `acl_users` map in `terraform/kubernetes/apps/init/main.tf` plus an `<APP>_VALKEY_PASSWORD` entry under `/apps/valkey`, then let Terraform redeploy the pod.
- **Missing `role_password_dc` fails the DB step immediately** — it's required, not optional, because there's no safe default password to fall back to.
- **The Redis step only runs when `redis_password_dc` is set on the target.** Omitting it is how you keep a target Postgres-only; there's no separate `--enable-redis` flag.
- **`admin_secret`/`admin_*_key` default to the TimescaleDB superuser conventions** (`app-timescaledb-secrets`, `POSTGRES_USER`, `POSTGRES_PASSWORD`). Override them explicitly for a target on a differently-named instance rather than assuming the defaults apply.
