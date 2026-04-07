#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Pre-deploy validation: verifica que todo esta listo antes del despliegue
# Uso: ./validate.sh [-e environment] [-c config.yaml]
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

check_pass() { echo -e "  ${GREEN}[PASS]${NC} $*"; }
check_fail() { echo -e "  ${RED}[FAIL]${NC} $*"; ERRORS=$((ERRORS + 1)); }
check_warn() { echo -e "  ${YELLOW}[WARN]${NC} $*"; WARNINGS=$((WARNINGS + 1)); }

echo "========================================"
echo " Pre-deploy Validation"
echo "========================================"
echo ""

# --- 1. Herramientas requeridas ---
echo "1. Verificando herramientas requeridas..."

REQUIRED_TOOLS=("terraform" "kubectl" "jq" "curl" "git")
for tool in "${REQUIRED_TOOLS[@]}"; do
    if command -v "$tool" &> /dev/null; then
        VERSION=$($tool --version 2>/dev/null | head -1 || echo "version desconocida")
        check_pass "$tool encontrado ($VERSION)"
    else
        check_fail "$tool no encontrado en el PATH"
    fi
done

echo ""

# --- 2. Variables de entorno requeridas ---
echo "2. Verificando variables de entorno..."

REQUIRED_VARS=("AWS_ACCESS_KEY_ID" "AWS_SECRET_ACCESS_KEY" "AWS_DEFAULT_REGION")
for var in "${REQUIRED_VARS[@]}"; do
    if [ -n "${!var:-}" ]; then
        # Mostrar solo los primeros 4 caracteres por seguridad
        VALUE="${!var}"
        MASKED="${VALUE:0:4}****"
        check_pass "$var configurada ($MASKED)"
    else
        check_fail "$var no esta definida"
    fi
done

echo ""

# --- 3. Validar sintaxis YAML ---
echo "3. Verificando archivos de configuracion..."

if [ -d "k8s/" ]; then
    for file in k8s/*.yaml k8s/*.yml; do
        [ -f "$file" ] || continue
        if python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
            check_pass "Sintaxis YAML valida: $file"
        else
            check_fail "Sintaxis YAML invalida: $file"
        fi
    done
fi

echo ""

# --- 4. Buscar secretos hardcodeados ---
echo "4. Buscando secretos hardcodeados..."

PATTERNS=(
    "password\s*[:=]\s*['\"][^'\"]+['\"]"
    "secret\s*[:=]\s*['\"][^'\"]+['\"]"
    "api[_-]?key\s*[:=]\s*['\"][^'\"]+['\"]"
    "AKIA[0-9A-Z]{16}"    # AWS Access Key ID
)

for pattern in "${PATTERNS[@]}"; do
    MATCHES=$(grep -rn -E "$pattern" --include="*.yaml" --include="*.yml" \
              --include="*.tf" --include="*.sh" . 2>/dev/null | \
              grep -v ".git/" | grep -v "node_modules/" || true)
    if [ -n "$MATCHES" ]; then
        check_fail "Posible secreto hardcodeado encontrado:"
        echo "$MATCHES" | head -5 | sed 's/^/         /'
    fi
done

if [ "$ERRORS" -eq 0 ]; then
    check_pass "No se encontraron secretos hardcodeados"
fi

echo ""

# --- 5. Verificar conexion ---
echo "5. Verificando conectividad..."

if curl -s --max-time 5 "https://registry.terraform.io/" > /dev/null 2>&1; then
    check_pass "Terraform Registry accesible"
else
    check_warn "No se puede acceder a Terraform Registry"
fi

echo ""

# --- Resumen ---
echo "========================================"
if [ "$ERRORS" -gt 0 ]; then
    echo -e " ${RED}RESULTADO: $ERRORS errores, $WARNINGS advertencias${NC}"
    echo " El despliegue NO debe continuar."
    echo "========================================"
    exit 1
else
    echo -e " ${GREEN}RESULTADO: 0 errores, $WARNINGS advertencias${NC}"
    echo " Validacion completada. El despliegue puede continuar."
    echo "========================================"
    exit 0
fi