#!/usr/bin/env bash
set -euo pipefail

# ==== Configuración desde variables de entorno ====
SSH_USER="${SSH_USER:-apiev4315}"
SSH_HOST="${SSH_HOST:-200.58.107.10}"
SSH_PORT="${SSH_PORT:-5829}"

# Si MySQL remoto NO escucha en 127.0.0.1:3306, cambia REMOTE_DB_HOST/PORT
REMOTE_DB_HOST="${REMOTE_DB_HOST:-127.0.0.1}"
REMOTE_DB_PORT="${REMOTE_DB_PORT:-3306}"

# Tunel local
LOCAL_HOST="${LOCAL_HOST:-127.0.0.1}"
LOCAL_PORT="${LOCAL_PORT:-11224}"

# Base de datos
DB_NAME="${DB_NAME:-api_hub}"
DB_USER="${DB_USER:-api_hub}"
DB_PASS="${DB_PASS:-OftBcwC3LD6Oiym!}"

# Salida (por defecto, directorio dumps)
OUTDIR="${OUTDIR:-/app/dumps}"
STAMP="$(date +%F_%H%M)"
OUTFILE="${OUTDIR}/${DB_NAME}_${STAMP}.sql.gz"

# Opcionales: descomenta si usas GTIDs y te da error
# EXTRA_OPTS="--set-gtid-purged=OFF"
EXTRA_OPTS=""

# Validar variables requeridas
if [[ -z "$SSH_USER" ]] || [[ -z "$SSH_HOST" ]] || [[ -z "$DB_USER" ]] || [[ -z "$DB_PASS" ]]; then
  echo "[!] Error: Variables de entorno requeridas no están configuradas:"
  echo "    SSH_USER, SSH_HOST, DB_USER, DB_PASS"
  exit 1
fi

# ==== No tocar desde aquí ====
cleanup() {
  if [[ -n "${SSH_PID:-}" ]] && kill -0 "${SSH_PID}" 2>/dev/null; then
    kill "${SSH_PID}" 2>/dev/null || true
  fi
  [[ -f "${TMP_CNF:-}" ]] && shred -u "${TMP_CNF}" || true
}
trap cleanup EXIT

echo "[*] Iniciando túnel SSH ${LOCAL_HOST}:${LOCAL_PORT} -> ${REMOTE_DB_HOST}:${REMOTE_DB_PORT} ..."
ssh -o ExitOnForwardFailure=yes \
    -o ServerAliveInterval=60 \
    -o ServerAliveCountMax=3 \
    -N -L "${LOCAL_HOST}:${LOCAL_PORT}:${REMOTE_DB_HOST}:${REMOTE_DB_PORT}" \
    -p "${SSH_PORT}" "${SSH_USER}@${SSH_HOST}" &
SSH_PID=$!

# Esperar a que el puerto local esté listo (hasta 30s)
for i in {1..30}; do
  if command -v nc >/dev/null 2>&1; then
    if nc -z "${LOCAL_HOST}" "${LOCAL_PORT}" 2>/dev/null; then break; fi
  else
    # Fallback sin nc: intentar ping con mysqladmin
    if mysqladmin --host="${LOCAL_HOST}" --port="${LOCAL_PORT}" ping >/dev/null 2>&1; then break; fi
  fi
  sleep 1
  [[ $i -eq 30 ]] && { echo "[!] No se pudo establecer el túnel a tiempo."; exit 1; }
done
echo "[*] Túnel listo (PID ${SSH_PID})."

# Defaults extra file para no exponer la contraseña en ps
TMP_CNF="$(mktemp)"
chmod 600 "${TMP_CNF}"
cat > "${TMP_CNF}" <<EOF
[client]
user=${DB_USER}
password=${DB_PASS}
host=${LOCAL_HOST}
port=${LOCAL_PORT}
EOF

echo "[*] Iniciando mysqldump de '${DB_NAME}' (comprimido)..."
# Nota: --single-transaction + --skip-lock-tables para consistencia sin bloquear (ideal InnoDB)
mysqldump --defaults-extra-file="${TMP_CNF}" \
  --skip-lock-tables \
  --single-transaction \
  --column-statistics=0 \
  --routines \
  --events \
  --add-drop-table \
  --disable-keys \
  --extended-insert \
  ${EXTRA_OPTS} \
  "${DB_NAME}" | gzip > "${OUTFILE}"

echo "[✓] Dump generado: ${OUTFILE}"