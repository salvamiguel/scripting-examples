#!/usr/bin/env bash

archivo="${1:?Uso: $0 <archivo>}"

if [[ ! -e "$archivo" ]]; then
    echo "Error: '$archivo' no existe" >&2
    exit 1
elif [[ -d "$archivo" ]]; then
    echo "Error: '$archivo' es un directorio, no un archivo" >&2
    exit 1
elif [[ ! -r "$archivo" ]]; then
    echo "Error: '$archivo' existe pero no tienes permiso de lectura" >&2
    exit 1
elif [[ ! -s "$archivo" ]]; then
    echo "Aviso: '$archivo' existe pero esta vacio"
    exit 0
else
    lineas=$(wc -l < "$archivo")
    echo "Archivo '$archivo': $lineas lineas, legible y listo para procesar"
fi