#!/usr/bin/env bash
# Nur fuer den Maintainer (revalenz), NICHT fuer den IT-Dienstleister der
# Kunden -- siehe UPDATE-RUNBOOK.md fuer den Update-Workflow beim Kunden.
# Die Signierlogik hier wird in der Entwicklung nur gegen Wegwerf-Schluessel
# und isolierte Repo-Kopien getestet, niemals gegen das echte Repo.
set -euo pipefail
HIER="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  echo "Usage: $0 <version, z.B. v0.1.0> <changelog-nachricht>" >&2
  exit 2
}

[ $# -ge 2 ] || usage
VERSION="$1"
shift
MESSAGE="$*"

[[ "$VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
  echo "Version muss dem Muster vX.Y.Z entsprechen, bekommen: $VERSION" >&2
  exit 2
}

cd "$HIER"

[ -z "$(git status --porcelain)" ] || {
  echo "Arbeitsverzeichnis nicht sauber -- erst committen oder verwerfen." >&2
  git status --short >&2
  exit 2
}

git rev-parse "$VERSION" >/dev/null 2>&1 && {
  echo "Tag $VERSION existiert bereits." >&2
  exit 2
}

STAMP=$(date +%Y-%m-%d)
TMP_CHANGELOG=$(mktemp)
trap 'rm -f "$TMP_CHANGELOG"' EXIT

# Neuer Eintrag kommt direkt NACH dem einleitenden Text und VOR den
# bisherigen Release-Eintraegen -- nicht ans Ende. Sonst wandert die
# Einleitung von CHANGELOG.md mit jedem Release weiter nach unten.
ERSTE_UEBERSCHRIFT=$(grep -n '^## ' CHANGELOG.md | head -n 1 | cut -d: -f1 || true)

if [ -n "$ERSTE_UEBERSCHRIFT" ]; then
  {
    head -n "$((ERSTE_UEBERSCHRIFT - 1))" CHANGELOG.md
    echo "## $VERSION - $STAMP"
    echo ""
    echo "$MESSAGE"
    echo ""
    tail -n "+$ERSTE_UEBERSCHRIFT" CHANGELOG.md
  } > "$TMP_CHANGELOG"
else
  # Erstes Release ueberhaupt -- noch keine "## "-Ueberschrift vorhanden.
  {
    cat CHANGELOG.md
    echo ""
    echo "## $VERSION - $STAMP"
    echo ""
    echo "$MESSAGE"
  } > "$TMP_CHANGELOG"
fi
mv "$TMP_CHANGELOG" CHANGELOG.md

git add CHANGELOG.md
git commit -m "docs: Aenderungsprotokoll fuer $VERSION"

git tag -s "$VERSION" -m "$MESSAGE"

ERWARTETER_FINGERPRINT="5F6E6D907617F8991135D1847B1C6E1640801E3F"
if ! git verify-tag --raw "$VERSION" 2>&1 | grep -q "VALIDSIG $ERWARTETER_FINGERPRINT"; then
  echo "FEHLER: Tag $VERSION wurde NICHT mit dem veroeffentlichten Schluessel ($ERWARTETER_FINGERPRINT) signiert." >&2
  echo "Tatsaechlich signiert mit einem anderen/keinem passenden Schluessel -- Tag wird geloescht." >&2
  git tag -d "$VERSION"
  exit 2
fi

echo "Tag $VERSION signiert erstellt. Zum Veroeffentlichen:"
echo "  git push origin main"
echo "  git push origin $VERSION"
echo "Danach auf GitHub ein Release zu diesem Tag anlegen (Aenderungsprotokoll"
echo "als Beschreibung uebernehmen) -- entweder im Web-UI oder per:"
echo "  gh release create $VERSION --title \"$VERSION\" --notes \"$MESSAGE\""
