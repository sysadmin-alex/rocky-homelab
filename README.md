# rocky-homelab

Unattended **Rocky Linux 10.2** installs. A Kickstart file is baked into a bootable ISO with `mkksiso`. After the install, a first-boot script hardens the system and logs every step.

## What it does

1. Builds a custom ISO that installs Rocky Linux with no prompts (`ks.cfg`).
2. During install, `%post` downloads `setup.sh` and registers a one-time systemd service (`firstboot.service`).
3. On first boot, `setup.sh` applies updates, hardens SSH, checks SELinux and the firewall, and validates the result.

```mermaid
flowchart LR
    A["Boot ISO + ks.cfg (mkksiso)"] --> B["Unattended install"]
    B --> C["%post: fetch setup.sh, create firstboot.service"]
    C --> D["Reboot"]
    D --> E["firstboot.service runs setup.sh once"]
    E --> F["Log + /var/lib/firstboot.done"]
```

## Repository layout

| File | Purpose |
|---|---|
| `ks.cfg` | Kickstart file: disks, user, network, packages, base security settings |
| `setup.sh` | First-boot hardening script, run once after the install |

## Build the ISO

Requirements: `mkksiso` (lorax), `xorriso`, and the Rocky 10.2 boot ISO.

```bash
sudo mkksiso --ks ks.cfg Rocky-10.2-x86_64-boot.iso ./auto.iso

# Extract the grub configs so they can be adjusted
xorriso -osirrox on -indev auto.iso \
  -extract /EFI/BOOT/grub.cfg efi-grub.cfg \
  -extract /boot/grub2/grub.cfg bios-grub.cfg

# Repack the ISO with the edited grub configs
xorriso \
  -indev auto.iso \
  -outdev final_kickstart.iso \
  -boot_image any replay \
  -map ./efi-grub.cfg /EFI/BOOT/grub.cfg \
  -map ./bios-grub.cfg /boot/grub2/grub.cfg
```

Boot a VM from `final_kickstart.iso`. The install runs with no input and reboots into the finished system.

## ks.cfg

| Area | Setting |
|---|---|
| Mode | Text, non-interactive, `en_US.UTF-8`, US keyboard |
| Time | `Europe/Athens`, Greek NTP pool (`0.gr.pool.ntp.org`, `1.gr.pool.ntp.org`) |
| Access | Root locked; `sysadmin` user in `wheel` with an SSH public key |
| Source | Rocky 10.2 BaseOS and AppStream from `dl.rockylinux.org` |
| Disk | GPT, `autopart` without LVM, XFS, no separate `/home` |
| Network | DHCP, hostname `rocky99`, DNS `1.1.1.1` |
| Security | SELinux enforcing; firewall enabled with SSH only |
| Services | `sshd`, `chronyd`, `auditd`, `NetworkManager`, `rsyslog` |
| Packages | `@^server-product-environment`, `audit`, `rsyslog`, `bash-completion`, `open-vm-tools`, `httpd` |
| `%post` | Downloads `setup.sh` to `/usr/local/sbin/`, creates and enables `firstboot.service` |

`firstboot.service` runs `setup.sh` once. It starts after the network and `firewalld`, writes output to `/var/log/firstboot_script.log`, and creates `/var/lib/firstboot.done` on success so it does not run again. If the script fails, it retries on the next boot.

## setup.sh

| Step | What it does |
|---|---|
| Updates | `dnf upgrade`, installs `dnf-automatic` set to security updates, enables its timer |
| Time | Enables `chronyd`, forces a sync, shows tracking status |
| SSH | Drop-in `00-hardening.conf`: no root login, `MaxAuthTries 3`, `wheel` only. Password login is turned off only if `sysadmin` has an authorized key |
| SELinux | Confirms Enforcing, fixes Permissive, fails if Disabled |
| Firewall | Allows SSH, removes `cockpit` |
| Logging | Enables `auditd`, sets persistent `journald` storage |
| Validation | Checks that services are active, prints SELinux status, notes whether a reboot is needed |

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

## Screenshots

<!-- Add a short caption above each image: what step it shows -->

<img width="975" height="79" alt="image" src="https://github.com/user-attachments/assets/11092fd9-3b00-4a8a-a52b-11c4ff7d8105" />
<img width="975" height="70" alt="image" src="https://github.com/user-attachments/assets/c5cd4849-79d7-423b-b116-e67678ef31f2" />
<img width="1088" height="56" alt="image" src="https://github.com/user-attachments/assets/34a970fd-beeb-4379-8160-b8c6b8156c16" />
<img width="561" height="113" alt="boot" src="https://github.com/user-attachments/assets/e50951af-77a1-459f-a7f4-6de5fe7b5ef0" />
<img width="728" height="294" alt="image" src="https://github.com/user-attachments/assets/2b2b2056-5962-465a-b4e0-fc3bb242f7f3" />
<img width="306" height="193" alt="image" src="https://github.com/user-attachments/assets/0bbf5b7a-1b16-4ef0-bc6e-ef52f152f8e0" />
<img width="1040" height="758" alt="image" src="https://github.com/user-attachments/assets/b333b75a-de3c-4d21-a6fd-9b25248dc13f" />
<img width="319" height="67" alt="image" src="https://github.com/user-attachments/assets/d9590648-7eb5-4249-a78d-be3ab12a5814" />
<img width="665" height="113" alt="image" src="https://github.com/user-attachments/assets/64992ddb-da10-41ca-b882-46f9b9b68ee6" />
<img width="1363" height="609" alt="image" src="https://github.com/user-attachments/assets/7f51b5bf-43bd-48be-8040-1f6c576a7a9c" />
<img width="764" height="807" alt="image" src="https://github.com/user-attachments/assets/5d6c80c9-2caf-4b4c-8719-7034bddbda84" />
<img width="1179" height="645" alt="image" src="https://github.com/user-attachments/assets/42b269e2-8104-4715-ae33-7693af92c855" />

## Before you use it

- Replace the SSH public key and the `--password` hash in `ks.cfg` with your own. Generate a hash with `openssl passwd -6`. Never commit a real password hash.
- `setup.sh` is fetched from the `main` branch for simplicity. For production, pin it to a commit with a checksum, or use `ansible-pull` with signed commits.

## Roadmap

- [ ] Move hardening into Ansible roles and run them with `ansible-pull`
- [ ] Add `ansible-lint` and `ksvalidator` checks with GitHub Actions
- [ ] Add OpenSCAP (CIS) scan results before and after hardening
- [ ] Add backups and monitoring
