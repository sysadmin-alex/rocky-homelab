#!/usr/bin/env bash
set -euo pipefail
log() { echo "$(date -Is) [firstboot] $*"; }

log "updates"
dnf -y upgrade
dnf -y install epel-release
dnf -y install dnf-automatic
sed -i 's/^upgrade_type.*/upgrade_type = security/' /etc/dnf/automatic.conf
systemctl enable --now dnf-automatic-install.timer

log "chrony"
systemctl enable --now chronyd
chronyc makestep || true
chronyc tracking || true

log "ssh"
if [ -s /home/sysadmin/.ssh/authorized_keys ]; then PASSAUTH=no
else PASSAUTH=yes; log "WARNING: no SSH key found, leaving password login on"; fi
mkdir -p /etc/ssh/sshd_config.d
cat > /etc/ssh/sshd_config.d/00-hardening.conf <<EOF
PermitRootLogin no
PasswordAuthentication ${PASSAUTH}
MaxAuthTries 3
AllowGroups wheel
EOF
chmod 600 /etc/ssh/sshd_config.d/00-hardening.conf
restorecon /etc/ssh/sshd_config.d/00-hardening.conf
sshd -t
systemctl reload sshd
sshd -T | grep -E '^(permitrootlogin|passwordauthentication|allowgroups)'

log "selinux"
case "$(getenforce)" in
  Enforcing) ;;
  Permissive) setenforce 1 ;;
  *) log "ERROR: SELinux is disabled; fix in Kickstart and relabel"; exit 1 ;;
esac

log "firewall"
systemctl is-active --quiet firewalld
firewall-cmd --permanent --add-service=ssh
firewall-cmd --permanent --remove-service=cockpit || true
firewall-cmd --reload

log "audit and journald"
systemctl enable auditd
mkdir -p /etc/systemd/journald.conf.d /var/log/journal
printf '[Journal]\nStorage=persistent\n' > /etc/systemd/journald.conf.d/persistent.conf
systemctl restart systemd-journald

log "validation"
systemctl is-active chronyd sshd auditd firewalld
getenforce
dnf needs-restarting -r || log "reboot recommended"
log "done"
