# Project Layout — database-utils

Terminal utility package: Liquibase migration, on-demand DB/role provisioning,
TimescaleDB EBS snapshot, and SQL admin templates for K8s-hosted databases.
Installs to `~/.local/bin` via `make install` (or monorepo `make install-utilities`).
Dual-path: `Portfolio/Utilities/source/database-utils` ↔ `utilities/database/database-utils`.

Plain tree: [PROJ-LAYOUT.summary.md](PROJ-LAYOUT.summary.md).
Arch: [PROJ-ARCH.md](PROJ-ARCH.md). How-to: [PROJ-HOWTO.md](PROJ-HOWTO.md).

```
database-utils/
├── bin/                            # Executables + SQL templates
│   ├── liquibase-shell             #   Interactive/one-shot Liquibase via kubectl port-forward
│   ├── liquibase-update            #   Legacy one-shot in-cluster Liquibase Job (gnp-backend)
│   ├── provision-db                #   Create Postgres DB/role + optional Valkey ACL on live instance
│   ├── tsdb-snapshot               #   App-consistent EBS snapshot (pg_backup_start/stop bracket)
│   ├── pgbouncer-auth-setup.sql    #   Template: PgBouncer auth_user + get_auth() (run on primary)
│   └── sql/
│       └── create-migrate-user.sql #   Template: migrate role w/ scoped DDL (run as postgres)
├── docs/
│   ├── PROJ-ARCH.md(+.summary)     #   Architecture overview + quick reference
│   ├── PROJ-LAYOUT.md(+.summary)   #   This file + tree-only companion
│   ├── PROJ-HOWTO.md(+.summary)    #   Task guides index + compact companion
│   ├── PROJ-FAQ.md(+.summary)      #   FAQ + compact companion
│   ├── liquibase-shell-spec.md     #   liquibase-shell design/behavior spec
│   └── howto/
│       └── provision-db.md         #   Full provision-db walkthrough (fields, dc, verify)
├── CHANGELOG.md                    # Package changelog / milestones
├── .gitignore                      # .DS_Store, editor swap, .env, .envrc.local
├── Makefile                        # compile/test no-ops; install → ~/.local/bin
└── README.md                       # Start here — install, prereqs, config, usage
```

## Install mapping (`make install`)

| Source | Install path | Method |
|--------|--------------|--------|
| `bin/liquibase-shell` | `~/.local/bin/liquibase-shell` | symlink |
| `bin/liquibase-update` | `~/.local/bin/liquibase-update` | symlink |
| `bin/provision-db` | `~/.local/bin/provision-db` | symlink |
| `bin/tsdb-snapshot` | `~/.local/bin/tsdb-snapshot` | copy (`install -m 755`) |
| `bin/*.sql`, `bin/sql/*` | *(not installed)* | copy/customize manually |

Override destination: `INSTALL_DIR=/other/path make install`.

## Notes

- **Config** (repo-level, not in this package): `.infra-config.yaml` / `infra-config.yaml`.
  - `liquibase-shell` / `provision-db`: `liquibase_targets` or `databases` (first non-empty).
  - `tsdb-snapshot`: `tsdb_snapshot_targets`; `--config <name>` selects a target, not a file path.
  - Override file for liquibase tools: `$LIQUIBASE_CONFIG`.
- **Config resolution** (`liquibase-shell`): `$LIQUIBASE_CONFIG` → `./infra-config.yaml` → git-root → `.infra-config.yaml` variants.
- **k8-lib**: scripts source `~/.local/share/k8-lib` (`common.sh` / `assist.sh`) when present for shared helpers and `--assist`.
- **Default KUBECONFIG**: `liquibase-shell` sets `~/.kube/noizu/config` when unset.
- **SQL templates** are not deployed by install; edit placeholders before running on primary.
- **Makefile**: `compile` / `test` are no-ops; only `install` does work.

## Key Files Requiring Setup

| File / artifact | Action |
|-----------------|--------|
| `infra-config.yaml` / `.infra-config.yaml` | Define `liquibase_targets` / `databases` and `tsdb_snapshot_targets` (cwd or monorepo root; or `$LIQUIBASE_CONFIG`) |
| Target `role_password_dc` (+ optional redis fields) | Required on the liquibase target for `provision-db --db` / Valkey ACL |
| `bin/pgbouncer-auth-setup.sql` | Replace `${DB_*}` placeholders; run on primary only |
| `bin/sql/create-migrate-user.sql` | Substitute vars; run as postgres; set password from Infisical after |
