# homelab-ansible

A small, maintainable Ansible project for configuring Linux virtual machines
running on XCP-ng as Docker hosts and, later, deploying containerized homelab
services. GitHub is the intended source-control platform, Semaphore is the
intended playbook runner, and local development takes place in VS Code on macOS.

## Current scope and assumptions

This project contains a Docker-host management role and one approved test alias,
`docker-test-01`. The Docker playbook gathers facts and invokes the role with
sudo. It now performs configuration tasks; it is no longer a no-op scaffold.
Live check-mode, real execution, repeat-run idempotence, and post-run Docker
health checks passed on the existing Debian amd64 test host. Fresh-host
installation and arm64 runtime testing remain unverified. No containerized
services are deployed.

- Ansible will manage Linux guest VMs, not XCP-ng hypervisors.
- VM provisioning and XCP-ng API integration are out of scope initially.
- The initial test VM runs Debian 13 Trixie. Its actual hostname, address, SSH
  username, and private-key path are kept outside Git. The role initially
  supports Debian 13 Trixie on amd64 and arm64 only. Service choices are deferred.
- There is one initial inventory environment, `homelab`, which can contain
  multiple Docker hosts.
- Local execution and Semaphore use the same reusable roles and playbooks.
- Docker host management and service deployment are separate stages; deployment
  of any containerized service requires its own approval.
- Source control uses the private GitHub repository
  [mooit-artist/homelab-ansible](https://github.com/mooit-artist/homelab-ansible).
  Initial publication preserves its existing initial commit.

No real infrastructure addresses, hostnames, or credentials are included.

## Repository structure

```text
homelab-ansible/
├── ansible.cfg
├── requirements.yml
├── .gitignore
├── README.md
├── inventories/
│   └── homelab/
│       ├── inventory.yml
│       ├── group_vars/
│       │   ├── all.yml
│       │   └── docker_hosts.yml
│       └── host_vars/
│           └── .gitkeep
├── playbooks/
│   ├── site.yml
│   └── docker_hosts.yml
└── roles/
    └── docker_host/
        ├── defaults/
        │   └── main.yml
        ├── tasks/
        │   └── main.yml
        ├── handlers/
        │   └── main.yml
        ├── templates/
        │   └── docker.list.j2
        └── files/
            └── .gitkeep
```

| Path | Purpose |
| --- | --- |
| [inventories/homelab/inventory.yml](inventories/homelab/inventory.yml) | Hosts and group membership. Contains the test alias `docker-test-01` in `docker_hosts`, without connection details. |
| [group_vars/all.yml](inventories/homelab/group_vars/all.yml) | Non-secret settings shared by all hosts in this inventory. |
| [group_vars/docker_hosts.yml](inventories/homelab/group_vars/docker_hosts.yml) | Non-secret settings shared by Docker hosts. |
| [host_vars/](inventories/homelab/host_vars/) | Per-host overrides. A file's basename must match its inventory host identifier. Add files only when host details are explicitly supplied. |
| [playbooks/site.yml](playbooks/site.yml) | Top-level entry point importing focused playbooks. |
| [playbooks/docker_hosts.yml](playbooks/docker_hosts.yml) | Targets `docker_hosts` and invokes the reusable `docker_host` role. |
| [roles/docker_host/defaults/main.yml](roles/docker_host/defaults/main.yml) | Low-precedence, overridable, non-secret role defaults. |
| [roles/docker_host/tasks/main.yml](roles/docker_host/tasks/main.yml) | OS and migration guards, repository trust, package presence, and Docker service state. |
| [roles/docker_host/handlers/main.yml](roles/docker_host/handlers/main.yml) | Refreshes APT metadata when the managed repository or signing key changes. Does not restart Docker. |
| [roles/docker_host/templates/](roles/docker_host/templates/) | Role-owned Jinja2 templates. Secret values must come from protected runtime variables, not template source. |
| [roles/docker_host/files/](roles/docker_host/files/) | Role-owned static, non-secret files. Never place private keys or credentials here. |
| [ansible.cfg](ansible.cfg) | Default inventory and role paths, enabled SSH host-key checking, and disabled retry files. |
| [requirements.yml](requirements.yml) | Collection and external-role dependencies. Both lists are initially empty; pin approved dependencies when adding them. |
| [.gitignore](.gitignore) | Local secrets, overrides, generated files, Python environments, editor metadata, macOS files, and temporary-file exclusions. |
| [README.md](README.md) | Project design, security policy, execution guidance, and incremental implementation process. |

`.gitkeep` files preserve otherwise empty directories in Git and are not used
by Ansible. Empty inventory variable mappings are intentional placeholders.

### Configuration boundaries

Keep inventory separate from roles. Roles must not contain host addresses,
inventory-specific host names, or credentials. Put reusable defaults in the
role, shared environment configuration in `group_vars`, and host-specific
overrides in `host_vars`. Use a `docker_host_` prefix for future role variables
to reduce naming collisions.

Templates and static files belong inside the role that owns them; there are no
ambiguous repository-wide template or file directories.

Additional VMs can join the appropriate inventory groups. Additional services
can have their own roles and focused playbooks imported by `site.yml`. A future
environment can get a separate directory under `inventories/`, with its own
inventory and variables, while reusing the same roles.

## Secrets policy

Never commit passwords, API keys, tokens, private SSH keys, Ansible Vault
passwords, Semaphore credentials, or other secrets to Git. Do not add real
infrastructure details until they have been explicitly provided and approved
for inclusion.

- Use Ansible Vault or an external secrets-management system for future secret
  inputs. Clearly document each input when it is introduced.
- Use names such as `vault_service_api_token` to identify future Vault-managed
  inputs. This is a naming example, not a defined variable or usable credential.
  Do not supply fake secret defaults that could mask a missing required value.
- The initial policy keeps even encrypted Vault data outside Git. Local files
  named `vault.yml`, `vault.yaml`, `vault_*.yml`, `vault_*.yaml`, `*.vault.yml`,
  or `*.vault.yaml`, and directories named `vault`, are ignored. Do not change
  this policy without an explicit decision.
- Keep Vault passwords outside the checkout. Supply them interactively using
  `--ask-vault-pass`, through an external password file, or through Semaphore's
  protected credential facilities. Never put a Vault password in `ansible.cfg`.
- Local Vault files are not loaded merely because they exist. When secret
  inputs are introduced, explicitly wire their loading or external lookup into
  the execution workflow and document it. For example, a local run can load an
  encrypted external YAML file using `--extra-vars @/path/to/vault.yml` together
  with `--ask-vault-pass`; the path is a placeholder.
- Do not place secrets in ordinary inventory variables, role defaults, static
  files, template source, README examples, or tracked Semaphore configuration.
- Future secret-handling tasks must avoid exposing sensitive output, use
  `no_log: true` where appropriate, and protect generated files with suitable
  ownership and permissions.

The ignore rules also cover `.env` files (except a deliberately non-secret
`.env.example`), local secret directories, common private-key filenames and
formats, Vault password files, local YAML overrides, caches, backups, logs,
and temporary files. They deliberately avoid blanket exclusions such as
`*.yml`, `*.key`, or `*.pub` that could hide legitimate project files.

**`.gitignore` is not a security guarantee.** It does not protect already tracked
files or files added with `git add --force`, and arbitrary secret filenames
may not match any pattern. Review staged changes before every commit. If a
secret is exposed, revoke or rotate it; deleting it from the latest revision
does not remove it from Git history.

## Local prerequisites and validation

Use an isolated Python environment on macOS rather than modifying system
Python. Ansible runs on the control machine; later managed Linux hosts need
working SSH access and a supported Python interpreter.

Install Homebrew Python 3.13 if it is not already available:

```sh
brew install python@3.13
```

From the repository root, create a new environment with that interpreter:

```sh
python3.13 -m venv .venv
. .venv/bin/activate
python -m pip install 'ansible-core==2.21.5'
ansible --version
ansible-inventory -i inventories/homelab/inventory.yml --graph
ansible-playbook playbooks/site.yml --syntax-check
ansible-playbook playbooks/docker_hosts.yml --syntax-check
ansible-playbook playbooks/site.yml --list-tasks
```

The `.venv/` directory is ignored. The validated control environment uses Python
3.13 and Ansible Core 2.21.5; the installation command pins that Ansible version.
Align Semaphore with this toolchain and review support status and updates
before operational use. `requirements.yml` manages Galaxy dependencies, not
the Python interpreter or the Ansible Core package.

An existing Python 3.9 environment must be recreated, not merely activated.
After confirming `.venv/` contains only the disposable project environment,
deactivate it if active and run `python3.13 -m venv --clear .venv`, then repeat
the activation, installation, and validation commands above. This clears only
the project virtual environment. Do not clear a directory containing project
files or secrets.

Run commands from the repository root so Ansible discovers `ansible.cfg`.
Verify the displayed configuration path with `ansible --version`. Inventory
and role paths in this configuration are relative to the configuration file.
Ansible may ignore a configuration file in a world-writable working directory;
do not make the checkout world-writable.

The initial scaffold had an empty inventory and produced expected no-host
warnings. The inventory now contains the test alias. Successful syntax checks
verify parsing and role resolution, not Docker installation, connectivity, or
deployment. Task listing now shows the Docker management tasks.

### Initial scaffold verification

The scaffold passed the following local checks:

- All nine YAML files parsed successfully.
- Both playbook entry points passed Ansible syntax checks.
- Inventory parsing retained the empty `docker_hosts` group and defined no hosts.
- Task listing confirmed that the role performs no operational tasks.
- Dependency lists were empty.
- Git ignore checks excluded 39 representative secret, local, and temporary
  paths while keeping all scaffold files and representative non-secret paths
  trackable. These checks used disposable Git metadata outside the checkout;
  no Git repository was initialized here.

Initial validation used Python 3.9.6 and Ansible Core 2.15.13 in the ignored `.venv/`.
The available macOS Python constrained the install to this older Ansible
release. Ansible Core 2.15 is no longer supported; this is scaffold compatibility
validation only, not approval of a production toolchain.

The local environment was subsequently recreated using Homebrew Python 3.13.18
and Ansible Core 2.21.5. Dependency consistency (`python -m pip check`), inventory
parsing, both playbook syntax checks, task listing, and all nine YAML files
passed validation again. At that stage the inventory remained empty and the
role remained non-operational. No VM configuration was changed during that
upgrade.

### Test host connection configuration

Only the alias `docker-test-01` is tracked. Local connection details belong in
the control user's `~/.ssh/config`, outside this repository. The following is
a schematic example: replace the uppercase placeholders locally, never with
secrets in Git.

```sshconfig
Host docker-test-01
    HostName VM_ADDRESS
    User SSH_USERNAME
    IdentityFile ~/.ssh/homelab_ansible
    IdentitiesOnly yes
    StrictHostKeyChecking yes
```

Keep the private key outside the checkout, protect it with a passphrase, and
load it into the SSH agent before execution. On macOS, the local setup uses
`ssh-add --apple-use-keychain ~/.ssh/homelab_ansible`. Protect the SSH config
with mode `0600`. Verify the VM's host-key fingerprint through its trusted
hypervisor console before accepting it into `known_hosts`.

The test VM was verified through the console and key-only SSH login. Its boot
journal showed machine-ID initialization from its VM UUID and generation of
new RSA, ECDSA, and ED25519 host keys. This initialization did not use cloud-init,
which is absent. Do not assume other templates perform the same initialization.
The clone has 2 vCPUs, 2 GiB RAM, and a 20 GiB disk; disk expansion is deferred.
Sudo requires an interactive password; never store it in inventory.

From the repository root with the environment active, test only this alias:

```sh
ssh -o BatchMode=yes docker-test-01 true
ansible docker-test-01 --limit docker-test-01 -m ansible.builtin.ping \
  --ssh-extra-args='-o BatchMode=yes'
```

Ansible ping verifies SSH and remote Python module execution, not ICMP or
Docker health. It creates temporary module files but makes no persistent
configuration changes. Do not run deployment playbooks as a connectivity test.
Local validation returned `ping: pong` with `changed: false` using key-only
authentication. Ansible discovered `/usr/bin/python3.13` on the target; its
interpreter-discovery warning notes that installing another interpreter may
change future selection. Interpreter pinning is deferred until role OS
requirements are defined. At the connection-verification stage, both playbooks
passed syntax checks and their task list remained empty; operational tasks were
added in the subsequent Docker role stage.

For a separate approved privilege-escalation test, add `--become` and
`--ask-become-pass` and enter the sudo password only at the terminal prompt.
Do not change sudo policy to avoid that prompt.

The interactive Ansible sudo check was reported successful by the operator:
`ping: pong` with `changed: false`. The password was entered locally and was
not supplied to the repository or assistant.

### Existing Docker baseline

A subsequent read-only inspection of the test clone found:

- Docker Engine 29.9.2 and Docker Compose plugin 5.6.1.
- Installed `docker-ce`, `docker-ce-cli`, `containerd.io`, and
  `docker-compose-plugin` packages with Debian Trixie version suffixes.
- The Docker service is active and enabled.
- No containers, images, local volumes, or build cache reported by Docker.
- Approximately 16 GiB available on the root filesystem.

Docker CLI queries succeeded as the SSH user without sudo. Docker daemon
access normally grants root-equivalent privileges; do not add users to the
Docker group casually. This inspection did not deploy containers, change
packages, or alter daemon settings, and did not verify package-repository
configuration. Versions and disk usage are a baseline, not enforced defaults.
These results informed the approved Docker role scope below.

Because DHCP addresses may change, arrange a reservation outside Git or update
the local SSH mapping after independently verifying the VM's identity.

When dependencies are added to `requirements.yml`, install them on the control
machine or runner before validation and execution:

```sh
ansible-galaxy install -r requirements.yml
```

No Galaxy dependencies need installation for the initial empty lists.

After hosts and operational tasks are approved, establish verified SSH host
keys in the control machine's `known_hosts`; do not disable host-key checking.
Confirm connectivity, then use `--check --diff` with an explicit `--limit`
before a real deployment where the tasks support check mode. Diff output can
contain secrets, so secret-handling tasks must suppress it appropriately.

## Semaphore compatibility

Semaphore is an execution layer, not a source of repository-specific role
logic. After the GitHub repository and a suitable Semaphore runner exist:

1. Configure the GitHub repository in Semaphore. Store any private-repository
   access credentials in Semaphore's protected credential facilities, not Git.
2. Configure an inventory using
   `inventories/homelab/inventory.yml` from the repository if the installed
   Semaphore version supports repository-backed inventory. Otherwise configure
   an equivalent inventory in Semaphore and keep group/host identifiers aligned
   with this repository's variables.
3. Configure task templates with `playbooks/site.yml` or the focused
   `playbooks/docker_hosts.yml` path, relative to the repository root.
4. Supply SSH credentials, any privilege-escalation password, and any Vault
   password through the runner's protected credential facilities. An SSH key
   used to clone GitHub is conceptually separate from one used to access VMs.
5. Ensure execution uses the repository's `ansible.cfg` and can resolve `roles/`.
   If the working directory differs, explicitly select the configuration with
   `ANSIBLE_CONFIG` pointing to its actual checkout path.
6. Use a supported Ansible version consistent with local development. Install
   future requirements before running playbooks; configure dependency
   installation in the runner rather than assuming it happens automatically.
7. Provide trusted host keys to the runner's `known_hosts`. Keep SSH host-key
   checking enabled and test access before deployment.
8. When secrets are introduced, document how the runner loads the encrypted
   variables or external secrets. Supplying a Vault password alone does not
   load a Vault data file. Do not store secrets in ordinary task-template
   variables or exported configuration.

The runner does not inherit your Mac's SSH config or SSH agent. For the tracked
`docker-test-01` alias, supply an equivalent runner-local SSH mapping or external
inventory/host variables (`ansible_host` and `ansible_user`) and managed SSH
credentials. Preserve the alias and `docker_hosts` group when using an external
inventory so repository group/host variables resolve consistently. Keep actual
connection details outside Git, and verify runner host-key trust separately.

Semaphore configuration details depend on the installed version and runner
setup. There is no Semaphore credential, server address, or exported task
configuration in this scaffold.

## Docker host role

The initial role supports Debian 13 Trixie on amd64 and arm64. Other operating
systems, releases, and architectures fail explicitly before configuration.
It uses only Ansible builtin modules; no Galaxy dependency is required.

The role:

- Checks installed packages and refuses automatic migration from conflicting
  distribution Docker, containerd, runc, or Podman compatibility packages.
  Resolve any migration deliberately; the role does not uninstall them.
- Ensures `ca-certificates` is present and `/etc/apt/keyrings` exists.
- Downloads Docker's public signing key over verified HTTPS to
  `/etc/apt/keyrings/docker.asc` when missing. An existing key is retained;
  key rotation requires a separately reviewed update.
- Manages the stable Docker repository in `/etc/apt/sources.list.d/docker.list`,
  scoped to that signing key with `signed-by`. This uses the supported legacy
  one-line format to match the test VM's existing source without migrating it.
  Docker's current installation guide uses deb822 `docker.sources` instead.
- Refuses to add a duplicate when another source file references the Docker
  Debian repository. The guard is conservative: even a commented reference
  requires review. Source contents are suppressed from logs because unrelated
  repositories might include credentials.
- Refreshes APT metadata when the managed source or key changes, before package
  installation. The prerequisites task also refreshes metadata if older than
  one hour; metadata downloads are not package upgrades.
- Ensures the packages in `docker_host_packages` are present: Docker Engine,
  CLI, bundled containerd, Buildx, and the Compose plugin. Defaults live in
  [roles/docker_host/defaults/main.yml](roles/docker_host/defaults/main.yml);
  use inventory group/host variables for intentional overrides.
- Ensures Docker is enabled at boot and running, without restarting an already
  running daemon.

There is no `state: latest`, upgrade task, forced downgrade, automatic removal,
daemon configuration, Docker-group membership change, firewall change, or
container deployment. Missing packages install their available candidate and
required dependencies; APT may adjust dependencies to satisfy that installation.
Installed requested packages are not explicitly upgraded or version-pinned.
This does not disable pre-existing OS unattended-upgrade policies. Docker
installation/startup itself can create its default networks and firewall rules.
Review published-port behavior before deploying services, and treat daemon
access as root-equivalent.

### Verification sequence

Local syntax checks, YAML parsing, OS/architecture and conflict guard tests,
and exact amd64/arm64 repository-template rendering passed. These do not replace
live checks or demonstrate installation on a fresh VM. The existing Debian
amd64 test clone is the first live target; arm64 runtime testing is deferred.

The operator's first live dry run on `docker-test-01` passed with `ok=15`,
`changed=0`, `unreachable=0`, `failed=0`, and `skipped=1`. All guards passed,
and no configuration changes were predicted. The skipped repository-conflict
accumulation task is expected when no conflicting sources are found.
The Python interpreter-discovery warning is informational. The operator then
completed the first real execution with the same recap: `ok=15`, `changed=0`,
`unreachable=0`, `failed=0`, and `skipped=1`. Existing state matched the role
without configuration changes. The operator's repeat real run returned the same
recap, confirming idempotence on this existing test host. A subsequent key-only
SSH check confirmed Docker Engine 29.9.2, Compose 5.6.1, and Docker service
state `active` and `enabled`. This completes existing-host management
verification, not fresh-host installation or arm64 runtime verification.

With the local virtual environment active, first run:

```sh
ansible-playbook playbooks/docker_hosts.yml --limit docker-test-01 \
  --check --diff --ask-become-pass \
  --ssh-extra-args='-o BatchMode=yes'
```

Enter the sudo password only at the terminal prompt. Review the output before
applying anything. Check mode does not bootstrap a fresh host: a missing signing
key, repository, package metadata, or Docker service can cause later simulated
tasks to fail because earlier changes were not applied. `get_url` uses a HEAD
request in check mode and can report a predicted change without checking the
downloaded content. Investigate failures; do not bypass guards.

After the dry run is reviewed and approved, apply only to the test alias:

```sh
ansible-playbook playbooks/docker_hosts.yml --limit docker-test-01 \
  --ask-become-pass --ssh-extra-args='-o BatchMode=yes'
```

Repeat that same real run to verify idempotence. Expect `failed=0`,
`unreachable=0`, and `changed=0` on the repeat run when state is already correct.
An elapsed cache interval may trigger a metadata refresh; account for that
separately from configuration changes. Finally verify `docker --version`,
`docker compose version`, and `systemctl is-active docker` on the test host.
Do not deploy a sample container as part of this stage.

## Incremental implementation

Work in small, approved stages and verify each stage before moving on:

1. **Scaffold:** validate inventory parsing, both playbook entry points, role
   resolution, and ignore rules. No operational tasks or hosts.
2. **Host configuration:** after explicit host details and OS/SSH decisions,
   add inventory entries and non-secret variables, securely supply credentials,
   establish host-key trust, and verify connectivity.
3. **Docker host role:** agree on supported distributions and Docker setup,
   implement the reusable role, then test check mode, deployment, and
   idempotence on an approved test VM.
4. **Services:** add one approved service at a time, with its own configuration,
   secret inputs, templates, and deployment verification.
5. **Semaphore execution:** validate the approved workflow in the runner,
   including dependencies, inventory variables, credentials, and host-key trust.

Do not treat completion of the scaffold as approval to build the entire homelab.

## Git and GitHub workflow

The local repository uses `main` and the private GitHub repository above as
`origin`. The initial project commit builds on the existing remote README commit
without rewriting history. Author identity is configured locally for this
repository using a GitHub noreply address rather than a personal email.
GitHub CLI authentication lives in the macOS credential store, outside Git.

Before each commit, review what will be published:

```sh
git status --short
git diff
git add README.md inventories/ playbooks/ roles/ ansible.cfg requirements.yml .gitignore
git diff --cached --check
git diff --cached
git status --short --ignored
```

Do not stage `.venv/`, local SSH configuration, keys, passwords, or external
connection details. Review new files explicitly; ignore rules cannot detect
arbitrary secrets. Commit the reviewed changes and push normally, without force:

```sh
git commit -m "Describe the approved change"
git push origin main
```

Repository privacy is not a substitute for keeping secrets out of Git. Verify
private visibility before publication and before configuring Semaphore access.
Later, use focused branches and pull requests for changes when useful; branch
protection and CI are separate, unimplemented stages.
