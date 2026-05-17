#!/usr/bin/env bash
# Charge le schéma GLPI 11.0.7 (vide) dans MariaDB et exporte les plans EXPLAIN
# des requêtes baseline As-Is vers docs/explain_as_is.txt
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DUMP="${ROOT}/ancienne_base/glpi-11.0.7-empty.sql"
EXPLAIN_SQL="${ROOT}/sql/run_explain_as_is.sql"
OUTPUT="${ROOT}/docs/explain_as_is.txt"
CONTAINER="glpi-asis-mysql"
IMAGE="mariadb:11"
DB="glpi_asis"
ROOT_PASS="glpi_root"

if [[ ! -f "$DUMP" ]]; then
  echo "Erreur : dump introuvable : $DUMP" >&2
  exit 1
fi

echo "==> Démarrage MariaDB (conteneur ${CONTAINER})..."
docker rm -f "$CONTAINER" 2>/dev/null || true
docker run -d --name "$CONTAINER" \
  -e MARIADB_ROOT_PASSWORD="$ROOT_PASS" \
  -e MARIADB_DATABASE="$DB" \
  "$IMAGE" >/dev/null

cleanup() { docker rm -f "$CONTAINER" >/dev/null 2>&1 || true; }
trap cleanup EXIT

echo "==> Attente du serveur..."
for i in $(seq 1 60); do
  if docker exec "$CONTAINER" mariadb-admin ping -uroot -p"$ROOT_PASS" --silent 2>/dev/null; then
    break
  fi
  sleep 1
  if [[ "$i" -eq 60 ]]; then
    echo "Erreur : MariaDB ne répond pas." >&2
    exit 1
  fi
done

echo "==> Import du schéma GLPI (peut prendre 1–2 min)..."
docker exec -i "$CONTAINER" mariadb -uroot -p"$ROOT_PASS" "$DB" < "$DUMP"

echo "==> Exécution des EXPLAIN..."
{
  echo "============================================================================"
  echo " Plans EXPLAIN — Base GLPI As-Is (MySQL/MariaDB)"
  echo " Source schéma : ancienne_base/glpi-11.0.7-empty.sql (GLPI 11.0.7, vide)"
  echo " Requêtes      : sql/baseline_queries.sql (variante sql/run_explain_as_is.sql)"
  echo " Généré le     : $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  echo " Moteur        : MariaDB 11 (Docker)"
  echo " Note          : schéma vide (0 ligne) — les types d'accès (ALL, index) restent"
  echo "                 représentatifs ; les coûts estimés évoluent avec des données."
  echo "============================================================================"
  echo ""
  docker exec -i "$CONTAINER" mariadb -uroot -p"$ROOT_PASS" "$DB" < "$EXPLAIN_SQL"
} | tee "$OUTPUT"

echo "==> Résultats enregistrés dans : $OUTPUT"
