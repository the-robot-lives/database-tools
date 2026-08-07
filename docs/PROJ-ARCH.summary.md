# Project Architecture Summary

Bash/SQL package for K8s PostgreSQL/TimescaleDB (+ Valkey) ops in Noizu Infra.
Config outside package: `liquibase_targets` / `databases` and
`tsdb_snapshot_targets` in monorepo `infra-config.yaml` / `.infra-config.yaml`.
Install: `make install` → `~/.local/bin`. Dual path:
`Portfolio/Utilities/source/database-utils` ↔ `utilities/database/database-utils`.

## Components

- **liquibase-shell** — port-forward + K8s-secret creds; menu / `-- <cmd>` /
  `--shell`; local liquibase or Docker 4.29; `safety` + `--yes`; prefers
  `liquibase_targets` then `databases`
- **liquibase-update** — hardcoded gnp-backend one-shot Job; no infra-config
- **provision-db** — live CREATE DB/role (+ extensions); optional Valkey ACL;
  role/ACL pw from `dc`, admin from K8s secret; `databases` // `liquibase_targets`
- **tsdb-snapshot** — app-consistent EBS snap (`pg_backup_start/stop` session);
  `--crash-only` for standbys; needs k8-lib common + assist
- **pgbouncer-auth-setup.sql** / **sql/create-migrate-user.sql** — manual templates
- **Makefile** — symlink three shells, copy tsdb-snapshot; SQL not installed

## Design Principles

- Topology in YAML, not flags; operator interactivity via port-forward
- Split creds: dc for app secrets, live K8s for instance admin
- Consistent snapshots default; crash-only opt-in
- Cleanup traps for port-forwards and Postgres backup mode
- SQL templates reviewed/customized before primary execution

## Dependencies

kubectl, yq v4+, liquibase|Docker, psql, redis-cli, nc, dc, aws CLI;
k8-lib assist (update/provision/snapshot); k8-lib common (snapshot only)

## Ecosystem Fit

Monorepo utilities; `make install-utilities`; same `.infra-config.yaml` +
dc → Infisical → K8s Secrets flow as other DevOps tools.
