#!/usr/bin/env bash
set -euo pipefail
umask 077

if [ "$(id -u)" -ne 0 ] || [ "${SUDO_UID:-0}" -eq 0 ] || [ -z "${SUDO_GID:-}" ]; then
    printf '%s\n' 'Run with sudo from your non-root account on the controller VM.' >&2
    exit 1
fi

for command in docker tar gzip mktemp chown; do
    if ! command -v "$command" >/dev/null; then
        printf 'Required command not found: %s\n' "$command" >&2
        exit 1
    fi
done

compose=(docker compose -p semaphore -f /opt/semaphore/compose.yml)
container=$("${compose[@]}" ps --all --quiet semaphore)
if [ -z "$container" ] || [ "$(docker inspect --format '{{.State.Running}}' "$container")" != true ]; then
    printf '%s\n' 'Expected an existing, running Semaphore container. No snapshot created.' >&2
    exit 1
fi

archive=$(mktemp /var/tmp/semaphore-backup.XXXXXXXX)
complete=false
restart_needed=false

cleanup() {
    status=$?
    trap - EXIT HUP INT TERM
    if [ "$restart_needed" = true ]; then
        if ! "${compose[@]}" start semaphore; then
            printf '%s\n' 'ERROR: Semaphore restart failed. Restart it manually before continuing.' >&2
            status=1
        fi
    fi
    if [ "$complete" = false ]; then
        if ! rm -- "$archive"; then
            printf 'ERROR: Remove the incomplete snapshot manually: %s\n' "$archive" >&2
            status=1
        fi
    elif [ "$status" -ne 0 ]; then
        printf 'Protected snapshot retained at: %s\n' "$archive" >&2
    fi
    exit "$status"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

printf '%s\n' 'Stopping Semaphore for a consistent snapshot; no tasks may be running.'
restart_needed=true
"${compose[@]}" stop --timeout 60 semaphore
if [ "$(docker inspect --format '{{.State.Running}}' "$container")" != false ]; then
    printf '%s\n' 'ERROR: Semaphore is still running; refusing an inconsistent backup.' >&2
    exit 1
fi

tar --create --gzip --file="$archive" --directory=/opt semaphore
gzip --test "$archive"
tar --list --gzip --file="$archive" >/dev/null
complete=true
"${compose[@]}" start semaphore
restart_needed=false
chown "$SUDO_UID:$SUDO_GID" "$archive"
printf 'Snapshot ready: %s\n' "$archive"
printf '%s\n' 'This is NOT encrypted. Encrypt and verify it, then remove this exact file.'
printf '%s\n' 'Semaphore has been started; wait for healthy status before using the UI.'
