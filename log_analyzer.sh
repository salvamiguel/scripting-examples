#!/usr/bin/env bash
#
# log_analyzer.sh - Analizador de archivos de log
#
# Uso: log_analyzer.sh [opciones] <archivo_log> [archivo_log2 ...]
#
# Opciones:
#   -h, --help          Muestra esta ayuda
#   -v, --verbose       Modo detallado
#   -l, --level NIVEL   Filtrar por nivel minimo (INFO, WARNING, ERROR, CRITICAL)
#   -o, --output FILE   Escribir resumen en archivo
#   --version           Muestra la version
#
# Ejemplo:
#   log_analyzer.sh --level WARNING -v /var/log/app.log

set -euo pipefail

# =============================================
# Constantes
# =============================================

readonly VERSION="1.2.0"
readonly SCRIPT_NAME="$(basename "$0")"

readonly EXIT_OK=0
readonly EXIT_ERROR=1
readonly EXIT_USO=2

# Niveles de severidad (orden de menor a mayor)
readonly -a NIVELES=(INFO WARNING ERROR CRITICAL)

# =============================================
# Funciones de utilidad
# =============================================

mostrar_ayuda() {
    cat <<EOF
Uso: $SCRIPT_NAME [opciones] <archivo_log> [archivo_log2 ...]

Analiza archivos de log y genera un resumen por nivel de severidad.

Opciones:
  -h, --help          Muestra esta ayuda
  -v, --verbose       Modo detallado
  -l, --level NIVEL   Filtrar por nivel minimo (INFO, WARNING, ERROR, CRITICAL)
  -o, --output FILE   Escribir resumen en archivo
  --version           Muestra la version

Niveles (de menor a mayor severidad):
  INFO < WARNING < ERROR < CRITICAL

Ejemplos:
  $SCRIPT_NAME /var/log/app.log
  $SCRIPT_NAME --level WARNING -v /var/log/*.log
  $SCRIPT_NAME -o resumen.txt /var/log/app.log
EOF
}

log_msg() {
    local nivel="$1"
    shift
    if [[ "$verbose" == true ]]; then
        echo "[$nivel] $*" >&2
    fi
}

# =============================================
# Funciones de validacion
# =============================================

nivel_es_valido() {
    local nivel_buscado="$1"
    local n
    for n in "${NIVELES[@]}"; do
        if [[ "$n" == "$nivel_buscado" ]]; then
            return 0
        fi
    done
    return 1
}

obtener_indice_nivel() {
    local nivel_buscado="$1"
    local i
    for i in "${!NIVELES[@]}"; do
        if [[ "${NIVELES[$i]}" == "$nivel_buscado" ]]; then
            echo "$i"
            return 0
        fi
    done
    echo "-1"
    return 1
}

validar_archivo() {
    local archivo="$1"

    if [[ ! -e "$archivo" ]]; then
        echo "Error: '$archivo' no existe" >&2
        return 1
    elif [[ -d "$archivo" ]]; then
        echo "Error: '$archivo' es un directorio" >&2
        return 1
    elif [[ ! -r "$archivo" ]]; then
        echo "Error: sin permiso de lectura en '$archivo'" >&2
        return 1
    elif [[ ! -s "$archivo" ]]; then
        echo "Aviso: '$archivo' esta vacio, se omite" >&2
        return 1
    fi
    return 0
}

# =============================================
# Funcion principal de analisis
# =============================================

analizar_archivo() {
    local archivo="$1"
    local nivel_minimo_idx="$2"
    local lineas_total=0
    local lineas_filtradas=0

    # Contadores por nivel (array asociativo local)
    local -A contadores
    local n
    for n in "${NIVELES[@]}"; do
        contadores[$n]=0
    done

    log_msg "INFO" "Analizando: $archivo"

    # Leer el archivo linea por linea
    while IFS= read -r linea; do
        ((lineas_total++))

        # Comprobar cada nivel de severidad (de mayor a menor)
        local i
        for ((i = ${#NIVELES[@]} - 1; i >= 0; i--)); do
            local nivel="${NIVELES[$i]}"
            if [[ "$linea" == *"$nivel"* ]]; then
                ((contadores[$nivel]++))

                # Solo contar si supera el nivel minimo
                if ((i >= nivel_minimo_idx)); then
                    ((lineas_filtradas++))
                fi
                break
            fi
        done
    done < "$archivo"

    # Generar salida
    local salida=""
    salida+="--- $archivo ---\n"
    salida+="Lineas totales: $lineas_total\n"
    salida+="Lineas que superan nivel ${NIVELES[$nivel_minimo_idx]}: $lineas_filtradas\n"
    salida+="\n"

    for n in "${NIVELES[@]}"; do
        local idx
        idx=$(obtener_indice_nivel "$n")
        local marca=""
        if ((idx < nivel_minimo_idx)); then
            marca=" (filtrado)"
        fi
        printf -v linea_formato "  %-12s %5d%s\n" "$n" "${contadores[$n]}" "$marca"
        salida+="$linea_formato"
    done

    echo -e "$salida"
}

# =============================================
# Parseo de argumentos
# =============================================

# Valores por defecto
verbose=false
nivel_filtro="INFO"
archivo_salida=""
archivos_log=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h | --help)
            mostrar_ayuda
            exit $EXIT_OK
            ;;
        --version)
            echo "$SCRIPT_NAME v$VERSION"
            exit $EXIT_OK
            ;;
        -v | --verbose)
            verbose=true
            shift
            ;;
        -l | --level)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --level requiere un argumento" >&2
                exit $EXIT_USO
            fi
            nivel_filtro="${2^^}"  # Convertir a mayusculas
            if ! nivel_es_valido "$nivel_filtro"; then
                echo "Error: nivel '$nivel_filtro' no valido. Usa: ${NIVELES[*]}" >&2
                exit $EXIT_USO
            fi
            shift 2
            ;;
        -o | --output)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --output requiere un argumento" >&2
                exit $EXIT_USO
            fi
            archivo_salida="$2"
            shift 2
            ;;
        --)
            shift
            archivos_log+=("$@")
            break
            ;;
        -*)
            echo "Error: opcion desconocida '$1'" >&2
            echo "Usa '$SCRIPT_NAME --help' para ver las opciones disponibles" >&2
            exit $EXIT_USO
            ;;
        *)
            archivos_log+=("$1")
            shift
            ;;
    esac
done

# =============================================
# Validaciones previas
# =============================================

if [[ ${#archivos_log[@]} -eq 0 ]]; then
    echo "Error: debes especificar al menos un archivo de log" >&2
    echo "Usa '$SCRIPT_NAME --help' para ver el modo de uso" >&2
    exit $EXIT_USO
fi

nivel_minimo_idx=$(obtener_indice_nivel "$nivel_filtro")
log_msg "INFO" "Nivel minimo de filtro: $nivel_filtro (indice $nivel_minimo_idx)"

# =============================================
# Procesamiento
# =============================================

resultados=""
archivos_procesados=0
archivos_con_error=0

for archivo in "${archivos_log[@]}"; do
    if ! validar_archivo "$archivo"; then
        ((archivos_con_error++))
        continue
    fi

    resultado=$(analizar_archivo "$archivo" "$nivel_minimo_idx")
    resultados+="$resultado\n\n"
    ((archivos_procesados++))
done

# =============================================
# Salida
# =============================================

resumen="============================\n"
resumen+="  RESUMEN DEL ANALISIS\n"
resumen+="============================\n"
resumen+="Archivos procesados: $archivos_procesados\n"
resumen+="Archivos con error:  $archivos_con_error\n"
resumen+="Nivel de filtro:     $nivel_filtro\n"
resumen+="============================\n\n"
resumen+="$resultados"

if [[ -n "$archivo_salida" ]]; then
    echo -e "$resumen" > "$archivo_salida"
    log_msg "INFO" "Resumen escrito en: $archivo_salida"
    echo "Resumen guardado en: $archivo_salida"
else
    echo -e "$resumen"
fi

# Exit code basado en resultado
if [[ $archivos_con_error -gt 0 && $archivos_procesados -eq 0 ]]; then
    exit $EXIT_ERROR
fi

exit $EXIT_OK