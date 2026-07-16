# PROJ-HOWTO.summary — database-utils

Task list only — see [PROJ-HOWTO.md](PROJ-HOWTO.md) for full guides.

- **Install the tools** — get `liquibase-shell`, `liquibase-update`, `provision-db`, and `tsdb-snapshot` on your `$PATH`.
- **Open a Liquibase shell against a cluster database** — run/preview migrations, or get a live psql/mysql connection, against a `liquibase_targets` entry in `.infra-config.yaml`.
- **Run the legacy one-shot Liquibase update Job** — apply a changelog via a Kubernetes Job instead of an interactive port-forward (e.g. from CI).
- **Provision a database + role on an already-running instance** — create the Postgres database/login role (and optionally a Valkey/Redis ACL user) for an app on an instance that's already running. → [howto/provision-db.md](howto/provision-db.md)
- **Take an application-consistent TimescaleDB snapshot** — produce an EBS snapshot bracketed with `pg_backup_start`/`stop` rather than a bare crash-consistent volume snapshot.
- **Open a Liquibase shell against a MySQL/MariaDB target** — run migrations or get a live `mysql` connection against a `db_type: mysql` target, same tool as Postgres.
- **Use the SQL templates for a new project** — stand up PgBouncer auth or a migration user for a project that isn't wired into `provision-db` yet.
