#!/usr/bin/env bash
# Analiza un archivo de log y genera un resumen por nivel de severidad

log_file="${1:?Uso: $0 <archivo_log>}"

if [[ ! -f "$log_file" ]]; then
    echo "Error: '$log_file' no es un archivo valido" >&2
    exit 1
fi

declare -A contadores
contadores[INFO]=0
contadores[WARNING]=0
contadores[ERROR]=0
contadores[CRITICAL]=0
lineas_total=0

while IFS= read -r linea; do
    ((lineas_total++))

    for nivel in CRITICAL ERROR WARNING INFO; do
        if [[ "$linea" == *"$nivel"* ]]; then
            ((contadores[$nivel]++))
            break  # Una linea solo cuenta una vez, con la severidad mas alta
        fi
    done
done < "$log_file"

echo "=== Resumen de $log_file ==="
echo "Total de lineas: $lineas_total"
echo ""
for nivel in CRITICAL ERROR WARNING INFO; do
    printf "  %-10s %d\n" "$nivel" "${contadores[$nivel]}"
done