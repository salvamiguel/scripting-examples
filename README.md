# Bash Scripting - Repositorio de Ejemplos

Repositorio de scripts de ejemplo que acompana las unidades del curso de Bash Scripting. Cada script demuestra conceptos y patrones vistos en clase, desde fundamentos hasta integracion en pipelines CI/CD.

## Contenido

| Script | Unidad | Descripcion |
|--------|--------|-------------|
| `check_file_exists.sh` | Estructuras de Control | Validacion de archivos con condicionales, tests de archivo (`-e`, `-d`, `-r`, `-s`) y mensajes de error por stderr |
| `commands_flags.sh` | Estructuras de Control | Parseo de flags de linea de comandos con `case`, `shift` y el patron `--` para fin de opciones |
| `func_lib.sh` | Estructuras de Control | Biblioteca de funciones reutilizables: logging, validacion de IPs, operaciones con archivos y uso de `local` |
| `log_processing.sh` | Estructuras de Control | Procesamiento de logs linea por linea con `while IFS= read -r`, arrays asociativos y `declare -A` |
| `log_analyzer.sh` | Estructuras de Control | Script completo que combina condicionales, `case`, bucles, funciones, exit codes y procesamiento de archivos |
| `terraform_wrapper.sh` | Scripting en Pipelines | Wrapper para Terraform con validacion, logging con colores, manejo de errores y codigos de salida significativos |
| `kubectl_wrapper.sh` | Scripting en Pipelines | Wrapper para kubectl: dry-run, apply, verificacion de rollout y rollback automatico si falla |
| `validate.sh` | Scripting en Pipelines | Pre-flight checks antes del despliegue: herramientas, variables de entorno, YAML y deteccion de secretos hardcodeados |
| `release.sh` | Scripting en Pipelines | Automatizacion de releases: version bump (semver), generacion de changelog, creacion de tags y notificacion por Slack |

## Requisitos

- **Bash 4.0+** (recomendado 5.x). Los arrays asociativos (`declare -A`) requieren Bash 4+.
- **ShellCheck** para analisis estatico: `brew install shellcheck` (macOS) o `apt install shellcheck` (Debian/Ubuntu).

> En macOS, la version de Bash incluida es la 3.2. Instala una version moderna con `brew install bash`.

## Uso

```bash
# Dar permisos de ejecucion (si no los tiene)
chmod +x *.sh

# Ejecutar un script
./check_file_exists.sh /etc/hosts
./commands_flags.sh -v --output resultado.txt archivo.log
./log_analyzer.sh --level WARNING -v /var/log/system.log
./terraform_wrapper.sh plan -e staging -d infra/
./kubectl_wrapper.sh apply -f k8s/deployment.yaml -n production -t 180s
./validate.sh
./release.sh minor

# Analisis estatico
shellcheck *.sh
```

## Estructura por unidad

### Unidad 1 - Introduccion a Bash

Conceptos cubiertos en los scripts: shebang portable (`#!/usr/bin/env bash`), variables, quoting, parametros posicionales (`$1`, `$@`, `$#`), sustitucion de comandos y arrays.

### Unidad 2 - Estructuras de Control y Funciones

- **`check_file_exists.sh`** — Condicionales con `[[ ]]`, tests de archivo, mensajes a stderr con `>&2`.
- **`commands_flags.sh`** — Sentencia `case` para parseo de flags, bucle `while` con `shift`.
- **`func_lib.sh`** — Funciones con `local`, `return` vs `echo`, validacion de IPs con regex.
- **`log_processing.sh`** — Lectura de archivos con `while IFS= read -r`, arrays asociativos.
- **`log_analyzer.sh`** — Script completo que integra todos los conceptos de la unidad.

### Unidad 3 - Pipes y Herramientas de Texto

Conceptos aplicados en los scripts: redireccion (`>`, `>>`, `2>&1`), pipes (`|`), y herramientas como `grep`, `sed`, `awk` y `jq`.

### Unidad 4 - Automatizacion y Manejo de Errores

Patrones presentes en los scripts:

- `set -euo pipefail` como primera linea despues del shebang.
- `trap cleanup EXIT` para limpieza garantizada de recursos temporales.
- Funciones de logging con timestamps y niveles de severidad.
- Codigos de salida significativos (0 = exito, 2 = formato, 3 = init, etc.).

### Unidad 5 - Scripting en Pipelines CI/CD

- **`terraform_wrapper.sh`** — Wrapper completo: fmt check, init, validate, plan/apply con logging estructurado, colores y codigos de salida diferenciados.
- **`kubectl_wrapper.sh`** — Despliegue seguro en Kubernetes: validacion con dry-run, apply, verificacion de rollout con timeout y rollback automatico ante fallos.
- **`validate.sh`** — Pre-flight checks: verifica herramientas requeridas, variables de entorno, sintaxis YAML y busca secretos hardcodeados en el codigo.
- **`release.sh`** — Automatizacion de releases con Semantic Versioning: calcula la nueva version, genera changelog desde git log, crea tag y notifica por Slack.

## Convenciones

Todos los scripts siguen estas practicas:

```bash
#!/usr/bin/env bash          # Shebang portable
set -euo pipefail            # Modo estricto de errores
```

- Variables siempre entrecomilladas: `"$variable"`
- Variables dentro de funciones declaradas con `local`
- Mensajes de error enviados a stderr (`>&2`)
- Codigos de salida consistentes: `0` exito, `1` error general, `2` uso incorrecto

## Recursos

- [ShellCheck](https://www.shellcheck.net/) — Analisis estatico para scripts Bash
- [bats-core](https://github.com/bats-core/bats-core) — Framework de testing para Bash
- [GNU Bash Manual](https://www.gnu.org/software/bash/manual/) — Referencia oficial
