# database-tools — Database Utilities

TimescaleDB snapshot and database administration tools.

## Installation

```bash
make install    # Installs tsdb-snapshot to ~/.local/bin
```

## Prerequisites

- `kubectl` with cluster access
- `psql` for direct database operations (optional)

## Configuration

No config files required. SQL files in `bin/sql/` are templates — copy and customize for your environment.

## Tools

| Command | Purpose |
|---------|---------|
| `tsdb-snapshot` | Create and manage TimescaleDB snapshots |

## SQL Templates

| File | Purpose |
|------|---------|
| `bin/pgbouncer-auth-setup.sql` | Configure PgBouncer authentication |
| `bin/sql/create-migrate-user.sql` | Create migration database user |

Copy these to your project and adjust credentials/database names before use.
