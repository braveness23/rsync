# rsync — Home Assistant Add-on

Sync folders between Home Assistant and a remote machine over SSH using rsync. Supports push (HA → remote) and pull (remote → HA) per folder, with per-folder rsync options and configurable SSH port.

[![Add repository to Home Assistant][repo-badge]][repo-url]
[![Install on Home Assistant][install-badge]][install-url]

**Supported architectures:** amd64, aarch64, armv7, armhf, i386

[repo-badge]: https://img.shields.io/badge/Add-Repository-41BDF5?logo=home-assistant&style=for-the-badge
[repo-url]: https://my.home-assistant.io/redirect/supervisor_add_addon_repository/?repository_url=https%3A%2F%2Fgithub.com%2Fbraveness23%2Frsync
[install-badge]: https://img.shields.io/badge/Install-Add--on-41BDF5?logo=home-assistant&style=for-the-badge
[install-url]: https://my.home-assistant.io/redirect/supervisor_addon?addon=b10c135f_rsync

---

## Prerequisites

- `rsync` must be installed on the **remote machine**
- The remote machine must accept SSH key authentication
- The SSH public key must be added to `~/.ssh/authorized_keys` on the remote

---

## Installation

1. Add this repository to Home Assistant: **Settings → Add-ons → Add-on Store → ⋮ → Repositories**
2. Find **rsync** and click **Install**
3. Configure the add-on (see below) before starting it

---

## Configuration

```yaml
private_key_file: /ssl/rsync/id_rsa   # path inside /ssl volume
username: myuser                        # SSH user on the remote machine
remote_host: 192.168.1.100             # IP or hostname of the remote
remote_port: 22                         # optional, defaults to 22
folders:
  - local: /config                      # push /config to remote
    remote: /home/myuser/ha-backup
    direction: push                     # push = HA → remote (default)
  - local: /media/music                 # pull music from remote
    remote: /home/myuser/music
    direction: pull                     # pull = remote → HA
    options: '--archive --compress'     # optional: override default rsync flags
```

### Options reference

| Key | Required | Description |
| --- | --- | --- |
| `private_key_file` | Yes | Path to the SSH private key (must be under `/ssl/`) |
| `username` | Yes | SSH username on the remote machine |
| `remote_host` | Yes | IP address or hostname of the remote machine |
| `remote_port` | No | SSH port (default: `22`) |
| `folders[].local` | Yes | Local path on Home Assistant |
| `folders[].remote` | Yes | Remote path on the target machine |
| `folders[].direction` | No | `push` (HA → remote) or `pull` (remote → HA). Default: `push` |
| `folders[].options` | No | rsync flags. Default: `--archive --recursive --compress --delete --prune-empty-dirs` |

---

## SSH Key Setup

If no key file exists at `private_key_file`, the add-on generates an **Ed25519** key pair on first run and saves it to the configured path.

To authorize the key on your remote machine, copy the **public key** (`/ssl/rsync/id_rsa.pub`) to the remote:

```bash
ssh-copy-id -i /path/to/id_rsa.pub myuser@192.168.1.100
```

Or manually append the contents of `id_rsa.pub` to `~/.ssh/authorized_keys` on the remote.

> The add-on uses `StrictHostKeyChecking=accept-new` — it will automatically trust a host on the **first** connection and verify it on all subsequent ones. If the host key changes unexpectedly, the sync will fail and log an error.

---

## Running on a Schedule

This add-on runs once and exits. Use a **Home Assistant Automation** to trigger it on a schedule:

```yaml
automation:
  alias: Nightly rsync backup
  trigger:
    - platform: time
      at: "02:00:00"
  action:
    - service: hassio.addon_start
      data:
        addon: local_rsync
```

---

## Volumes Accessible to This Add-on

| Volume | Access | Notes |
| --- | --- | --- |
| `/share` | read/write | General shared storage |
| `/config` | read/write | Home Assistant configuration |
| `/ssl` | read/write | SSH key storage |
| `/backup` | **read-only** | HA backup archives |
| `/media` | **read-only** | Media files |

---

## Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| `bash: rsync: command not found` | rsync not installed on the remote machine |
| `Permission denied (publickey)` | Public key not in `authorized_keys` on the remote |
| `Host key verification failed` | Remote host key changed — remove the old entry from the container's `known_hosts` |
| Sync exits after first folder fails | Check logs for `Sync failed:` entries; remaining folders will still be attempted |
