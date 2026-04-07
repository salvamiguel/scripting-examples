#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Automatizacion de releases: changelog -> version bump -> tag -> notificar
# Uso: ./release.sh [major|minor|patch]
# =============================================================================

BUMP_TYPE="${1:-patch}"

log_info() { echo "[INFO] $*"; }
log_success() { echo "[OK]   $*"; }

# --- 1. Obtener version actual ---
CURRENT_VERSION=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
CURRENT_VERSION="${CURRENT_VERSION#v}"  # Quitar el prefijo 'v'

IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

# --- 2. Calcular nueva version (Semantic Versioning) ---
case "$BUMP_TYPE" in
    major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
    minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
    patch) PATCH=$((PATCH + 1)) ;;
    *)     echo "Uso: $0 [major|minor|patch]"; exit 1 ;;
esac

NEW_VERSION="v${MAJOR}.${MINOR}.${PATCH}"
log_info "Version actual: v$CURRENT_VERSION -> Nueva version: $NEW_VERSION"

# --- 3. Generar changelog desde el ultimo tag ---
log_info "Generando changelog..."

CHANGELOG=$(git log "v${CURRENT_VERSION}..HEAD" --pretty=format:"- %s (%h)" --no-merges 2>/dev/null || echo "- Release inicial")

CHANGELOG_ENTRY="## ${NEW_VERSION} ($(date +%Y-%m-%d))

${CHANGELOG}
"

# Prepend al archivo CHANGELOG.md
if [ -f CHANGELOG.md ]; then
    echo -e "${CHANGELOG_ENTRY}\n$(cat CHANGELOG.md)" > CHANGELOG.md
else
    echo "$CHANGELOG_ENTRY" > CHANGELOG.md
fi

log_success "Changelog actualizado"

# --- 4. Crear commit y tag ---
git add CHANGELOG.md
git commit -m "release: ${NEW_VERSION}"
git tag -a "$NEW_VERSION" -m "Release ${NEW_VERSION}"

log_success "Tag creado: $NEW_VERSION"

# --- 5. Notificar (Slack webhook) ---
if [ -n "${SLACK_WEBHOOK:-}" ]; then
    log_info "Enviando notificacion a Slack..."
    PAYLOAD=$(jq -n \
        --arg version "$NEW_VERSION" \
        --arg changes "$CHANGELOG" \
        '{text: ("Nueva release: " + $version + "\n" + $changes)}')

    curl -s -X POST "$SLACK_WEBHOOK" \
         -H "Content-Type: application/json" \
         -d "$PAYLOAD" > /dev/null

    log_success "Notificacion enviada"
else
    log_info "SLACK_WEBHOOK no configurado. Omitiendo notificacion."
fi

echo ""
log_success "Release $NEW_VERSION completada"
echo "Ejecuta 'git push && git push --tags' para publicar."