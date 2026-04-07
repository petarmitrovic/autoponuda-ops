#!/usr/bin/env bash

playbook="${1:-}"

if [[ -z "$playbook" ]]; then
  echo "Usage: $0 <playbook>"
  exit 1
fi

ansible-playbook "$playbook" --vault-password-file .vault_pass.local