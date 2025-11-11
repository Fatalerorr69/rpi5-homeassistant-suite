# Ansible Setup Guide

Setup Home Assistant Suite on RPi5 using Ansible.

## Prerequisites

### On your local machine:

```bash
# Install Ansible
pip install ansible

# Or with apt (Ubuntu/Debian)
sudo apt-get install ansible
```

### On RPi5:

```bash
# SSH access enabled
sudo systemctl start ssh
sudo systemctl enable ssh

# Python3 installed
python3 --version
```

## Quick Start

### 1. Setup inventory

Edit `inventory.ini`:

```ini
[rpi5]
rpi5_host ansible_host=homeassistant.local ansible_user=pi
```

Or multiple hosts:

```ini
[rpi5]
rpi1 ansible_host=192.168.1.100 ansible_user=pi
rpi2 ansible_host=192.168.1.101 ansible_user=pi
```

### 2. Configure SSH (recommended)

**Generate SSH key:**

```bash
ssh-keygen -t ed25519 -f ~/.ssh/ansible_rpi
```

**Copy to RPi:**

```bash
ssh-copy-id -i ~/.ssh/ansible_rpi.pub pi@homeassistant.local
```

**Update inventory:**

```ini
[rpi5:vars]
ansible_ssh_private_key_file=~/.ssh/ansible_rpi
```

### 3. Run playbook

```bash
# Test connection
ansible -i ansible/inventory.ini rpi5 -m ping

# Run full provisioning
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml

# Or ask for password
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml -k
```

## What playbook does

1. ✅ Updates system packages
2. ✅ Installs dependencies (Docker, Python, Git, etc.)
3. ✅ Clones repository
4. ✅ Creates config directories
5. ✅ Syncs configs and validates YAML
6. ✅ Starts Docker services
7. ✅ Sets up cron backups
8. ✅ Configures maintenance
9. ✅ Enables monitoring
10. ✅ Shows deployment summary

## Advanced usage

### Run specific tasks

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --tags docker
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml --skip-tags monitoring
```

### Run on specific hosts

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml -l rpi1
```

### Dry run (check mode)

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml -C
```

### Verbose output

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml -vvv
```

## Troubleshooting

### SSH connection failed

```bash
# Test SSH
ssh -i ~/.ssh/ansible_rpi pi@homeassistant.local

# Or check with Ansible
ansible -i ansible/inventory.ini rpi5 -m setup
```

### Python not found

Ansible needs Python. Install on RPi:

```bash
sudo apt-get install python3 python3-pip
```

### Permission denied

Ensure user can run docker without sudo:

```bash
ssh pi@homeassistant.local
sudo usermod -aG docker $USER
# Log out and log in
```

## Idempotence

Playbook is idempotent — can be run multiple times safely. Re-running will:
- Update packages
- Sync configs
- Restart services (if changed)

## Post-deployment

After playbook completes:

```bash
ssh pi@homeassistant.local
cd ~/rpi5-homeassistant-suite

# Check status
docker-compose ps

# Setup additional features
./POST_INSTALL/post_install_setup_menu.sh
```

## Scaling

For multiple RPi5 hosts, update inventory with each host and run:

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
```

Each host will be provisioned independently in parallel.
