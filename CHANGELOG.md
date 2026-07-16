# Changelog — utilities/database/database-utils

## [Unreleased]
- PROJ-ARCH.md / PROJ-LAYOUT.md (+ `.summary.md` companions) expanded with fuller architecture and directory-layout documentation.

## [m4-provision-db] — 2026-07-08 — tag: `utilities-database-database-utils/m4-provision-db`
New `provision-db` tool: creates the Postgres database + login role for an app on an already-running cluster instance, since a live instance only runs `initdb.d/` scripts on first init of an empty data dir — apps added later never get provisioned automatically. Reuses `liquibase_targets.<target>` from `.infra-config.yaml` for connection details; splits credential sourcing so role creds come from `dc` (source of truth, mirrors Infisical-synced secrets) while superuser creds come from the live K8s admin secret (auto-generated, not pinned in `dc`).

### Added
- `bin/provision-db` — create-db-and-role tool for running instances (initial 219-line landing, then hardened/expanded to 308 lines same day)
- Makefile: symlink-install `provision-db` alongside `liquibase-shell`/`liquibase-update`

## [m3-tsdb-snapshot-safety] — 2026-07-07 — tag: `utilities-database-database-utils/m3-tsdb-snapshot-safety`
Hardened `tsdb-snapshot`'s backup-bracketing wait against slow checkpoints on busy primaries, and made timeout/failure modes distinguishable.

### Changed
- Backup-bracket wait is now configurable (`K8_TSDB_PSQL_WAIT_SECS`, default 900s) instead of a fixed short timeout, since `pg_backup_start(fast=false)` waits for the next scheduled checkpoint and can take several minutes under load
- psql session helper now returns distinct exit codes for "timed out" vs "session died" instead of collapsing both to a generic failure

## [m2-liquibase-shell-hardening] — 2026-06-25 — tag: `utilities-database-database-utils/m2-liquibase-shell-hardening`
Small maintenance pass: repo hygiene plus a KUBECONFIG default fix for `liquibase-shell`.

### Added
- `.gitignore` for local/generated files

### Fixed
- `liquibase-shell` now defaults `KUBECONFIG` to `~/.kube/noizu/config` when unset; previously an unset `KUBECONFIG` sent secret/port-forward `kubectl` calls to whatever context the shell happened to default to, causing the password fetch to silently fail with "Tried keys: DB_PASSWORD" even though the key existed

## [m1-initial-import] — 2026-06-13 — tag: `utilities-database-database-utils/m1-initial-import`
Initial import of the database-utils toolkit as a subtree merge — established the package's baseline surface.

### Added
- `liquibase-shell` — interactive Liquibase shell against a port-forwarded cluster DB
- `liquibase-update` — Liquibase changelog update runner
- `tsdb-snapshot` — application-consistent EBS snapshot of TimescaleDB volumes via `pg_backup_start`/`stop` bracketing
- `bin/pgbouncer-auth-setup.sql`, `bin/sql/create-migrate-user.sql` — SQL templates
- `docs/PROJ-ARCH.md`, `docs/liquibase-shell-spec.md`
- `Makefile`, `README.md`
