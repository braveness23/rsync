#!/usr/bin/env bashio
# shellcheck shell=bash
set -e

PRIVATE_KEY_FILE=$(bashio::config 'private_key_file')
if [ ! -f "$PRIVATE_KEY_FILE" ]; then
  bashio::log.info 'Generate keypair'

  mkdir -p "$(dirname "$PRIVATE_KEY_FILE")"
  ssh-keygen -t ed25519 -f "$PRIVATE_KEY_FILE" -N ''

  bashio::log.info "Generated key-pair in $PRIVATE_KEY_FILE"
else
  bashio::log.info "Use private key from $PRIVATE_KEY_FILE"
fi

HOST=$(bashio::config 'remote_host')
USERNAME=$(bashio::config 'username')
FOLDERS=$(bashio::addon.config | jq -r ".folders")

# Create local directories if they don't exist
echo "$FOLDERS" | jq -c '.[]' | while read -r folder; do
  LOCAL_DIR=$(echo "$folder" | jq -r '.local')
  bashio::log.info "Checking local directory: $LOCAL_DIR"
  if [ ! -d "$LOCAL_DIR" ]; then
    bashio::log.info "Creating local directory: $LOCAL_DIR"
    mkdir -p "$LOCAL_DIR"
  fi
done

if bashio::config.has_value 'remote_port'; then
  PORT=$(bashio::config 'remote_port')
  bashio::log.info "Use port $PORT"
else
  PORT=22
fi

SSH_OPTS="-p ${PORT} -i ${PRIVATE_KEY_FILE} -oStrictHostKeyChecking=accept-new -oPasswordAuthentication=no -oBatchMode=yes -oConnectTimeout=30"

folder_count=$(echo "$FOLDERS" | jq -r '. | length')
sync_errors=0

for (( i=0; i<folder_count; i=i+1 )); do

  local=$(echo "$FOLDERS" | jq -r ".[$i].local")
  remote=$(echo "$FOLDERS" | jq -r ".[$i].remote")
  options=$(echo "$FOLDERS" | jq -r ".[$i].options // \"--archive --recursive --compress --delete --prune-empty-dirs\"")
  direction=$(echo "$FOLDERS" | jq -r ".[$i].direction // \"push\"")

  # Split options string into array to prevent shell injection via unquoted expansion
  read -ra rsync_opts <<< "${options}"

  if [ "$direction" = "pull" ]; then
    # Pull from remote to local.
    bashio::log.info "Sync ${USERNAME}@${HOST}:${remote} -> ${local} with options \"${options}\""
    set -x
    rsync "${rsync_opts[@]}" \
    -e "ssh ${SSH_OPTS}" \
    "${USERNAME}@${HOST}:${remote}" "${local}" || { set +x; bashio::log.error "Sync failed: ${USERNAME}@${HOST}:${remote} -> ${local}"; sync_errors=$((sync_errors + 1)); continue; }
    set +x
  else
    # Default push from local to remote
    bashio::log.info "Sync ${local} -> ${USERNAME}@${HOST}:${remote} with options \"${options}\""
    set -x
    rsync "${rsync_opts[@]}" \
    -e "ssh ${SSH_OPTS}" \
    "${local}" "${USERNAME}@${HOST}:${remote}" || { set +x; bashio::log.error "Sync failed: ${local} -> ${USERNAME}@${HOST}:${remote}"; sync_errors=$((sync_errors + 1)); continue; }
    set +x
  fi
done

if [ "$sync_errors" -gt 0 ]; then
  bashio::log.warning "Sync completed with ${sync_errors} error(s)"
  exit 1
fi

bashio::log.info "Synced all folders"
