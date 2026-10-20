#!/bin/bash
# Legt VM 101 "buero" (Nextcloud, Open WebUI, Eingang) auf dem Proxmox-Host an. Idempotent.
# Aufruf auf dem Host als root: bash vm-buero-anlegen.sh /root/ct130.pub
set -euo pipefail
. "$(dirname "$0")/umgebung.sh"
VMID=101
PUBKEY=${1:?Pfad zum oeffentlichen SSH-Schluessel angeben}
IMG=/var/lib/vz/template/iso/noble-cloudimg.img

if qm status "$VMID" >/dev/null 2>&1; then
  echo "VM $VMID existiert bereits, nichts zu tun"
  exit 0
fi

qm create "$VMID" --name buero --machine q35 --bios ovmf --cpu host --cores 4 \
  --memory 7168 --balloon 0 --ostype l26 --scsihw virtio-scsi-single \
  --net0 virtio,bridge=vmbr0 \
  --net1 virtio=BC:24:11:77:00:02,bridge=vmbr1 \
  --agent enabled=1 --serial0 socket --vga std --onboot 1 \
  --efidisk0 local-lvm:1,efitype=4m,pre-enrolled-keys=0
qm importdisk "$VMID" "$IMG" local-lvm >/dev/null
qm set "$VMID" --scsi0 "local-lvm:vm-${VMID}-disk-1,discard=on,ssd=1,iothread=1" --boot order=scsi0
qm resize "$VMID" scsi0 80G
qm set "$VMID" --ide2 local-lvm:cloudinit --ciuser vali --sshkeys "$PUBKEY" \
  --ipconfig0 ip=dhcp --ipconfig1 ip=10.77.0.2/24 --nameserver "${NAMESERVER:?NAMESERVER setzen (DNS-Server des Buero-Netzes)}"
qm start "$VMID"
