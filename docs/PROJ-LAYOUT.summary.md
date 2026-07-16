# Project Layout — Summary

```
database-utils/
├── bin/                            # Executable tools + SQL templates
│   ├── liquibase-shell             #   Liquibase shell via kubectl port-forward
│   ├── liquibase-update            #   One-shot K8s Job Liquibase update
│   ├── provision-db                #   Provision Postgres DB/role + Valkey ACL user
│   ├── tsdb-snapshot               #   App-consistent EBS snapshot of TimescaleDB
│   ├── pgbouncer-auth-setup.sql    #   SQL template — pgbouncer auth
│   └── sql/
│       └── create-migrate-user.sql #   SQL template — migrate role
├── docs/                           # PROJ-ARCH, PROJ-LAYOUT (+ summaries), liquibase-shell-spec.md
├── .gitignore                      # swap files, .env, .envrc.local
├── Makefile                        # make install → ~/.local/bin
└── README.md                       # Install, prerequisites, configuration
```
