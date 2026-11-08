# Automated Hardening & Backup Pipeline

A streamlined setup for hands-free OS installation, automated system hardening, and secure local backups using Restic.

---

## 1. Hands-Free Installation & Kickstart

The installation process is fully automated via Kickstart. During the `%post` phase, configuration scripts are fetched and executed automatically, including setting up your public SSH key for secure remote access.

> **Note:** Always double-check your SSH configurations during kickstart deployments to prevent accidental lockouts.

| Hands-Free Setup | Post-Install Script Execution |
| :---: | :---: |
| <img src="https://github.com/user-attachments/assets/b333b75a-de3c-4d21-a6fd-9b25248dc13f" width="480" /> | <img src="https://github.com/user-attachments/assets/0ae933c5-2e4b-4373-93cd-016a5ff569b3" width="480" /> |

* **Script Status:** Active and executing via curl payload in the kickstart `%post-%end` block.
* **SSH Integration:** Automated injection of authorized public keys.

---

## 2. System Hardening Logs

Once the system boots, the hardening script runs to lock down the environment. Below are sample execution logs showing the hardening tasks being applied:

<img src="https://github.com/user-attachments/assets/5d6c80c9-2caf-4b4c-8719-7034bddbda84" alt="Hardening logs part 1" width="700" />

<img src="https://github.com/user-attachments/assets/42b269e2-8104-4715-ae33-7693af92c855" alt="Hardening logs part 2" width="700" />

---

## 3. Automated Backups with Restic

Backups are handled via **Restic**, configured to run seamlessly on the system.

### Installation & Initialization
```bash
# Install Restic
dnf install restic -y # or your package manager equivalent

# Initialize the backup repository
restic init -r /opt/backups/my-repo
```

### Backup Script (`/usr/local/sbin/backup.sh`)
The custom backup script handles repository snapshots and cleanup:

<img src="https://github.com/user-attachments/assets/ba1dd895-2d76-46e0-9ceb-250a6aafd159" alt="backup.sh script" width="550" />

### Manual Execution & Verification
Running the backup script manually confirms snapshots are successfully created and stored:

<img src="https://github.com/user-attachments/assets/d2cfde4f-fe78-48b4-87eb-e692e84db297" alt="Manual backup execution" width="700" />

### Restoring from Backup
To restore your system or files from the latest snapshot, run:

```bash
restic -r /opt/backups/my-repo restore latest --target /
```
