#!/usr/bin/env bash
set -euo pipefail
set -a; . /etc/restic/env; set +a
META=/var/backups/meta

dnf repoquery --userinstalled > $META/packages.txt || true
lsblk -f > $META/lsblk.txt
blkid > $META/blkid.txt
findmnt > $META/findmnt.txt
firewall-cmd --list-all-zones > $META/firewall.txt || true
semanage export -f $META/selinux.txt || true
systemctl list-unit-files --state=enabled > $META/enabled-services.txt

restic backup --files-from /etc/restic/include.txt \
  --exclude-file /etc/restic/exclude.txt --tag daily

restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune

restic check --read-data-subset=5%
