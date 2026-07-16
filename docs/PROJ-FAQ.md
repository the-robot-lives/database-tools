# PROJ-FAQ — database-utils

Why/when/compared-to-what questions. For *what it is* see [PROJ-ARCH.md](PROJ-ARCH.md); for *how to do it* see [PROJ-HOWTO.md](PROJ-HOWTO.md).

## Motivation

### Why would I use `provision-db` instead of just re-running my `initdb.d/` scripts?

Because `initdb.d/` only runs once, on first init of an empty data directory — a running cluster instance never re-executes it, so any app added after day one gets no database, no role, and no ACL user automatically. `provision-db` does that create-on-a-running-instance step on demand, reusing the same `liquibase_targets.<target>` connection info instead of a bespoke script per app. The trade-off: it's an imperative, run-it-yourself step — there's no reconciliation loop keeping provisioning in sync with config, so a target added to `.infra-config.yaml` still needs someone to actually run the tool once.
→ *See [PROJ-HOWTO.md](PROJ-HOWTO.md#how-to-provision-a-database--role-on-an-already-running-instance) / [howto/provision-db.md](howto/provision-db.md)*

### Why bracket TimescaleDB snapshots with `pg_backup_start`/`stop` instead of just snapshotting the EBS volume?

A bare EBS snapshot of a live Postgres data volume is only crash-consistent — restoring it replays WAL from an arbitrary write-in-flight point, same as a power-loss recovery. The `pg_backup_start`/`stop` bracket tells Postgres to fence the backup window so the snapshot restores cleanly without relying on crash recovery having to do the right thing. The cost is real: `fast=false` waits for the *next scheduled checkpoint*, which can take minutes on a busy primary, so a bracketed snapshot is measurably slower to start than a crash-only one.
→ *See [PROJ-HOWTO.md](PROJ-HOWTO.md#how-to-take-an-application-consistent-timescaledb-snapshot)*

### Why does `make install` symlink `liquibase-shell`/`liquibase-update`/`provision-db` but *copy* (`install -m 755`) `tsdb-snapshot`?

There's no documented rationale in the Makefile or its history — it reads as an inconsistency rather than a deliberate policy, so don't infer a design reason from it. What matters practically: edits to `bin/liquibase-shell`, `bin/liquibase-update`, or `bin/provision-db` take effect on your `$PATH` immediately (they're symlinks); an edit to `bin/tsdb-snapshot` does *not* take effect until you re-run `make install`, since the installed copy is a snapshot at install time.
→ *See [PROJ-HOWTO.md](PROJ-HOWTO.md#how-to-install-the-tools)*

### Why does `provision-db` split credential sourcing between `dc` and the live K8s secret instead of just reading everything from one place?

Because the two credential classes have different lifecycles: role/ACL passwords for apps are declared config (they mirror what Infisical syncs to K8s, so `dc` is the source of truth and stays stable across cluster rebuilds), while the Postgres superuser password is auto-generated at cluster bring-up and only ever lives in the live K8s admin secret — pinning it in `dc` would just create a second, driftable copy of a secret nobody is supposed to hand-manage. Reading both from `dc` would mean manually copying an auto-generated superuser password into version-controlled config every time the cluster gets rebuilt.
→ *See [PROJ-ARCH.md](PROJ-ARCH.md#provision-db) for the design rationale*

## Fit

### When should I reach for `liquibase-update` (the Job) instead of `liquibase-shell`?

Almost never for new work — `liquibase-update` predates `liquibase-shell`'s one-shot mode and is kept around specifically for the legacy gnp-backend target that's hardcoded to it. For anything interactive, or any new target, `liquibase-shell <target> -- update` covers the same ground with menu/one-shot/`--shell` flexibility the Job doesn't have. Reach for the Job only if you specifically need in-cluster execution (e.g. from a CI runner with no local `liquibase`/`kubectl` port-forward path).
→ *See [PROJ-HOWTO.md](PROJ-HOWTO.md#how-to-run-the-legacy-one-shot-liquibase-update-job)*

### When should I use `--crash-only` instead of the default app-consistent bracket on `tsdb-snapshot`?

When the target is a standby/replica volume, since a replica has nothing writing transactions locally for `pg_backup_start` to fence and the bracket adds wait time for no consistency benefit. On a primary, skip the bracket only if you've deliberately decided crash-consistency is good enough for that particular snapshot (e.g. a throwaway dev copy) — the default is app-consistent specifically because restoring an unbracketed snapshot of a busy primary risks a longer, less-predictable recovery.
→ *See [PROJ-HOWTO.md](PROJ-HOWTO.md#how-to-take-an-application-consistent-timescaledb-snapshot)*

### Is this toolkit the right choice for a database that isn't in `.infra-config.yaml` yet?

No, not as-is — every tool here is config-driven off `liquibase_targets`/`tsdb_snapshot_targets`, and none of them accept a fully ad-hoc connection string. Add a target entry first (see the README example under `liquibase_targets`); until then, `liquibase-shell` with no matching target just lists what *is* configured, and `provision-db`/`tsdb-snapshot` have nothing to key off of.

## Comparison

### How does `provision-db` differ from just running `kubectl exec -it ... -- psql` and typing the `CREATE DATABASE`/`CREATE ROLE` myself?

Functionally not much for a one-off — the difference is credential handling and repeatability. `provision-db` sources role/ACL passwords from `dc` (so the password it sets matches what Infisical will later sync into the app's K8s secret) and the superuser password from the live admin secret automatically, instead of you copying both by hand into a `psql` session and risking a typo or a stale/mismatched password. It also optionally provisions a matching Valkey ACL user in the same run.

### How does `liquibase-shell` differ from `liquibase-update`?

`liquibase-shell` port-forwards and runs `liquibase` (or a raw `psql`/`mysql` shell) locally against the port-forward, giving you an interactive menu, one-shot `-- <cmd>` invocations, or a live `--shell` session; `liquibase-update` instead `kubectl apply`s a one-shot in-cluster Job that runs Liquibase itself and exits. The shell path is the current default for anything a human is doing; the Job path is legacy, kept only for the one target still wired to it.

## Capability

### Can `provision-db` create a Valkey/Redis ACL user, not just a Postgres role?

Yes — when a target's config includes `redis_*` provisioning fields, `provision-db` also runs a `redis-cli ACL SETUSER` against app-valkey in the same invocation. The important caveat: that ACL user is **not durable** — it's wiped if the Valkey pod is recreated, because `SETUSER` issued at runtime doesn't persist across pod restarts the way `--user` CLI args baked into the chart do. Treat `provision-db`'s ACL step as convenient-for-now, not a substitute for fixing the Helm chart to pass durable `--user` args.

### Does `liquibase-shell` work against MySQL/MariaDB targets, or only Postgres?

Both — `db_type: postgresql` or `mysql` in a target's config selects which client (`psql`/`mysql`) and env-var set `--shell` exports. Most of the toolkit's design narrative (and every other tool here) is Postgres/TimescaleDB-specific; `liquibase-shell` is the one tool with first-class MySQL support.
→ *See [PROJ-HOWTO.md](PROJ-HOWTO.md#how-to-open-a-liquibase-shell-against-a-mysqlmariadb-target)*

### Can `tsdb-snapshot` run against a replica, or only a primary?

Yes, via `--crash-only` (or `crash_only: true` on the target) — the app-consistent bracket is skipped since a replica has no local write activity for `pg_backup_start` to fence. Running the *default* (bracketed) mode against a replica isn't blocked, but it buys you nothing: the tool verifies primary status specifically to decide which behavior makes sense, and the bracket exists to protect against in-flight primary writes that don't apply to a standby.

## Caveats

### What's the risk of running `tsdb-snapshot` (default mode) on a busy primary?

`pg_backup_start(fast=false)` waits for the next *scheduled* checkpoint rather than forcing an immediate one, and on a loaded primary that can take several minutes — the tool waits up to `K8_TSDB_PSQL_WAIT_SECS` (default 900s) before calling it a failure. A timeout there doesn't necessarily mean anything is broken; it can just mean the checkpoint hasn't come around yet. A distinct failure mode — the psql session dying mid-backup (pod restart/OOM) — is reported separately so you don't conflate "still waiting" with "something crashed."
→ *See [PROJ-HOWTO.md](PROJ-HOWTO.md#how-to-take-an-application-consistent-timescaledb-snapshot)*

### Is it safe to run the SQL templates (`bin/pgbouncer-auth-setup.sql`, `bin/sql/create-migrate-user.sql`) as-is?

No — they're templates with placeholder credentials, meant to be copied out of the repo, edited, and only then applied. `make install` deliberately never installs or deploys them, precisely so they aren't mistaken for ready-to-run scripts. Running one unedited creates a role with a known placeholder password on your database.
→ *See [PROJ-HOWTO.md](PROJ-HOWTO.md#how-to-use-the-sql-templates-for-a-new-project)*

### If `KUBECONFIG` is wrong, will I get an obvious error?

Not necessarily — the most common symptom is `Failed to read password ... Tried keys: DB_PASSWORD` (or similar), which reads like a missing/misnamed secret key but almost always means `kubectl` is pointed at the wrong cluster context and simply can't find the secret it expects. `liquibase-shell` defaults `KUBECONFIG` to `~/.kube/noizu/config` when unset specifically to close this gap, but if you've exported a different `KUBECONFIG` for another cluster, that override wins and you'll see the same misleading error.

### Why does `--shell` mode export `MYSQL_HOST`/`MYSQL_TCP_PORT`/`MYSQL_PWD` for a MySQL target but not `MYSQL_USER`/`MYSQL_DATABASE` the way it exports a full Postgres connection?

Because the `mysql` client has no environment-variable equivalent for user/database the way libpq does (`PGUSER`/`PGDATABASE`) — `MYSQL_PWD` is the only credential var the client honors, so that's as far as env-export can go. You still have to pass `-u <user> <db>` on the `mysql` command line yourself inside `--shell`; if that's one flag too many, the menu/one-shot `-- <cmd>` invocations don't need this at all since they build the full command internally.
→ *See [PROJ-HOWTO.md](PROJ-HOWTO.md#how-to-open-a-liquibase-shell-against-a-mysqlmariadb-target)*

### What happens if I open `liquibase-shell` against a target that has no `changelog_dir`/`changelog_file` configured?

You get a live connection shell instead of the usual Liquibase menu — the tool treats "no changelog configured" as "this target is a plain DB connection, not a migration target" rather than an error. That's useful for instance-level targets you only ever want to `psql`/`mysql` into. If you actually need a one-shot Liquibase command (`status`, `update-sql`, etc.) against such a target, pass `--changelog-file=...` on the command line to force it rather than editing the target's permanent config.
→ *See [PROJ-HOWTO.md](PROJ-HOWTO.md#how-to-open-a-liquibase-shell-against-a-cluster-database)*

### Can a `safety: readonly` target still run `update`/destructive Liquibase commands if I really want to?

Not through `liquibase-shell` itself — a readonly target's command allowlist (`status diff validate history update-sql rollback-count-sql changelog-sync-sql`) is enforced by the tool, not just documented as a convention. If you need to actually apply changes against what's marked readonly, the intended escape hatch is `--shell` plus manual SQL — a deliberate, visible extra step rather than a flag that silently lifts the restriction.

## Trust

### Does `provision-db` generate or store secrets of its own?

No — it only reads existing credentials: role/ACL passwords from `dc` (already the source of truth that syncs to K8s via Infisical) and the superuser password from the live K8s admin secret. It doesn't mint new passwords, write anywhere outside the target database/Valkey instance, or persist anything locally beyond normal shell environment for the duration of the run.

### Does `liquibase-shell --shell` leave database passwords lying around after I exit?

The password lives only in the exported `PGPASSWORD`/`LB_DEFAULTS_FILE` environment for the duration of the shell session and the port-forward's process lifetime; it isn't written to a dotfile, history-persisted config, or a temp file that survives the session. Ordinary shell-history capture of commands you type is outside the tool's control, same as any other CLI session — don't paste the password itself into a command line.
