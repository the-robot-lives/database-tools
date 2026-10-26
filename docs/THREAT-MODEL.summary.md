# Threat Model — Summary

Local operator-side DB-admin CLI toolkit; no server, no own listeners. Every tool
inherits the invoking operator's `KUBECONFIG` (and AWS creds for snapshots) with no
added authorization. Full model: [THREAT-MODEL.md](THREAT-MODEL.md).

## Trust boundaries

- Operator workstation ↔ cluster API (kubectl: secret reads, port-forwards, exec, Jobs)
- Workstation ↔ DBs via `kubectl port-forward` (binds `127.0.0.1`) and `kubectl exec` psql
- Workstation ↔ AWS (`aws ec2 create-snapshot` — full volume copy leaves the cluster)
- Workstation ↔ local secret stores (`dc` reveal; K8s Secrets)

## Register (7)

| ID | Severity | Component | Status |
|----|----------|-----------|--------|
| T-001 | Medium | `--shell` exports `PGPASSWORD` + session-long password-bearing liquibase.properties (0700 mktemp, trap-cleaned) | Open (accepted) |
| T-002 | Low | `provision-db` redis-cli passwords in argv — local process listing | Open |
| T-003 | Medium | `--yes`/`LIQUIBASE_ASSUME_YES` bypasses destructive gates | Mitigated (opt-in; readonly whitelist mode) |
| T-004 | High | KUBECONFIG compromise = full DB admin by design | Accepted (workstation boundary) |
| T-005 | Medium | EBS snapshot = full data copy in AWS | Partial (encryption + IAM; no lifecycle mgmt) |
| T-006 | Low | Hand-run SQL templates, manual `${VAR}` substitution | Mitigated (not installed; primary-only note) |
| T-007 | Low | `liquibase-update` Job runs as root in gnp | Accepted (backoffLimit 0, TTL 1h) |

## Coverage

4 mitigated/partial · 2 open (accepted-by-design) · 1 accepted. Key controls:
localhost-only forwards, safety modes + confirms, cleanup traps, secretKeyRef-only
Job password (ConfigMap holds a placeholder), read-only docker mount,
`pg_is_in_recovery` snapshot guard. No package-level audit log of destructive runs.
