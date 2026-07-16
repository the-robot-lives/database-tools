# Project Layout

Terminal utility package: TimescaleDB snapshot, Liquibase migration, and database
provisioning/administration tools for K8s-hosted databases. Scripts install to
`~/.local/bin` via `make install` (symlinked, except `tsdb-snapshot` which is copied).

```
database-utils/
├── bin/                            # Executable tools + SQL templates
│   ├── liquibase-shell             #   Interactive Liquibase shell w/ kubectl port-forward; targets from infra-config.yaml
│   ├── liquibase-update            #   One-shot K8s Job running Liquibase update (gnp-backend schema), no Helm hook needed
│   ├── provision-db                #   Create Postgres DB + role (and optional Valkey ACL user) on a running cluster instance
│   ├── tsdb-snapshot               #   App-consistent EBS snapshot of TimescaleDB volume (pg_backup_start/stop bracket)
│   ├── pgbouncer-auth-setup.sql    #   SQL template — pgbouncer auth user setup (run on primary; edit placeholders first)
│   └── sql/
│       └── create-migrate-user.sql #   SQL template — create migrate role on primary (run as postgres superuser)
├── docs/                           # Documentation
│   ├── PROJ-ARCH.md                #   Architecture overview
│   ├── PROJ-ARCH.summary.md        #   Architecture quick reference
│   ├── PROJ-LAYOUT.md              #   This file
│   ├── PROJ-LAYOUT.summary.md      #   Layout quick reference
│   └── liquibase-shell-spec.md     #   liquibase-shell design/behavior spec
├── .gitignore                      # Ignores editor swap files, .env, .envrc.local
├── Makefile                        # `make install` → symlinks/copies tools to ~/.local/bin
└── README.md                       # Start here — install, prerequisites, configuration
```

## Notes

- **Config resolution** (`liquibase-shell`): `$LIQUIBASE_CONFIG` → `./infra-config.yaml` → repo-root `infra-config.yaml` → `.infra-config.yaml` variants.
- **SQL files are templates** — copy and customize manually; `make install` does not deploy them.
- Scripts source the shared `k8-lib` assist helper (`~/.local/share/k8-lib`) when present for `--assist` AI help.

## Key Files Requiring Setup

| File | Action |
|------|--------|
| `infra-config.yaml` / `.infra-config.yaml` | Must exist in cwd or repo root (or set `$LIQUIBASE_CONFIG`) for liquibase tools |
| `bin/pgbouncer-auth-setup.sql` | Replace placeholder variables before running on primary |
| `bin/sql/create-migrate-user.sql` | Run as postgres superuser with `${DB_HOST}`/`${DB_NAME}` substituted |
