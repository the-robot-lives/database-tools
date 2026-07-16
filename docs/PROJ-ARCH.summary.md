# Project Architecture Summary

Terminal utility package: CLI tools + SQL templates for administering K8s-hosted
PostgreSQL/TimescaleDB and Valkey in the Noizu infrastructure. Config-driven off
`infra-config.yaml` / `.infra-config.yaml` (`liquibase_targets`,
`tsdb_snapshot_targets`); installs to `~/.local/bin` via `make install`; sources
shared `k8-lib` for helpers and `--assist`.

## Components

- **bin/liquibase-shell** — interactive/one-shot Liquibase via kubectl port-forward; K8s-secret creds; `--shell` exports PG*/LB_* env
- **bin/liquibase-update** — legacy one-shot in-cluster Liquibase Job (hardcoded gnp-backend target)
- **bin/provision-db** — create Postgres DB/role + optional Valkey ACL user on a running instance (post-initdb apps)
- **bin/tsdb-snapshot** — app-consistent EBS snapshot bracketed by pg_backup_start/stop; `--crash-only` for standbys
- **bin/pgbouncer-auth-setup.sql** — template: PgBouncer auth user (SECURITY DEFINER) + read-only user
- **bin/sql/create-migrate-user.sql** — template: migration role with scoped DDL privileges
- **Makefile** — symlinks the three shell tools, copies tsdb-snapshot

## Design Principles

- Config-driven targets in .infra-config.yaml, not script flags
- Port-forward + local tooling for interactivity; in-cluster Job only for legacy path
- App-consistent snapshots by default; crash-only opt-in
- Split credential sourcing: role/ACL creds from dc, live admin creds from K8s secret
- Template-based SQL with manual review before execution
- Cleanup traps release port-forwards and Postgres backup mode on any exit

## Dependencies

k8-lib (common.sh/assist.sh), kubectl, liquibase, yq v4+, aws CLI, dc, psql, redis-cli, nc

## Ecosystem Fit

Part of the Noizu Infra monorepo utilities; installed by repo-root
`make install-utilities`; shares `.infra-config.yaml` conventions and the
dc → Infisical → K8s Secrets flow with the other DevOps tools.
