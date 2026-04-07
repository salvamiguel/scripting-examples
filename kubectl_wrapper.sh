#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Wrapper para kubectl: validar -> apply -> verificar rollout -> rollback si falla
# Uso: ./kubectl_wrapper.sh <apply|rollback> -f <manifest> [-n namespace]
# =============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]  $(date '+%Y-%m-%d %H:%M:%S')${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]    $(date '+%Y-%m-%d %H:%M:%S')${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]  $(date '+%Y-%m-%d %H:%M:%S')${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR] $(date '+%Y-%m-%d %H:%M:%S')${NC} $*" >&2; }

ACTION=""
MANIFEST=""
NAMESPACE="default"
TIMEOUT="120s"

usage() {
    echo "Uso: $0 <apply|rollback> -f <manifest.yaml> [-n namespace] [-t timeout]"
    exit 1
}

if [ $# -lt 1 ]; then usage; fi
ACTION="$1"; shift

while [[ $# -gt 0 ]]; do
    case "$1" in
        -f|--file)      MANIFEST="$2"; shift 2 ;;
        -n|--namespace) NAMESPACE="$2"; shift 2 ;;
        -t|--timeout)   TIMEOUT="$2"; shift 2 ;;
        *) log_error "Argumento desconocido: $1"; usage ;;
    esac
done

# --- Validaciones previas ---
if [ -z "$MANIFEST" ]; then
    log_error "Debes especificar un manifiesto con -f"
    exit 1
fi

if [ ! -f "$MANIFEST" ]; then
    log_error "Archivo no encontrado: $MANIFEST"
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    log_error "kubectl no esta instalado"
    exit 1
fi

# --- Funciones ---
validate_manifest() {
    log_info "Validando manifiesto con dry-run..."
    if kubectl apply --dry-run=client -f "$MANIFEST" -n "$NAMESPACE" > /dev/null 2>&1; then
        log_success "Manifiesto valido"
        return 0
    else
        log_error "Manifiesto invalido:"
        kubectl apply --dry-run=client -f "$MANIFEST" -n "$NAMESPACE"
        return 1
    fi
}

get_deployment_name() {
    # Extrae el nombre del Deployment del manifiesto
    kubectl apply --dry-run=client -f "$MANIFEST" -n "$NAMESPACE" -o jsonpath='{.metadata.name}' 2>/dev/null
}

wait_for_rollout() {
    local deployment="$1"
    log_info "Esperando rollout de $deployment (timeout: $TIMEOUT)..."
    if kubectl rollout status "deployment/$deployment" -n "$NAMESPACE" --timeout="$TIMEOUT"; then
        log_success "Rollout completado: $deployment"
        return 0
    else
        log_error "Rollout fallido o timeout alcanzado para $deployment"
        return 1
    fi
}

rollback_deployment() {
    local deployment="$1"
    log_warn "Ejecutando rollback de $deployment..."
    if kubectl rollout undo "deployment/$deployment" -n "$NAMESPACE"; then
        log_success "Rollback completado: $deployment"
        wait_for_rollout "$deployment"
    else
        log_error "Fallo en el rollback de $deployment"
        exit 1
    fi
}

# --- Ejecucion ---
case "$ACTION" in
    apply)
        validate_manifest

        DEPLOYMENT_NAME=$(get_deployment_name)
        log_info "Aplicando manifiesto: $MANIFEST (namespace: $NAMESPACE)"

        kubectl apply -f "$MANIFEST" -n "$NAMESPACE"

        if [ -n "$DEPLOYMENT_NAME" ]; then
            if ! wait_for_rollout "$DEPLOYMENT_NAME"; then
                log_error "Despliegue fallido. Iniciando rollback automatico..."
                rollback_deployment "$DEPLOYMENT_NAME"
                exit 1
            fi
        fi

        log_success "Despliegue completado exitosamente"
        ;;
    rollback)
        DEPLOYMENT_NAME=$(get_deployment_name)
        if [ -z "$DEPLOYMENT_NAME" ]; then
            log_error "No se pudo determinar el nombre del deployment"
            exit 1
        fi
        rollback_deployment "$DEPLOYMENT_NAME"
        ;;
    *)
        log_error "Accion invalida: $ACTION"
        usage
        ;;
esac