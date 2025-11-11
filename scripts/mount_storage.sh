#!/bin/bash
# Mount external storage (USB, NAS, network drives)
set -euo pipefail

usage() {
    cat <<EOF
Usage: $0 [mount|unmount|list|auto-mount]
  mount      Mount device interactively
  unmount    Unmount device
  list       List all mount points
  auto-mount Add device to fstab for persistence
EOF
    exit 1
}

if [ $# -lt 1 ]; then usage; fi

case "$1" in
    list)
        echo "=== Mounted Storage Devices ==="
        lsblk -o NAME,SIZE,TYPE,MOUNTPOINT
        echo ""
        echo "=== /etc/fstab Entries ==="
        grep -E "^/dev|^UUID" /etc/fstab || echo "Žádné custom mounts"
        ;;
    mount)
        echo "Dostupné zařízení:"
        lsblk -dno NAME,SIZE | grep -v "^sda"
        read -p "Vyberte zařízení (např. sdb1): " device
        
        if [ ! -e "/dev/$device" ]; then
            echo "❌ Zařízení /dev/$device neexistuje"
            exit 1
        fi
        
        read -p "Cílový adresář (výchozí /mnt/storage): " mount_point
        mount_point=${mount_point:-/mnt/storage}
        
        sudo mkdir -p "$mount_point"
        sudo mount "/dev/$device" "$mount_point" || {
            echo "❌ Připojení selhalo. Zkuste určit typ filesystem:"
            read -p "Filesystem (ntfs/ext4/vfat) [auto]: " fstype
            fstype=${fstype:-auto}
            sudo mount -t "$fstype" "/dev/$device" "$mount_point"
        }
        
        echo "✅ Připojeno: /dev/$device -> $mount_point"
        ;;
    unmount)
        echo "Připojená zařízení:"
        mount | grep "/mnt"
        read -p "Odpojit (zadejte mount point): " mount_point
        sudo umount "$mount_point" && echo "✅ Odpojeno: $mount_point" || echo "❌ Odpojení selhalo"
        ;;
    auto-mount)
        echo "Dostupné zařízení:"
        lsblk -dno NAME,SIZE,UUID | grep -v "^sda"
        read -p "Vyberte UUID nebo device: " identifier
        read -p "Cílový adresář: " mount_point
        read -p "Filesystem (ext4/ntfs/vfat) [ext4]: " fstype
        fstype=${fstype:-ext4}
        
        # Přidat do fstab
        echo "UUID=$identifier  $mount_point  $fstype  defaults,nofail  0  2" | sudo tee -a /etc/fstab
        
        mkdir -p "$mount_point"
        sudo mount "$mount_point"
        echo "✅ Přidáno do fstab a připojeno"
        ;;
    *)
        usage
        ;;
esac
