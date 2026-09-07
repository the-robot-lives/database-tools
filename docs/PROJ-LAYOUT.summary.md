# Project Layout — Summary

K8s DB utilities: Liquibase shell/Job, provision-db, tsdb-snapshot, SQL templates.
Full annotated tree: [PROJ-LAYOUT.md](PROJ-LAYOUT.md).

```
database-utils/
├── bin/
│   ├── liquibase-shell             # Liquibase via kubectl port-forward
│   ├── liquibase-update            # One-shot K8s Job (gnp-backend)
│   ├── provision-db                # Postgres DB/role + optional Valkey ACL
│   ├── tsdb-snapshot               # App-consistent EBS snapshot of TimescaleDB
│   ├── pgbouncer-auth-setup.sql    # SQL template — pgbouncer auth
│   └── sql/
│       └── create-migrate-user.sql # SQL template — migrate role
├── docs/
│   ├── PROJ-ARCH.md · PROJ-ARCH.summary.md
│   ├── PROJ-LAYOUT.md · PROJ-LAYOUT.summary.md
│   ├── PROJ-HOWTO.md · PROJ-HOWTO.summary.md
│   ├── PROJ-FAQ.md · PROJ-FAQ.summary.md
│   ├── liquibase-shell-spec.md
│   └── howto/provision-db.md
├── CHANGELOG.md
├── merge-notes.md                  # sep-1 branch-sweep notes (transient)
├── .gitignore
├── Makefile                        # make install → ~/.local/bin
└── README.md
```

See [PROJ-LAYOUT.md](PROJ-LAYOUT.md) for install mapping, config notes, and setup table.
