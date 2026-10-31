#!/usr/bin/env bash
set -euo pipefail
set -o noclobber
umask 077

if [ "$(id -u)" -ne 0 ]; then
    printf '%s\n' 'Run this helper with sudo on the Semaphore controller VM.' >&2
    exit 1
fi

command -v openssl >/dev/null
for path in /opt/semaphore /opt/semaphore/secrets; do
    if [ -L "$path" ] || { [ -e "$path" ] && [ ! -d "$path" ]; }; then
        printf 'Refusing unsafe directory: %s\n' "$path" >&2
        exit 1
    fi
done
for path in /opt/semaphore/secrets/admin_password /opt/semaphore/secrets/access_key_encryption; do
    if [ -e "$path" ] || [ -L "$path" ]; then
        printf 'Refusing to overwrite existing secret: %s\n' "$path" >&2
        exit 1
    fi
done

IFS= read -r -s -p 'Choose a unique Semaphore admin password (at least 20 characters): ' password
printf '\n'
if [ "${#password}" -lt 20 ]; then
    printf '%s\n' 'Admin password must contain at least 20 characters. No secrets written.' >&2
    exit 1
fi
IFS= read -r -s -p 'Confirm admin password: ' confirmation
printf '\n'
if [ "$password" != "$confirmation" ]; then
    printf '%s\n' 'Admin password confirmation does not match. No secrets written.' >&2
    exit 1
fi

install -d -o root -g root -m 0755 /opt/semaphore
install -d -o root -g root -m 0700 /opt/semaphore/secrets
openssl rand -base64 32 > /opt/semaphore/secrets/access_key_encryption
printf '%s\n' "$password" > /opt/semaphore/secrets/admin_password
unset password confirmation
chown 1001:0 /opt/semaphore/secrets/admin_password /opt/semaphore/secrets/access_key_encryption
chmod 0400 /opt/semaphore/secrets/admin_password /opt/semaphore/secrets/access_key_encryption
printf '%s\n' 'Secret files prepared locally. Back them up securely; do not print or commit them.'
