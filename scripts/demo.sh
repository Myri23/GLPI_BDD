#!/usr/bin/env bash
# Démo complète du projet GLPI_BDD
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONTAINER="${ORACLE_CONTAINER:-gallant_turing}"
PDB="${ORACLE_PDB:-ORCLPDB1}"
USER="${ORACLE_USER:-cyglpi}"
PASS="${ORACLE_PASS:-amsterdam}"

echo "=== Copie du projet dans le conteneur ${CONTAINER} ==="
docker cp "$ROOT" "${CONTAINER}:/opt/GLPI_BDD"

echo "=== Installation applicative ==="
docker exec -i "$CONTAINER" sqlplus -s "${USER}/${PASS}@${PDB}" <<'SQL'
@/opt/GLPI_BDD/install.sql
SQL

DEMO_SCRIPT="${DEMO_SCRIPT:-demo_interactive.sql}"
echo "=== Démo : ${DEMO_SCRIPT} (DEMO_SCRIPT=demo.sql pour mode auto) ==="
docker exec -it "$CONTAINER" sqlplus "${USER}/${PASS}@${PDB}" "@/opt/GLPI_BDD/scripts/${DEMO_SCRIPT}"

echo "=== (Optionnel) Benchmark ==="
echo "docker exec -it $CONTAINER sqlplus ${USER}/${PASS}@${PDB} @/opt/GLPI_BDD/tests/benchmark.sql"
