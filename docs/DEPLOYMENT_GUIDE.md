# GitHub Actions Deployment Guide

Automatický deployment na RPi5 při push na `main` branch.

## Setup

### 1. Generate SSH key for deployment

Na vašem počítači:

```bash
ssh-keygen -t ed25519 -f ha-deploy -C "ha-deploy-key"
cat ha-deploy.pub
```

### 2. Add public key to RPi

Na RPi5 (nebo SSH):

```bash
# Přidat veřejný klíč
echo "ssh-ed25519 AAAA..." >> ~/.ssh/authorized_keys

# Zkontrolovat
ssh-keygen -l -f ~/.ssh/authorized_keys
```

### 3. Add secret to GitHub

V GitHub repository settings → Secrets and variables → Actions:

**Nový secret: `RPI_SSH_KEY`**
- Obsah: Celý **privátní klíč** (ha-deploy bez .pub)

```bash
cat ha-deploy | pbcopy  # Na Mac
# Nebo na Linux:
cat ha-deploy | xclip -selection clipboard
```

### 4. Optional: Customize workflow

Upravte `.github/workflows/deploy.yml`:

```yaml
on:
  push:
    branches: [ main ]
    paths:
      - 'CONFIG/**'          # Trigger on config changes
      - 'docker-compose.yml' # Trigger on compose changes
```

## Usage

### Automatic deployment

Při každém `push` na `main`:

```bash
git add CONFIG/configuration.yaml
git commit -m "Update HA config"
git push origin main
# ↓ GitHub Actions automatically:
# 1. Validates YAML
# 2. Checks bash syntax
# 3. SSHs to RPi
# 4. Syncs configs
# 5. Restarts Docker
# 6. Performs health check
```

### Manual deployment

V GitHub Actions tab → "Deploy to RPi" → "Run workflow":

```
target_host: 192.168.1.100 (nebo homeassistant.local)
```

## What happens

### Validation stage

- ✅ YAML validation (PyYAML)
- ✅ Bash syntax check
- ✅ Docker compose syntax

### Deployment stage

1. SSH na RPi
2. `git pull origin main`
3. `./scripts/sync_config.sh --force --validate`
4. `docker-compose down && docker-compose up -d`
5. Health check (curl, docker ps)
6. Notification (success/failure)

## Troubleshooting

### SSH key not configured

Workflow zobrazí:

```
⚠️ RPI_SSH_KEY not configured. Skipping deployment.
```

**Řešení:**
1. Vygenerujte SSH klíč (viz výše)
2. Přidejte do `.github/workflows/deploy.yml` v sekci `deploy` → `steps`
3. Nakonfigurujte GitHub secret

### Deployment timeout

Pokud se HA spouští dlouho:

```yaml
- name: Wait for HA
  run: sleep 30 && curl -f http://localhost:8123 || true
```

### Health check fails

```bash
# Na RPi ověřit ručně:
docker-compose ps
docker logs homeassistant | tail -50
curl http://localhost:8123
```

## Advanced

### Deploy na více RPi

Upravte workflow pro loop:

```yaml
strategy:
  matrix:
    host: ['rpi1.local', 'rpi2.local']
jobs:
  deploy:
    steps:
      - run: ssh pi@${{ matrix.host }} ...
```

### Environment variables

Přidejte v `github.com/settings/secrets/actions`:

```
RPI_HOSTNAME=homeassistant.local
RPI_USER=pi
```

Pak v workflow:

```yaml
env:
  TARGET_HOST: ${{ secrets.RPI_HOSTNAME }}
  RPI_USER: ${{ secrets.RPI_USER }}
```

### Notifications

Přidejte webhook notification:

```yaml
- name: Slack notification
  uses: 8398a7/action-slack@v3
  with:
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
    status: ${{ job.status }}
```

## Security Best Practices

1. ✅ Use ed25519 SSH keys (not RSA)
2. ✅ Store only **private key** in GitHub secret
3. ✅ Rotate SSH keys every 6 months
4. ✅ Limit SSH key permissions on RPi
5. ✅ Use branch protection (require status checks)

## Monitoring

V GitHub Actions tab:

- ✅ Green checkmark = deployment successful
- ❌ Red X = deployment failed
- 🟡 Yellow = running

Klikněte na workflow run pro detaily.
