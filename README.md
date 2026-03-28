# auto-ponuda-ops

Infrastructure as code for the auto-ponuda project, managed with Ansible.

## Prerequisites

- [Ansible](https://docs.ansible.com/ansible/latest/installation_guide/index.html) installed on your local machine
- SSH access to the target VPS

## Project structure

```
.
├── ansible.cfg               # Ansible configuration
├── inventory/
│   └── hosts.yml             # Target hosts
├── roles/
│   └── docker/               # Installs Docker Engine and Compose plugin
│       ├── defaults/main.yml
│       ├── handlers/main.yml
│       └── tasks/main.yml
└── playbooks/
    └── setup_docker.yml      # Playbook: install Docker on VPS
```

## Getting started

### 1. Configure inventory

Edit `inventory/hosts.yml` and replace the placeholders with your VPS details:

```yaml
my-vps:
  ansible_host: YOUR_VPS_IP_OR_HOSTNAME
  ansible_user: YOUR_SSH_USER
```

Optionally uncomment and set `ansible_ssh_private_key_file` if your key is not in the default SSH location.

### 2. Verify connectivity

```bash
ansible all -m ping
```

## Playbooks

### Install Docker

Installs Docker Engine, Docker CLI, containerd, and the Docker Compose plugin on all hosts in the `vps` group.

```bash
ansible-playbook playbooks/setup_docker.yml
```

**Options** (set as extra vars or in the playbook `vars` block):

| Variable | Default | Description |
|---|---|---|
| `docker_users` | `[]` | List of OS users to add to the `docker` group |

Example — add `ubuntu` to the docker group:

```bash
ansible-playbook playbooks/setup_docker.yml -e '{"docker_users": ["ubuntu"]}'
```

## Notes

- Targets **Ubuntu** hosts. For Debian, update the GPG key URL and apt repo in `roles/docker/tasks/main.yml`.
- Docker Compose is installed as the **v2 plugin** — use `docker compose` (not `docker-compose`).
- Sensitive values (vault passwords, SSH keys) are listed in `.gitignore` and should never be committed.
