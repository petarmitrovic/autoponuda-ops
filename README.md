# auto-ponuda-ops

Infrastructure as code for the auto-ponuda project, managed with Ansible.

## Prerequisites

- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/index.html) installed on your local machine
- SSH access to the target VPS
- Ansible collections installed:
  ```bash
  ansible-galaxy collection install -r ansible-requirements.yml
  ```

## Project structure

```
.
├── ansible.cfg
├── ansible-requirements.yml        # Ansible collection dependencies
├── inventory/
│   ├── hosts.yml                   # Target hosts
│   └── group_vars/
│       └── vps/
│           ├── vars.yml            # Plain group variables
│           └── vault.yml           # Ansible Vault encrypted secrets
├── roles/
│   ├── docker/                     # Installs Docker Engine and Compose plugin
│   ├── node_exporter/              # Runs node-exporter (host metrics agent)
│   └── monitoring/                 # Deploys Prometheus + Grafana stack
└── playbooks/
    ├── setup_server.yml            # Baseline: docker + node_exporter (run on every server)
    ├── setup_docker.yml            # Docker only
    └── setup_monitoring.yml        # Prometheus + Grafana (dedicated monitoring host)
```

## Getting started

### 1. Configure inventory

Edit `inventory/hosts.yml` and fill in your VPS details:

```yaml
my-vps:
  ansible_host: YOUR_VPS_IP_OR_HOSTNAME
  ansible_user: YOUR_SSH_USER
```

Optionally uncomment `ansible_ssh_private_key_file` if your key is not in the default SSH location.

### 2. Set up secrets

Secrets are stored in `inventory/group_vars/vps/vault.yml`, encrypted with Ansible Vault. The vault password is never committed — keep it in `.vault_pass.local` (already gitignored).

**First time setup:**
```bash
# Get the vault password from a team member via a secure channel (e.g. 1Password, Signal)
# and write it to your local password file
echo "<vault-password>" > .vault_pass.local
```

**To edit secrets later:**
```bash
ansible-vault edit --vault-password-file .vault_pass.local inventory/group_vars/vps/vault.yml
```

The encrypted file is safe to commit — it looks like a blob of ciphertext in the repo.

### 3. Verify connectivity

```bash
ansible all -m ping
```

## Roles

| Role | Responsibility | Depends on |
|---|---|---|
| `docker` | Installs Docker Engine and Compose plugin | — |
| `node_exporter` | Runs node-exporter as a Docker container; exposes host metrics to Prometheus | `docker` |
| `monitoring` | Deploys Prometheus + Grafana via Docker Compose | `docker` |

**Role dependency note:** `node_exporter` and `monitoring` both declare `docker` as a dependency in their `meta/main.yml`, so Docker will always be installed automatically when either role is applied.

## Playbooks

### Base server setup (run on every new server)

Installs Docker and starts node-exporter. This is the baseline for all servers.

```bash
ansible-playbook playbooks/setup_server.yml
```

### Deploy monitoring stack

Deploys Prometheus and Grafana on the target host. Prometheus is pre-configured to scrape node-exporter.

```bash
ansible-playbook playbooks/setup_monitoring.yml --vault-password-file .vault_pass.local
```

Services are bound to `127.0.0.1` only and not reachable from the outside. To access Grafana locally, use SSH port forwarding:

```bash
ssh -N -L 3000:127.0.0.1:3000 YOUR_SSH_USER@YOUR_VPS_IP
# then open http://localhost:3000
```

**Note:** `GF_SECURITY_ADMIN_PASSWORD` only takes effect on the very first run when the Grafana volume is empty. If the volume already exists with a different password, reset it manually:
```bash
docker exec -it grafana grafana-cli admin reset-admin-password <new-password>
```

### Install Docker only

```bash
ansible-playbook playbooks/setup_docker.yml
```

| Variable | Default | Description |
|---|---|---|
| `docker_users` | `[]` | OS users to add to the `docker` group |

## Adding a new server

1. Add the host to `inventory/hosts.yml` under the `vps` group
2. Run the base setup playbook:
   ```bash
   ansible-playbook playbooks/setup_server.yml --vault-password-file .vault_pass.local --limit <new-host>
   ```
3. If the new server should also run the monitoring stack:
   ```bash
   ansible-playbook playbooks/setup_monitoring.yml --limit <new-host> --vault-password-file .vault_pass.local
   ```

## CI/CD (GitHub Actions)

The `deploy_monitoring` workflow (`.github/workflows/deploy_monitoring.yml`) runs the monitoring playbook from GitHub Actions. It requires two repository secrets:

| Secret | Value |
|---|---|
| `ANSIBLE_VAULT_PASSWORD` | The vault password (same as `.vault_pass.local`) |
| `SSH_PRIVATE_KEY` | A **dedicated** deploy SSH private key (not your personal key) |

The workflow is triggered manually from the Actions tab.

## Notes

- Targets **Ubuntu** hosts. For Debian, update the GPG key URL and apt repo in `roles/docker/tasks/main.yml`.
- Docker Compose is installed as the **v2 plugin** — use `docker compose` (not `docker-compose`).
- The vault password file (`.vault_pass.local`) is gitignored and must never be committed.
