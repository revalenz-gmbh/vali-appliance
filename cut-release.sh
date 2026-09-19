#!/usr/bin/env bash
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

{
  head -n 2 CHANGELOG.md
  echo ""
  echo "## $VERSION - $STAMP"
  echo ""
  echo "$MESSAGE"
  echo ""
  tail -n +3 CHANGELOG.md
} > "$TMP_CHANGELOG"
mv "$TMP_CHANGELOG" CHANGELOG.md

git add CHANGELOG.md
git commit -m "docs: Aenderungsprotokoll fuer $VERSION"

git tag -s "$VERSION" -m "$MESSAGE"

echo "Tag $VERSION signiert erstellt. Zum Veroeffentlichen:"
echo "  git push origin main"
echo "  git push origin $VERSION"
echo "Danach auf GitHub ein Release zu diesem Tag anlegen (Aenderungsprotokoll"
echo "als Beschreibung uebernehmen) -- entweder im Web-UI oder per:"
echo "  gh release create $VERSION --title \"$VERSION\" --notes \"$MESSAGE\""
