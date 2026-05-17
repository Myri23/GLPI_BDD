# Optimisation et plans d’exécution

## Méthode

1. Requêtes de référence As-Is : `sql/baseline_queries.sql` (MySQL / MariaDB + `docs/explain_as_is.txt`).
2. Comparaison To-Be : `tests/benchmark.sql` (`EXPLAIN PLAN` + `DBMS_XPLAN.DISPLAY`).
3. Analyse consolidée : `docs/resultats_performance.md`.

## Requêtes clés

| ID | Flux | Optimisation To-Be |
|----|------|-------------------|
| Q1 | Inventaire par site | 1 table `Materiel` + partition `id_site` vs 6× UNION GLPI |
| Q2 | Recherche série | Index `idx_materiel_serial` |
| Q3 | Cartographie réseau | FK `Reseau` / `EquipementReseau` vs chaîne polymorphe GLPI |
| Q4 | Droits utilisateur | `V_DROITS_ROLE` + RBAC normalisé |
| Q5 | Stats par site/type | `V_ETAT_MATERIEL` |

## Benchmark Oracle (extrait)

Exécuter après `install.sql` :

```sql
@/opt/GLPI_BDD/tests/benchmark.sql
```

Exporter : `docker cp <conteneur>:/tmp/resultats_benchmark.txt ./tests/`

## Partie 2 — impact des index

Le benchmark compare requêtes avec / sans index sur `Materiel`, `Affectation`, `Ticket`.  
À grande volumétrie, les index composites `(id_site, statut)` deviennent déterminants.

## Partie 3 — BDDR

Requêtes sur `V_ALL_MATERIELS`, `V_ALL_TICKETS` depuis `CYGLPI_HUB` — coût du `UNION ALL` distant vs gain de fragmentation locale.
