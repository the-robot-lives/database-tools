# AGENT-README

> Orientation for AI coding agents working in this repo. Human docs: README.md.

## Type

scripts

## Purpose

Liquibase migration shells (`liquibase-shell`, `liquibase-update`), database provisioning (`provision-db`), and TimescaleDB snapshot helpers (`tsdb-snapshot`) for cluster-hosted Postgres/MySQL, reached through kubectl port-forwards with credentials pulled from Kubernetes Secrets.

## Stack

Bash CLIs in `bin/`; wraps Liquibase (local CLI or `liquibase/liquibase:4.29` Docker fallback); targets resolved from `infra-config.yaml` `liquibase_targets`; needs `yq`, `nc`, optional `psql`/`mysql`.

## Dev mode

```bash
make install    # liquibase-shell, liquibase-update, provision-db, tsdb-snapshot -> ~/.local/bin
make test       # placeholder (no-op)
liquibase-shell <target> -- status
```

## Ports / URLs

- none (library/CLI). Tools open kubectl port-forwards per target (`local_port`, e.g. 54320 → service port 5432) defined in `liquibase_targets`.

## Tests

```bash
make test      # placeholder (no-op)
```

## Gotchas

- Targets come from the resolved `.infra-config.yaml` / `infra-config.yaml` (override with `LIQUIBASE_CONFIG`); first non-empty of `liquibase_targets` / `databases` wins.
- Credentials are pulled from Kubernetes Secrets per target (`secret_name` + `username_key`/`secret_key`, with `_fallbacks` alternates) — never hardcode.
- Non-interactive/agent use: `liquibase-shell --yes <target> -- …` or `LIQUIBASE_ASSUME_YES=1` skips destructive confirms.
- "Liquibase owns the schema" is monorepo-wide: run migrations here after changelog changes merge; deployment itself is CI/CD-driven.
