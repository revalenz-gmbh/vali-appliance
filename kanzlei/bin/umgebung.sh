# Wird von den Skripten eingebunden. Adressen der eigenen Installation setzen, z. B. in ~/.kanzlei-umgebung oder per export.
[ -f "$HOME/.kanzlei-umgebung" ] && . "$HOME/.kanzlei-umgebung"
: "${PVE_HOST:?PVE_HOST setzen (Adresse des Proxmox-Hosts, z. B. 192.0.2.10)}"
: "${VALI_GPU_HOST:?VALI_GPU_HOST setzen (Adresse der VM vali-gpu im Buero-Netz)}"
