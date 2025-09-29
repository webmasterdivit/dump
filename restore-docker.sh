#!/usr/bin/env bash
set -euo pipefail

# ===== Configuración RDS desde variables de entorno =====
DB_HOST="${RDS_HOST:-dex-prod.c43mjqbkgpvb.us-east-1.rds.amazonaws.com}"
DB_PORT="${RDS_PORT:-3306}"
DB_DATABASE="${RDS_DATABASE:-hubapi}"
DB_USERNAME="${RDS_USERNAME:-dex_admin}"
DB_PASSWORD="${RDS_PASSWORD:-6dax5mTGbth5s8FMgZUv}"
DB_CHARSET="${DB_CHARSET:-utf8}"
DB_COLLATION="${DB_COLLATION:-utf8_general_ci}"

# RDS suele exigir SSL
SSL_MODE="${SSL_MODE:-REQUIRED}"     # REQUIRED recomendado en RDS
MAX_ALLOWED_PACKET="${MAX_ALLOWED_PACKET:-1G}"

INFILE="${1:-}"
usage(){ echo "Uso: $0 /ruta/dump.sql[.gz]"; exit 1; }
[[ -n "$INFILE" ]] || usage
[[ -r "$INFILE" ]] || { echo "[!] No puedo leer '$INFILE'"; exit 1; }

# Validar variables requeridas
if [[ -z "$DB_HOST" ]] || [[ -z "$DB_USERNAME" ]] || [[ -z "$DB_PASSWORD" ]]; then
  echo "[!] Error: Variables de entorno requeridas no están configuradas:"
  echo "    RDS_HOST, RDS_USERNAME, RDS_PASSWORD"
  exit 1
fi

# ===== Credenciales seguras via defaults-extra-file =====
TMP_CNF="$(mktemp)"
cleanup(){ [[ -f "$TMP_CNF" ]] && shred -u "$TMP_CNF" || true; }
trap cleanup EXIT

chmod 600 "$TMP_CNF"
cat > "$TMP_CNF" <<EOF
[client]
host=${DB_HOST}
port=${DB_PORT}
user=${DB_USERNAME}
password=${DB_PASSWORD}
default-character-set=${DB_CHARSET}
ssl-mode=${SSL_MODE}
max_allowed_packet=${MAX_ALLOWED_PACKET}
EOF

echo "[*] Probando conexión SSL a RDS (${DB_HOST}:${DB_PORT})..."
if ! mysql --defaults-extra-file="$TMP_CNF" -e "SELECT 1;" >/dev/null 2>&1; then
  echo "[!] No se pudo conectar a RDS. Revisa Security Group (puerto 3306 desde tu IP), usuario/clave y que SSL esté habilitado."
  exit 1
fi

# Crear DB si no existe (si el usuario puede)
echo "[*] Verificando base '${DB_DATABASE}'..."
mysql --defaults-extra-file="$TMP_CNF" -e "CREATE DATABASE IF NOT EXISTS \`${DB_DATABASE}\` CHARACTER SET ${DB_CHARSET} COLLATE ${DB_COLLATION};" || true

# ===== Preámbulo/Sesión =====
SESSION_SQL=$(cat <<'SQL'
SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0;
SET @OLD_AUTOCOMMIT=@@AUTOCOMMIT, AUTOCOMMIT=0;
SET NAMES current_charset COLLATE current_collation;
SQL
)
SESSION_SQL="${SESSION_SQL/current_charset/${DB_CHARSET}}"
SESSION_SQL="${SESSION_SQL/current_collation/${DB_COLLATION}}"

FOOTER_SQL=$(cat <<'SQL'
COMMIT;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET SQL_NOTES=@OLD_SQL_NOTES;
SET AUTOCOMMIT=@OLD_AUTOCOMMIT;
SQL
)

# ===== Decompresión =====
if [[ "$INFILE" == *.gz ]]; then
  DECOMPRESS_CMD=(gunzip -c -- "$INFILE")
elif [[ "$INFILE" == *.sql ]]; then
  DECOMPRESS_CMD=(cat -- "$INFILE")
else
  echo "[!] Extensión no reconocida. Usa .sql o .sql.gz"
  exit 1
fi

# ===== Progreso opcional =====
if command -v pv >/dev/null 2>&1; then
  PIPE_VIEWER=(pv)
else
  PIPE_VIEWER=(cat)
fi

# ===== Filtros de compatibilidad =====
# 1) Quita NO_AUTO_CREATE_USER en sql_mode
# 2) Quita DEFINER=... para rutinas/triggers
# 3) Elimina CREATE/DROP DATABASE (innecesario en RDS y puede fallar por permisos)
# 4) Reescribe 'USE `api_hub`' -> 'USE `hubapi`'
FILTERS=(
  sed -E
    -e 's/(^|,)\s*NO_AUTO_CREATE_USER\s*(,|)/\1\2/g' \
    -e 's/,,+/,/g' -e 's/=\s*,/=/g' \
    -e 's/DEFINER=`[^`]+`@`[^`]+`/DEFINER=CURRENT_USER/g' \
    -e '/^[[:space:]]*CREATE[[:space:]]+DATABASE\b/I d' \
    -e '/^[[:space:]]*DROP[[:space:]]+DATABASE\b/I d' \
    -e 's/\bUSE[[:space:]]+`api_hub`/USE `'"${DB_DATABASE}"'`/g'
)

echo "[*] Iniciando restauración en '${DB_DATABASE}' desde '${INFILE}'..."
{
  echo "$SESSION_SQL"
  "${DECOMPRESS_CMD[@]}" | "${FILTERS[@]}" | "${PIPE_VIEWER[@]}"
  echo "$FOOTER_SQL"
} | mysql --defaults-extra-file="$TMP_CNF" --database="$DB_DATABASE"

echo "[✓] Restauración completada en '${DB_DATABASE}' en ${DB_HOST}"