# PROJ-HOWTO — database-utils

Task-oriented guides for the things you'll actually do with this toolkit. For
*what it is* see [PROJ-ARCH.md](PROJ-ARCH.md); for *where things live* see
[PROJ-LAYOUT.md](PROJ-LAYOUT.md).

## How to: install the tools

**Goal:** get `liquibase-shell`, `liquibase-update`, `provision-db`, and `tsdb-snapshot` on your `$PATH`.
**Prereqs:** `kubectl` w/ cluster access; `yq` (v4+); `liquibase` (for the Liquibase tools); `nc`; `psql`/`mysql` for `--shell` mode; `dc` + `redis-cli` for `provision-db`.

1. From this directory:
   ```bash
   make install
   ```
   Installs to `$HOME/.local/bin` by default (override with `INSTALL_DIR=/other/path make install`).
2. `liquibase-shell`, `liquibase-update`, and `provision-db` are symlinked (edits to `bin/` take effect immediately); `tsdb-snapshot` is copied.

**Verify:**
```bash
which liquibase-shell provision-db tsdb-snapshot
```
**Gotchas:**
- SQL templates (`bin/pgbouncer-auth-setup.sql`, `bin/sql/create-migrate-user.sql`) are **not** installed — copy and customize them manually per-project.
- `liquibase-shell` defaults `KUBECONFIG` to `~/.kube/noizu/config` only when unset; if you point at a different cluster, export `KUBECONFIG` yourself first.

## How to: open a Liquibase shell against a cluster database

**Goal:** run/preview migrations, or get a live psql/mysql connection, against a `liquibase_targets` entry in `.infra-config.yaml`.
**Prereqs:** target defined under `liquibase_targets` in the resolved `.infra-config.yaml`/`infra-config.yaml`; `KUBECONFIG` pointed at the right cluster.

1. List/pick a target and open the interactive menu:
   ```bash
   liquibase-shell start-app
   ```
2. Or run one command non-interactively:
   ```bash
   liquibase-shell start-app -- status        # pending changesets
   liquibase-shell start-app -- update-sql     # preview SQL, no changes applied
   liquibase-shell start-app -- update         # apply pending migrations
   ```
3. Or drop straight into a live DB connection (port-forward stays up, `psql`/`mysql` env vars pre-exported):
   ```bash
   liquibase-shell start-app --shell
   ```

**Verify:** the tool prints `==> Connected: <db_type> @ localhost:<port>/<db>` before handing control to the menu/shell.
**Gotchas:**
- Targets marked `safety: readonly` in config reject anything outside `status diff validate history update-sql rollback-count-sql changelog-sync-sql` — use a writable target (or `--shell` + manual SQL with intent) if you need `update`.
- A target with no `changelog_dir`/`changelog_file` configured has no changelog — `liquibase-shell <target>` opens a connection shell instead of the menu; pass `--changelog-file=...` to force one-shot Liquibase commands against it.
- `Failed to read password ... Tried keys: ...` almost always means `KUBECONFIG` is pointing at the wrong context, not a missing secret key.

## How to: run the legacy one-shot Liquibase update Job

**Goal:** apply a changelog via a Kubernetes Job instead of an interactive port-forward (e.g. from CI).
**Prereqs:** same `liquibase_targets` config as above; the target's changelog is reachable from the Job's image.

1. ```bash
   liquibase-update <target>
   ```
**Verify:** `kubectl get jobs -n <namespace>` shows the Job completed; check its logs for the applied changeset count.
**Gotchas:** this path predates `liquibase-shell --shell`/one-shot mode — prefer `liquibase-shell <target> -- update` for anything interactive; reach for `liquibase-update` only when you specifically need the Job-based execution model.

## How to: provision a database + role on an already-running instance

New apps added to a running Postgres/Valkey instance don't get auto-provisioned — only `initdb.d/` scripts on first init do that. `provision-db` does the create-on-a-live-instance step on demand.
→ *See [howto/provision-db.md](howto/provision-db.md)*

## How to: take an application-consistent TimescaleDB snapshot

**Goal:** produce an EBS snapshot that's crash-consistent-plus (bracketed with `pg_backup_start`/`stop`) rather than a bare crash-consistent volume snapshot.
**Prereqs:** target defined under `tsdb_snapshot_targets` in the resolved config; AWS creds with EBS snapshot permission; `K8_LIB_DIR` (`~/.local/share/k8-lib` by default) installed.

1. ```bash
   tsdb-snapshot --config gnp --label "pre-promote"
   ```
2. For a standby/replica volume where an app-consistent bracket isn't meaningful, skip it:
   ```bash
   tsdb-snapshot --config gnp-replica --crash-only
   ```

**Verify:** tool prints the created EBS snapshot ID; `aws ec2 describe-snapshots --filters Name=tag:Name,Values=<snapshot_name>` shows it `completed`.
**Gotchas:**
- `pg_backup_start(fast=false)` waits for the *next scheduled checkpoint*, not an immediate one — on a busy primary this can take several minutes. The tool waits up to `K8_TSDB_PSQL_WAIT_SECS` (default 900s) before declaring the bracket failed; raise it (`K8_TSDB_PSQL_WAIT_SECS=1800 tsdb-snapshot ...`) rather than assuming the run hung.
- A timeout and a dead psql session are reported as distinct failures — a timeout usually means retry off-peak or raise the wait; a dropped session usually means the pod restarted or OOMed mid-backup.
- Omitting `--config <target>` (or passing an unknown one) just lists the configured `tsdb_snapshot_targets` and exits — it's not a crash.

## How to: open a Liquibase shell against a MySQL/MariaDB target

**Goal:** run migrations or get a live `mysql` connection against a `liquibase_targets` entry whose `db_type` is `mysql` — the same tool used for Postgres targets, no separate command.
**Prereqs:** target defined under `liquibase_targets` with `db_type: mysql`; `mysql` client on `$PATH` for `--shell` mode.

1. Set `db_type: mysql` on the target (alongside the usual `namespace`/`service`/`remote_port`/`local_port`/`db_name`/secret keys) — everything else about the target block is the same shape as a Postgres one.
2. Run/preview migrations exactly as with a Postgres target:
   ```bash
   liquibase-shell <mysql-target> -- status
   liquibase-shell <mysql-target> -- update-sql
   ```
3. Or drop into a live connection:
   ```bash
   liquibase-shell <mysql-target> --shell
   # then, inside the shell:
   mysql
   ```

**Verify:** the tool prints `==> Connected: mysql @ localhost:<port>/<db>`; inside `--shell`, `MYSQL_HOST`/`MYSQL_TCP_PORT`/`MYSQL_PWD` are pre-exported so a bare `mysql` connects without flags.
**Gotchas:**
- `--shell` mode only exports `MYSQL_HOST`/`MYSQL_TCP_PORT`/`MYSQL_PWD` for `mysql` targets — there's no `MYSQL_USER`/`MYSQL_DATABASE` equivalent, so pass `-u <user> <db>` on the `mysql` command line (or rely on the JDBC-only one-shot/menu commands, which don't need this).
- An unrecognized `db_type` fails fast with `Unsupported db_type for target '<target>'` and lists the two supported values (`postgresql`, `mysql`) — this is the whole toolkit's MySQL support surface; every other tool here (`provision-db`, `tsdb-snapshot`) is Postgres/TimescaleDB-only.

## How to: use the SQL templates for a new project

**Goal:** stand up PgBouncer auth or a migration user for a project that isn't wired into `provision-db` yet.
**Prereqs:** direct `psql` access to the target database as an admin/superuser.

1. Copy the template you need out of the repo — don't run it in place:
   ```bash
   cp bin/pgbouncer-auth-setup.sql ~/scratch/pgbouncer-auth-setup.sql
   cp bin/sql/create-migrate-user.sql ~/scratch/create-migrate-user.sql
   ```
2. Edit credentials/database names inside the copy, then apply:
   ```bash
   psql -h <host> -U <admin> -d <db> -f ~/scratch/create-migrate-user.sql
   ```

**Verify:** `\du` in `psql` shows the new role; PgBouncer's `userlist.txt`/auth query picks it up on reload.
**Gotchas:** these are templates with placeholder credentials — applying one unedited creates a role with a known/placeholder password.
