#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Wrapper para Terraform: fmt check -> validate -> plan -> apply
# Uso: ./terraform_wrapper.sh <action> [options]
#   action: plan | apply | destroy
#   options:
#     -e, --environment   Entorno (staging, production)
#     -d, --directory     Directorio de configuración Terraform
#     -a, --auto-approve  Aplicar sin confirmación (solo para CI)
# =============================================================================

# --- Colores y logging ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info()    { echo -e "${BLUE}[INFO]  $(date '+%Y-%m-%d %H:%M:%S')${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]    $(date '+%Y-%m-%d %H:%M:%S')${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]  $(date '+%Y-%m-%d %H:%M:%S')${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR] $(date '+%Y-%m-%d %H:%M:%S')${NC} $*" >&2; }

# --- Valores por defecto ---
ACTION=""
ENVIRONMENT="staging"
TF_DIR="."
AUTO_APPROVE=false

# --- Parseo de argumentos ---
usage() {
    echo "Uso: $0 <plan|apply|destroy> [-e environment] [-d directory] [-a]"
    exit 1
}

if [ $# -lt 1 ]; then
    usage
fi

ACTION="$1"
shift

while [[ $# -gt 0 ]]; do
    case "$1" in
        -e|--environment) ENVIRONMENT="$2"; shift 2 ;;
        -d|--directory)   TF_DIR="$2"; shift 2 ;;
        -a|--auto-approve) AUTO_APPROVE=true; shift ;;
        *) log_error "Argumento desconocido: $1"; usage ;;
    esac
done

# --- Validacion de argumentos ---
if [[ ! "$ACTION" =~ ^(plan|apply|destroy)$ ]]; then
    log_error "Accion invalida: $ACTION. Usa plan, apply o destroy."
    exit 1
fi

if [ ! -d "$TF_DIR" ]; then
    log_error "Directorio no encontrado: $TF_DIR"
    exit 1
fi

cd "$TF_DIR"

# --- Verificar que Terraform esta instalado ---
if ! command -v terraform &> /dev/null; then
    log_error "Terraform no esta instalado o no esta en el PATH"
    exit 1
fi

TF_VERSION=$(terraform version -json | jq -r '.terraform_version')
log_info "Terraform version: $TF_VERSION"
log_info "Accion: $ACTION | Entorno: $ENVIRONMENT | Directorio: $TF_DIR"

# --- Paso 1: Verificar formato ---
log_info "Paso 1/4: Verificando formato (terraform fmt -check)..."
if terraform fmt -check -recursive > /dev/null 2>&1; then
    log_success "Formato correcto"
else
    log_error "Hay archivos sin formatear. Ejecuta 'terraform fmt -recursive' localmente."
    terraform fmt -check -recursive -diff
    exit 2
fi

# --- Paso 2: Inicializar ---
log_info "Paso 2/4: Inicializando (terraform init)..."
if ! terraform init -input=false -no-color; then
    log_error "Fallo en terraform init"
    exit 3
fi
log_success "Inicializacion completada"

# --- Paso 3: Validar ---
log_info "Paso 3/4: Validando configuracion (terraform validate)..."
if ! terraform validate -no-color; then
    log_error "Fallo en terraform validate"
    exit 4
fi
log_success "Configuracion valida"

# --- Paso 4: Ejecutar la accion ---
PLAN_FILE="tfplan-${ENVIRONMENT}-$(date +%Y%m%d%H%M%S)"

case "$ACTION" in
    plan)
        log_info "Paso 4/4: Generando plan (terraform plan)..."
        if terraform plan -out="$PLAN_FILE" -no-color -input=false; then
            log_success "Plan generado: $PLAN_FILE"
            log_info "Para aplicar: $0 apply -e $ENVIRONMENT -d $TF_DIR"
        else
            log_error "Fallo en terraform plan"
            exit 5
        fi
        ;;
    apply)
        log_info "Paso 4/4: Aplicando cambios (terraform apply)..."
        # Buscar el plan mas reciente para este entorno.
        # Si no hay ninguno, ls falla y con pipefail el script terminaria aqui: || true lo evita.
        # shellcheck disable=SC2012  # los nombres de plan los genera este script, sin espacios
        LATEST_PLAN=$(ls -t tfplan-"${ENVIRONMENT}"-* 2>/dev/null | head -1 || true)
        if [ -n "$LATEST_PLAN" ]; then
            log_info "Usando plan existente: $LATEST_PLAN"
            if [ "$AUTO_APPROVE" = true ]; then
                terraform apply -no-color -input=false "$LATEST_PLAN"
            else
                terraform apply "$LATEST_PLAN"
            fi
        else
            log_warn "No se encontro plan previo. Generando plan y aplicando..."
            if [ "$AUTO_APPROVE" = true ]; then
                terraform apply -auto-approve -no-color -input=false
            else
                terraform apply
            fi
        fi
        log_success "Apply completado"
        ;;
    destroy)
        log_warn "ATENCION: Se van a destruir recursos en $ENVIRONMENT"
        if [ "$AUTO_APPROVE" = true ]; then
            terraform destroy -auto-approve -no-color -input=false
        else
            terraform destroy
        fi
        log_success "Destroy completado"
        ;;
esac

log_success "Wrapper finalizado correctamente (accion: $ACTION, entorno: $ENVIRONMENT)"
exit 0