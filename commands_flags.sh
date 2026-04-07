#!/usr/bin/env bash

verbose=false
output_file=""
dry_run=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h | --help)
            echo "Uso: $(basename "$0") [opciones] <archivo>"
            echo ""
            echo "Opciones:"
            echo "  -h, --help       Muestra esta ayuda"
            echo "  -v, --verbose    Modo detallado"
            echo "  -o, --output     Archivo de salida"
            echo "  -n, --dry-run    Simular sin ejecutar"
            echo "  --version        Muestra la version"
            exit 0
            ;;
        -v | --verbose)
            verbose=true
            shift
            ;;
        -o | --output)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --output requiere un argumento" >&2
                exit 1
            fi
            output_file="$2"
            shift 2
            ;;
        -n | --dry-run)
            dry_run=true
            shift
            ;;
        --version)
            echo "v1.0.0"
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -*)
            echo "Error: opcion desconocida '$1'" >&2
            exit 2
            ;;
        *)
            break
            ;;
    esac
done

$verbose && echo "Modo verbose activado"
$dry_run && echo "Modo dry-run: no se ejecutaran cambios"
[[ -n "$output_file" ]] && echo "Salida: $output_file"
echo "Argumentos restantes: $*"