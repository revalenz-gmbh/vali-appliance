#!/bin/bash
# Wird von kiosk.service unter dem Benutzer "kiosk" gestartet: wartet auf die buero-VM, dann Browser im Vollbild.
until curl -sk -o /dev/null --max-time 3 https://cloud.buero.intern/status.php; do sleep 3; done
udiskie --automount --no-notify --no-tray >/dev/null 2>&1 &
exec chromium --kiosk --ozone-platform=wayland --no-first-run --noerrdialogs --disable-infobars \
  --lang=de --accept-lang=de-DE,de --password-store=basic --disable-features=Translate --disk-cache-dir=/tmp/kiosk-cache \
  https://start.buero.intern/
