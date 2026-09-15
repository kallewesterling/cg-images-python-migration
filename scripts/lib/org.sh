#!/usr/bin/env bash
#
# Resolve the Chainguard organization name the same way in every script.
# ORG_NAME (env override) and an already-exported CGR_ORG (set by a script
# that ran earlier in this shell session) both short-circuit the prompt.
DEFAULT_ORG="chainguard.edu"

: "${ORG_NAME:=${CGR_ORG:-}}"
if [ -z "$ORG_NAME" ]; then
  read -rp "${DEFAULT_ORG}? [y/N] " USE_DEFAULT_ORG
  if [[ "$USE_DEFAULT_ORG" =~ ^[Yy]$ ]]; then
    ORG_NAME="$DEFAULT_ORG"
  else
    read -rp "Chainguard organization name: " ORG_NAME
  fi
fi
export CGR_ORG="$ORG_NAME"
