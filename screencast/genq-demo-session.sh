#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/genq-demo.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT

DEMO_HOME="$TMP_DIR/home"
NU_INCLUDE_PATHS="$ROOT_DIR/src/lib"$'\x1e'"$ROOT_DIR/src/lib/ext"
mkdir -p "$DEMO_HOME/config" "$DEMO_HOME/vault"

cat > "$DEMO_HOME/config/default.toml" <<EOF
[database]
active = "demo"

[database.connections]
demo = "$ROOT_DIR/data/pres2025.rmtree"

[paths]
sql_dir = "$ROOT_DIR/sql"
lib_dir = "$ROOT_DIR/src/lib"
ext_dir = "$ROOT_DIR/src/lib/ext"
output_dir = "$DEMO_HOME/vault"

[display]
date_format = 1
table_mode = "rounded"

[extensions]
enabled = ["miams", "pres2025"]
EOF

type_text() {
  local text="$1"
  local delay="${2:-0.018}"
  local i

  for (( i = 1; i <= ${#text}; i++ )); do
    printf '%s' "${text:$((i-1)):1}"
    sleep "$delay"
  done
  printf '\n'
}

pause() {
  sleep "${1:-1}"
}

run_genq() {
  local command="$1"

  printf '\033[1;32mgenq-demo>\033[0m '
  type_text "$command"
  nu --no-config-file -I "$NU_INCLUDE_PATHS" -c "with-env { GENQ_HOME: '$DEMO_HOME' } { source '$ROOT_DIR/src/main.nu'; $command }"
}

printf '\033[2J\033[H'
printf 'GenQuery demo against the bundled presidents database\n'
pause 1

run_genq "genq list people | first 8"
pause 1.2

run_genq "genq list presidents | select RIN Given Surname Description | first 8"
pause 1.4

run_genq "genq list people | where Surname =~ 'Adams|Roosevelt|Bush' | first 10"
pause 1.4

run_genq "genq list families | first 8"
pause 1.4

run_genq "genq list sources | select SrcID AbbrevSourceName | first 8"
pause 1.2

printf '\033[1;32mgenq-demo>\033[0m '
type_text "exit" 0.03
pause 0.5
