# rocky-homelab

Unattended **Rocky Linux 10.2** install. A Kickstart file is baked into a bootable ISO with `mkksiso`. After the install, a first-boot script hardens the system and logs every step. A separate script handles encrypted, deduplicated backups with restic.

Rocky Linux is a community RHEL-compatible distribution.

## What it does

1. Builds a custom ISO that installs Rocky Linux with no prompts (`ks.cfg`).
2. During install, `%post` downloads `setup.sh` and registers a one-time systemd service (`firstboot.service`). It also sets up the SSH public key for the `sysadmin` user.
3. On first boot, `setup.sh` applies updates, hardens SSH, checks SELinux and the firewall, and validates the result.
4. `backup.sh` takes restic snapshots of the chosen paths and logs the run.

```mermaid
flowchart LR
    A["Boot ISO + ks.cfg (mkksiso)"] --> B["Unattended install"]
    B --> C["%post: fetch setup.sh, create firstboot.service"]
    C --> D["Reboot"]
    D --> E["firstboot.service runs setup.sh once"]
    E --> F["Log + /var/lib/firstboot.done"]
```

## Repository layout

| File        | Purpose                                                                                 |
|-------------|-----------------------------------------------------------------------------------------|
| `ks.cfg`    | Kickstart file: disks, user, network, packages, base security settings                  |
| `setup.sh`  | First-boot hardening script, run once after the install                                 |
| `backup.sh` | Selects what to back up, logs the run, then hands the data over to restic               |

## Quick start

Requirements: `mkksiso` (from lorax), `xorriso`, and the Rocky 10.2 boot ISO.

```bash
# 1. Bake the Kickstart file into the ISO
sudo mkksiso --ks ks.cfg Rocky-10.2-x86_64-boot.iso ./auto.iso

# 2. Extract the GRUB configs so they can be adjusted
xorriso -osirrox on -indev auto.iso \
  -extract /EFI/BOOT/grub.cfg efi-grub.cfg \
  -extract /boot/grub2/grub.cfg bios-grub.cfg

# 3. Shorten the menu timeout to 5 s so the install starts by itself
sed -i 's/^set timeout=.*/set timeout=5/; s/^set default=.*/set default="0"/' efi-grub.cfg bios-grub.cfg

# 4. Repack the ISO with the edited GRUB configs
xorriso \
  -indev auto.iso \
  -outdev final_kickstart.iso \
  -boot_image any replay \
  -map ./efi-grub.cfg /EFI/BOOT/grub.cfg \
  -map ./bios-grub.cfg /boot/grub2/grub.cfg
```

Boot a VM from `final_kickstart.iso`. The install runs with no input and reboots into the finished system.

> **Note:** Double-check the SSH key and SSH settings in `ks.cfg` before deploying, so you do not lock yourself out.

## Screenshots

Tested in a VM with a 23 GB SATA disk, 2.6 GB RAM, 4 CPU cores and NAT networking.

### Install

| Hands-free setup | Post-install script execution |
|:---:|:---:|
| <img src="https://github.com/user-attachments/assets/b333b75a-de3c-4d21-a6fd-9b25248dc13f" alt="Hands-free Kickstart install" width="100%"> | <img src="https://github.com/user-attachments/assets/0ae933c5-2e4b-4373-93cd-016a5ff569b3" alt="setup.sh fetched and executed from %post" width="100%"> |

The script is fetched with `curl` in the `%post` block and runs on first boot.

### Hardening logs

Sample output from `setup.sh` applying the hardening steps:

| Part 1 | Part 2 |
|:---:|:---:|
| <img src="https://github.com/user-attachments/assets/5d6c80c9-2caf-4b4c-8719-7034bddbda84" alt="Hardening logs part 1" width="100%"> | <img src="https://github.com/user-attachments/assets/42b269e2-8104-4715-ae33-7693af92c855" alt="Hardening logs part 2" width="100%"> |

## What gets configured

### ks.cfg

| Area     | Setting                                                                                 |
|----------|-----------------------------------------------------------------------------------------|
| Mode     | Text, non-interactive, `en_US.UTF-8`, US keyboard                                       |
| Time     | `Europe/Athens`, Greek NTP pool (`0.gr.pool.ntp.org`, `1.gr.pool.ntp.org`)              |
| Access   | Root locked; `sysadmin` user in `wheel` with an SSH public key                          |
| Source   | Rocky 10.2 BaseOS and AppStream from `dl.rockylinux.org`                                |
| Disk     | GPT, `autopart` without LVM, XFS, no separate `/home`                                   |
| Network  | DHCP, hostname `rocky99`, DNS `1.1.1.1`                                                 |
| Security | SELinux enforcing; firewall enabled with SSH only                                       |
| Services | `sshd`, `chronyd`, `auditd`, `NetworkManager`, `rsyslog`                                |
| Packages | `@^server-product-environment`, `audit`, `rsyslog`, `bash-completion`, `open-vm-tools`  |
| `%post`  | Downloads `setup.sh` to `/usr/local/sbin/`, creates and enables `firstboot.service`     |

`firstboot.service` runs `setup.sh` once. It starts after the network and `firewalld`, writes output to `/var/log/firstboot_script.log`, and creates `/var/lib/firstboot.done` on success so it does not run again. If the script fails, it retries on the next boot.

### setup.sh

| Step       | What it does                                                                                                                                   |
|------------|------------------------------------------------------------------------------------------------------------------------------------------------|
| Updates    | `dnf upgrade`, installs `dnf-automatic` set to security updates, enables its timer                                                             |
| Time       | Enables `chronyd`, forces a sync, shows tracking status                                                                                        |
| SSH        | Drop-in `00-hardening.conf`: no root login, `MaxAuthTries 3`, `wheel` only. Password login is turned off only if `sysadmin` has an authorized key |
| SELinux    | Confirms Enforcing, fixes Permissive, fails if Disabled                                                                                        |
| Firewall   | Allows SSH, removes `cockpit`                                                                                                                  |
| Logging    | Enables `auditd`, sets persistent `journald` storage                                                                                           |
| Validation | Checks that services are active, prints SELinux status, notes whether a reboot is needed                                                       |

The script uses `set -euo pipefail`, so a failed step stops it instead of continuing silently.

## Verify after install

```bash
systemctl status firstboot
cat /var/log/firstboot_script.log
ls /var/lib/firstboot.done
sshd -T | grep -E 'permitrootlogin|passwordauthentication|allowgroups'
getenforce
systemctl list-timers | grep dnf
```

Reboot once and check that the log shows no second run.

## Backups with restic

`backup.sh` decides which paths go into the backup, logs the run, and hands the data to [restic](https://restic.net/).

### Setup

```bash
# Install restic
sudo dnf install restic -y

# Initialize the repository
restic init -r /opt/backups/my-repo

# Install the script
sudo install -m 750 backup.sh /usr/local/sbin/backup.sh
```

<img src="https://github.com/user-attachments/assets/ba1dd895-2d76-46e0-9ceb-250a6aafd159" alt="backup.sh script" width="80%">

### Run and verify

Run the script manually and confirm that snapshots are created:

```bash
sudo /usr/local/sbin/backup.sh
restic -r /opt/backups/my-repo snapshots
```

<img src="https://github.com/user-attachments/assets/d2cfde4f-fe78-48b4-87eb-e692e84db297" alt="Manual backup execution showing snapshots" width="80%">

### Restore

Restore into a scratch directory first and inspect the result:

```bash
restic -r /opt/backups/my-repo restore latest --target /tmp/restore-test
```

Restoring with `--target /` overwrites live files, so only do that when you really mean to replace the system state.

> **Limitation:** the repository above is on the same disk as the system. That protects against deleted or corrupted files, but not against disk failure. For a real backup, add a second copy elsewhere (another machine over SFTP, or object storage) and run `restic check` regularly.
