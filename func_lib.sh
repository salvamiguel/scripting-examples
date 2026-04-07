#!/usr/bin/env bash
# func_lib.sh - Biblioteca de funciones reutilizables

# --- Logging ---

log() {
    local nivel="$1"
    shift
    local mensaje="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$nivel] $mensaje" >&2
}

log_info()    { log "INFO"    "$@"; }
log_warn()    { log "WARNING" "$@"; }
log_error()   { log "ERROR"   "$@"; }

# --- Validacion ---

es_numero_entero() {
    local valor="$1"
    [[ "$valor" =~ ^-?[0-9]+$ ]]
}

es_ip_valida() {
    local ip="$1"
    local regex='^([0-9]{1,3}\.){3}[0-9]{1,3}$'

    if [[ ! "$ip" =~ $regex ]]; then
        return 1
    fi

    local IFS='.'
    read -ra octetos <<< "$ip"
    for octeto in "${octetos[@]}"; do
        if (( octeto < 0 || octeto > 255 )); then
            return 1
        fi
    done
    return 0
}

# --- Archivos ---

archivo_existe_y_legible() {
    local ruta="$1"
    [[ -f "$ruta" && -r "$ruta" ]]
}

tamano_archivo_legible() {
    local ruta="$1"
    if [[ ! -f "$ruta" ]]; then
        echo "0B"
        return 1
    fi

    local bytes
    bytes=$(stat -f%z "$ruta" 2>/dev/null || stat -c%s "$ruta" 2>/dev/null)

    if (( bytes < 1024 )); then
        echo "${bytes}B"
    elif (( bytes < 1048576 )); then
        echo "$(( bytes / 1024 ))KB"
    elif (( bytes < 1073741824 )); then
        echo "$(( bytes / 1048576 ))MB"
    else
        echo "$(( bytes / 1073741824 ))GB"
    fi
}

# --- Uso ---
# source func_lib.sh
# log_info "Proceso iniciado"
# es_ip_valida "192.168.1.1" && echo "IP valida"
# tamano=$(tamano_archivo_legible "/var/log/syslog")