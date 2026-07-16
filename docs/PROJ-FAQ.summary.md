# PROJ-FAQ.summary — database-utils

Question list only — see [PROJ-FAQ.md](PROJ-FAQ.md) for full answers.

## Motivation
- Why would I use `provision-db` instead of just re-running my `initdb.d/` scripts?
- Why bracket TimescaleDB snapshots with `pg_backup_start`/`stop` instead of just snapshotting the EBS volume?
- Why does `make install` symlink `liquibase-shell`/`liquibase-update`/`provision-db` but *copy* (`install -m 755`) `tsdb-snapshot`?
- Why does `provision-db` split credential sourcing between `dc` and the live K8s secret instead of just reading everything from one place?

## Fit
- When should I reach for `liquibase-update` (the Job) instead of `liquibase-shell`?
- When should I use `--crash-only` instead of the default app-consistent bracket on `tsdb-snapshot`?
- Is this toolkit the right choice for a database that isn't in `.infra-config.yaml` yet?

## Comparison
- How does `provision-db` differ from just running `kubectl exec -it ... -- psql` and typing the `CREATE DATABASE`/`CREATE ROLE` myself?
- How does `liquibase-shell` differ from `liquibase-update`?

## Capability
- Can `provision-db` create a Valkey/Redis ACL user, not just a Postgres role?
- Does `liquibase-shell` work against MySQL/MariaDB targets, or only Postgres?
- Can `tsdb-snapshot` run against a replica, or only a primary?

## Caveats
- What's the risk of running `tsdb-snapshot` (default mode) on a busy primary?
- Is it safe to run the SQL templates (`bin/pgbouncer-auth-setup.sql`, `bin/sql/create-migrate-user.sql`) as-is?
- If `KUBECONFIG` is wrong, will I get an obvious error?
- Why does `--shell` mode export `MYSQL_HOST`/`MYSQL_TCP_PORT`/`MYSQL_PWD` for a MySQL target but not `MYSQL_USER`/`MYSQL_DATABASE` the way it exports a full Postgres connection?
- What happens if I open `liquibase-shell` against a target that has no `changelog_dir`/`changelog_file` configured?
- Can a `safety: readonly` target still run `update`/destructive Liquibase commands if I really want to?

## Trust
- Does `provision-db` generate or store secrets of its own?
- Does `liquibase-shell --shell` leave database passwords lying around after I exit?
