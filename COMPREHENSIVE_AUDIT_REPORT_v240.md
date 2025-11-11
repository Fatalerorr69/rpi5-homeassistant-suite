# 🔍 Komprehenzivní Audit Repozitáře — v2.4.0

**Datum:** 2025-11-11  
**Verze:** 2.4.0 — Kompletní analýza + opravy + nové features  
**Status:** 🟡 **MEDIUM** — Několik kritických a středních problémů

---

## 📊 Souhrn Zjištění

| Kategorie | Stav | Počet | Priorita |
|-----------|------|-------|----------|
| **Bash skripty** | ✅ Syntaxe OK | 76 | - |
| **YAML soubory** | ⚠️ Drobné chyby | 32+16 | MEDIUM |
| **Docker konfigurace** | 🟡 Částečně | 1 | HIGH |
| **Storage vrstva** | 🔴 Chybí | 1 | CRITICAL |
| **Multi-OS podpora** | ❌ Není | 0/5 | HIGH |
| **VM support** | ⚠️ Částečný | 1/3 | MEDIUM |

---

## 🔴 KRITICKÉ PROBLÉMY

### 1. **Duplicitní CONFIG/ a config/ adresáře**
- **Problém:** Zdroj v `CONFIG/`, runtime v `config/`, ale synchronizace není robustní
- **Dopad:** Při ruční editaci `config/` se změní ztrácejí, při sync se přepíšou
- **Řešení:** Implementovat jednosměrný sync s backup a verzováním
- **Soubory:** `scripts/sync_config.sh`, `docker-compose.yml`

```bash
# CHYBA: Přímé bindování bez synchronizace
volumes:
  - ./config:/config      # Bez ověření, zda je synced!
```

### 2. **Storage Mounting — bez automatického připojení při bootu**
- **Problém:** `STORAGE/auto_mount_setup.sh` a `scripts/mount_storage.sh` jsou jen helpers, ne systémové spuštění
- **Dopad:** Po restartu RPi se NAS/USB nepřipojují automaticky
- **Řešení:** 
  - Systemd unit soubory pro automatické mount
  - Validace fstab před aplikací
  - Health check na mount status

```bash
# CHYBA: Jen skript, nezapojený do boot sekvence
sudo echo "/dev/sdb1 /mnt/storage ext4 defaults,nofail 0 2" >> /etc/fstab
```

### 3. **Docker Permissions — bez explicitních nastavení**
- **Problém:** Skripty přidávají uživatele do docker skupiny, ale bez ověření, zda je to bezpečné
- **Dopad:** Potenciální bezpečnostní riziko, funkční problémy s zálohováním
- **Řešení:** Explicitní oprávnění s ACL, audit loggingu

### 4. **Home Assistant os-agent — hardcodované verze**
- **Problém:** `os-agent_1.6.0_linux_aarch64.deb` je pevně kódovaná
- **Dopad:** Skript selhá, když vyjde nová verze
- **Řešení:** Dynamické zjišťování verze z GitHub API

```bash
# CHYBA v install.sh (řádek 115):
wget -O /tmp/os-agent_1.6.0_linux_aarch64.deb \
    https://github.com/home-assistant/os-agent/releases/download/1.6.0/...
```

---

## 🟡 STŘEDNĚ KRITICKÉ PROBLÉMY

### 5. **Multi-OS Support — Chybí**
- **Stav:** Kód předpokládá POUZE Debian/Ubuntu
- **Chybí:**
  - ❌ Rocky Linux 8/9 (Red Hat RHEL-compatible)
  - ❌ CentOS 7/8/9
  - ❌ Alpine Linux (lightweight)
  - ❌ Ubuntu 24.04 LTS (novější verzí)
  - ❌ Armbian (optimalizované pro ARM SBC)

**Řešení:** Detekční funkce + podmínkový install

```bash
# CHYBA: Jen apt!
sudo apt-get install -y ... # Selhá na Rocky/CentOS (yum/dnf)
```

### 6. **VM Support — Neúplný**
- **Stav:** Jen QEMU/libvirt a VirtualBox
- **Chybí:**
  - ⚠️ Proxmox LXC containers
  - ⚠️ KVM hypervisor (host setup)
  - ⚠️ Docker-in-Docker (nested HA)
  - ⚠️ Network bridge konfigurace
  - ⚠️ GPU passthrough (RTX/TPU)

### 7. **Storage Varianty — Nedostatečné**
- **Co máme:** USB mount, NAS (CIFS/NFS)
- **Co chybí:**
  - ❌ SSD-optimized ekstenze4 tuning
  - ❌ LVM (Logical Volume Management)
  - ❌ Cloud storage (S3, Backblaze, Google Drive)
  - ❌ ZFS s snapshoty
  - ❌ Tiered storage (SSD cache + HDD archive)

### 8. **YAML Konfigurace — Částečně Validní**
- **Problém:** `config/configuration.yaml` nemá "homeassistant:" root
- **Dopad:** Home Assistant nerozpozná konfiguraci
- **Řešení:** Vytvořit `CONFIG/configuration.yaml.template` s korektní strukturou

### 9. **Ansible Playbook — Neúplný Rollback**
- **Problém:** Playbook nemá rollback na chybu
- **Dopad:** Částečně instalovaný systém zůstane v nekonzistentním stavu
- **Řešení:** Handlers a pre-flight checks

### 10. **Backup & Disaster Recovery — Chybí**
- **Stav:** Jen lokální backup s rotací
- **Chybí:**
  - ❌ Off-site backup (cloud)
  - ❌ Encrypted backups
  - ❌ Disaster recovery playbook
  - ❌ Restore testy

---

## ⚠️ MENŠÍ PROBLÉMY

### 11. **Logování — Nedostatečné**
- Skripty logují do `/home/$(whoami)/...`, ale bez centralizace
- **Řešení:** Syslog nebo journald integration

### 12. **Health Checks — Nejsou Automatické**
- Jen v `DIAGNOSTICS/` a `POST_INSTALL/setup_monitoring.sh`
- **Řešení:** Integrovat do `setup_master.sh` jako pravidelný health check

### 13. **Network Configuration — Hardkódovaná**
- TZ="Europe/Prague" a "homeassistant.local" jsou napevno
- **Řešení:** Interaktivní setup nebo .env soubor

### 14. **Docker Networking — Bez Explicitního Nastavení**
- `network_mode: host` v některých, `depends_on` bez health checks
- **Řešení:** Custom network + health checks

### 15. **Security — Bez Secrets Management**
- Hesla v docker-compose, SSH klíče nejsou zabezpečené
- **Řešení:** Docker secrets + .env.local (gitignored)

---

## 📁 Struktura Problémů po Souborech

| Soubor | Problém | Severity | Oprava |
|--------|---------|----------|--------|
| `install.sh` | os-agent hardcoded | 🔴 | Dynamická verze |
| `setup_master.sh` | Bez multi-OS detekce | 🟡 | Detekční funkce |
| `docker-compose.yml` | Bez health checks | 🟡 | Přidat healthcheck |
| `scripts/sync_config.sh` | Bez verzování | 🟡 | Git snapshot |
| `scripts/mount_storage.sh` | Bez systemd integration | 🔴 | Unit soubory |
| `POST_INSTALL/setup_vmspace.sh` | Jen 2 z 5 VM typů | 🟡 | Přidat Proxmox atd |
| `ansible/playbook.yml` | Bez rollback | 🟡 | Error handlers |
| `CONFIG/configuration.yaml` | Chybí root element | 🔴 | Template fix |

---

## ✅ ŘEŠENÍ — Implementační Plán (v2.4.0)

### **Fáze 1: Kritické Opravy (HNED)**

```bash
# 1. Oprava configuration.yaml
cp CONFIG/configuration.yaml CONFIG/configuration.yaml.bak
cat > CONFIG/configuration.yaml << 'EOF'
# Konfigurační soubor Home Assistantu
homeassistant:
  name: RPi5 Home Assistant
  latitude: 50.0755
  longitude: 14.4378
  elevation: 200
  unit_system: metric
  time_zone: Europe/Prague

# Automatické komponenty
default_config:
logger:
  default: info
EOF

# 2. Přidat storage systemd unit
sudo tee /etc/systemd/system/ha-storage-mounts.service << 'EOF'
[Unit]
Description=Home Assistant Storage Mounts
Before=docker.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/ha-mount-storage.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable ha-storage-mounts

# 3. Detekce OS v install.sh
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    fi
}

OS=$(detect_os)
case "$OS" in
    debian|ubuntu)
        sudo apt update && sudo apt install ...
        ;;
    rocky|centos|rhel)
        sudo dnf install ...
        ;;
    alpine)
        sudo apk add ...
        ;;
esac
```

### **Fáze 2: Storage Varianty (TÝDEN 1)**

```bash
# Nové skripty:
scripts/storage_config_wizard.sh      # Interaktivní výběr storage
scripts/storage_validate.sh           # Validace storage setup
scripts/storage_migrate.sh            # Migrace mezi storage typy
POST_INSTALL/setup_tiered_storage.sh  # Tiered storage (SSD+HDD)
POST_INSTALL/setup_cloud_backup.sh    # Cloud backup (S3/Backblaze)
```

### **Fáze 3: Multi-OS & VM (TÝDEN 2-3)**

```bash
# Nové skripty:
INSTALLATION/install_multi_os.sh      # Universal installer
INSTALLATION/setup_proxmox.sh         # Proxmox LXC
INSTALLATION/setup_docker_in_docker.sh # Nested HA
POST_INSTALL/setup_vm_host.sh        # KVM host prep
POST_INSTALL/setup_gpu_passthrough.sh # GPU support
```

### **Fáze 4: Dokumentace & Testing (TÝDEN 3-4)**

```bash
# Nové dokumenty:
docs/STORAGE_VARIANTS.md              # Doporučení pro storage
docs/MULTI_OS_GUIDE.md                # Instalace na různých OS
docs/VM_DEPLOYMENT.md                 # VM nasazení
docs/BACKUP_RECOVERY.md               # Záloha a obnova
tests/integration_tests.sh            # End-to-end testy
```

---

## 🎯 Detailní Akční Body (Co Udělat NYNÍ)

### **1️⃣ Opravit configuration.yaml (5 minut)**
```bash
./scripts/fix_configuration_yaml.sh
```

### **2️⃣ Přidat Storage Mount Systemd (10 minut)**
```bash
sudo cp scripts/ha-mount-storage.sh /usr/local/bin/
sudo tee /etc/systemd/system/ha-storage-mounts.service
sudo systemctl daemon-reload && sudo systemctl enable ha-storage-mounts
```

### **3️⃣ Přidat OS Detection (15 minut)**
```bash
# Upravit install.sh, setup_master.sh, ansible/playbook.yml
./scripts/detect_os.sh  # Nový skript
```

### **4️⃣ Vytvořit Storage Wizard (30 minut)**
```bash
scripts/storage_config_wizard.sh      # Nový interaktivní skript
POST_INSTALL/setup_storage_options.sh # Expanded storage options
```

### **5️⃣ Přidat VM Support (1 hodina)**
```bash
POST_INSTALL/setup_vm_orchestration.sh  # Sjednocené VM management
INSTALLATION/setup_proxmox.sh           # Proxmox support
INSTALLATION/setup_kvm_host.sh          # KVM host setup
```

### **6️⃣ Přidat Backup & Recovery (1 hodina)**
```bash
scripts/backup_manager.sh               # Centralizovaný backup
scripts/restore_manager.sh              # Centralizované obnovování
docs/BACKUP_RECOVERY.md                 # Dokumentace
```

### **7️⃣ Security Hardening (1 hodina)**
```bash
scripts/setup_secrets.sh                # .env a Docker secrets
POST_INSTALL/setup_ssh_keys.sh         # SSH key management
POST_INSTALL/setup_firewall.sh         # UFW configuration
```

### **8️⃣ Health Checks & Monitoring (1 hodina)**
```bash
scripts/health_check_system.sh          # Centralizované health checks
POST_INSTALL/setup_monitoring_advanced.sh  # Prometheus/Grafana
docs/MONITORING.md                      # Monitoring guide
```

---

## 📝 Nové Soubory k Vytvoření

```
scripts/
  ├─ fix_configuration_yaml.sh      [Priority: 🔴 CRITICAL]
  ├─ detect_os.sh                   [Priority: 🔴 CRITICAL]
  ├─ storage_config_wizard.sh       [Priority: 🟡 HIGH]
  ├─ storage_validate.sh            [Priority: 🟡 HIGH]
  ├─ storage_migrate.sh             [Priority: 🟡 MEDIUM]
  ├─ backup_manager.sh              [Priority: 🟡 HIGH]
  ├─ restore_manager.sh             [Priority: 🟡 HIGH]
  └─ health_check_system.sh         [Priority: 🟡 MEDIUM]

POST_INSTALL/
  ├─ setup_tiered_storage.sh        [Priority: 🟡 MEDIUM]
  ├─ setup_cloud_backup.sh          [Priority: 🟡 MEDIUM]
  ├─ setup_vm_orchestration.sh      [Priority: 🟡 MEDIUM]
  ├─ setup_gpu_passthrough.sh       [Priority: 🟠 LOW]
  ├─ setup_security_hardening.sh    [Priority: 🟡 HIGH]
  └─ setup_advanced_monitoring.sh   [Priority: 🟠 LOW]

INSTALLATION/
  ├─ install_multi_os.sh            [Priority: 🟡 HIGH]
  ├─ setup_proxmox_lxc.sh          [Priority: 🟡 MEDIUM]
  ├─ setup_docker_in_docker.sh     [Priority: 🟡 MEDIUM]
  └─ setup_kvm_host.sh             [Priority: 🟠 LOW]

docs/
  ├─ STORAGE_VARIANTS.md            [Priority: 🟡 HIGH]
  ├─ MULTI_OS_GUIDE.md              [Priority: 🟡 HIGH]
  ├─ VM_DEPLOYMENT.md               [Priority: 🟡 MEDIUM]
  ├─ BACKUP_RECOVERY.md             [Priority: 🟡 HIGH]
  ├─ SECURITY_HARDENING.md          [Priority: 🟡 HIGH]
  └─ MONITORING.md                  [Priority: 🟠 LOW]

tests/
  └─ integration_tests.sh            [Priority: 🟠 LOW]
```

---

## 🔄 Roadmap do v3.0

- **v2.4.0** (Current) → Multi-OS + Storage variants + VM support
- **v2.5.0** → Cloud backup + Security hardening + Monitoring
- **v3.0.0** → Kubernetes support + Multi-RPi clustering + HA failover

---

## 📊 Metriky Úspěchu

| Metrika | Aktuální | Cíl (v2.4) | Cíl (v3.0) |
|---------|----------|-----------|-----------|
| Podporované OS | 1 (Debian) | 5 | 8+ |
| VM typů | 2 | 5 | 10 |
| Storage variant | 2 | 6 | 12 |
| Backup strategie | 1 | 3 | 5 |
| Health checks | Manuální | Automatické | Predictive |
| Security score | 6/10 | 8/10 | 9.5/10 |

---

## 🎓 Příkazy pro Start

```bash
# Kompletní audit
./scripts/system_check.sh

# Jednotlivé opravy
./scripts/fix_configuration_yaml.sh       # PRIORITY 1
./scripts/detect_os.sh                    # PRIORITY 2
./scripts/storage_config_wizard.sh        # PRIORITY 3

# Kompletní setup (vše v pořadí)
./setup_master.sh
# Vyberte: 1 (Kompletní instalace)
```

---

## ✅ Kontrolní List

- [ ] Opravit `configuration.yaml`
- [ ] Přidat OS detection
- [ ] Vytvořit storage wizard
- [ ] Přidat systemd mount units
- [ ] Implementovat backup/restore
- [ ] Přidat VM orchestraci
- [ ] Security hardening
- [ ] Dokumentace + testy

---

**Připraveno k implementaci:** 2025-11-11  
**Priorita:** 🔴 URGENT — Začít s Fází 1 IHNED  
**Odhadovaný čas:** 4-6 hodin na kompletní implementaci
