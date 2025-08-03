# Globtim Backup & Security Usage Guide

## 🚀 Quick Start

### 1. Initial Setup (Run Once)
```bash
# Set up secure SSH
./setup_secure_ssh.sh

# Install security hooks
./install_security_hooks.sh

# Create your config file
cp cluster_config.sh.template cluster_config.sh
# Edit cluster_config.sh with your server details

# Set up automated weekly backups
./setup_weekly_backup.sh
```

### 2. Create Your Config File
Edit `cluster_config.sh` (this file is gitignored):
```bash
export REMOTE_HOST="scholten@fileserver-ssh"
export REMOTE_PATH="~/globtim"
export SSH_KEY_PATH="~/.ssh/id_ed25519"
```

## 📅 Daily Development Workflow

### Upload Changes to Server
```bash
# Quick sync
./upload_to_cluster.sh

# Sync + setup Julia environment
./upload_to_cluster.sh --setup

# Sync + run tests
./upload_to_cluster.sh --test
```

### Manual Backup
```bash
# Create immediate backup
./weekly_backup.sh
```

## 🔒 Security Management

### Monthly Security Audit
```bash
# Check for security issues
./security_audit.sh
```

### Check Backup Status
```bash
# View recent backups on server
ssh -i ~/.ssh/id_ed25519 scholten@fileserver-ssh "ls -lah globtim_backups/"

# View backup logs
tail -f backup.log
```

## 🔄 Backup Management

### Automated Backups
- **When**: Every Sunday at 2:00 AM
- **Retention**: Last 8 weeks (automatically cleaned)
- **Location**: `~/globtim_backups/` on fileserver
- **Logs**: `backup.log` in your project directory

### Manual Backup Operations
```bash
# Create backup now
./weekly_backup.sh

# Restore a backup
./restore_backup.sh

# View backup history
ssh -i ~/.ssh/id_ed25519 scholten@fileserver-ssh "cat globtim_backups/backup_manifest.txt"
```

## 📊 Monitoring

### Check Cron Job Status
```bash
# View current cron jobs
crontab -l

# Check if backup ran
tail backup.log
```

### Backup Space Usage
```bash
# Check space on server
ssh -i ~/.ssh/id_ed25519 scholten@fileserver-ssh "du -sh globtim_backups/"
```

## 🛠 Troubleshooting

### SSH Issues
```bash
# Test SSH connection
ssh -i ~/.ssh/id_ed25519 scholten@fileserver-ssh "echo 'Connection OK'"

# Fix SSH permissions
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
```

### Backup Issues
```bash
# Manual backup with verbose output
./weekly_backup.sh

# Check server disk space
ssh -i ~/.ssh/id_ed25519 scholten@fileserver-ssh "df -h"
```

### Security Issues
```bash
# Run security audit
./security_audit.sh

# Check for sensitive files
find . -name "*.key" -o -name "*password*"
```

## 📋 File Structure

```
globtim/
├── upload_to_cluster.sh      # Main sync script
├── weekly_backup.sh          # Backup script
├── restore_backup.sh         # Restore script
├── setup_weekly_backup.sh    # Backup automation setup
├── security_audit.sh         # Security checker
├── setup_secure_ssh.sh       # SSH hardening
├── cluster_config.sh         # Your server config (gitignored)
├── backup.log               # Backup logs
└── BACKUP_USAGE_GUIDE.md    # This guide
```

## ⚡ Quick Commands Reference

| Task | Command |
|------|---------|
| Sync to server | `./upload_to_cluster.sh` |
| Backup now | `./weekly_backup.sh` |
| Restore backup | `./restore_backup.sh` |
| Security check | `./security_audit.sh` |
| View backups | `ssh -i ~/.ssh/id_ed25519 scholten@fileserver-ssh "ls -lah globtim_backups/"` |
| Check logs | `tail -f backup.log` |
