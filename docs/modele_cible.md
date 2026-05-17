# Modèle cible — GLPI CY Tech

## Objectifs

1. Une table **`Materiel`** unique (fin de l’éclatement GLPI par type).
2. **FK SQL** explicites, sans polymorphisme `itemtype/items_id`.
3. **Multi-sites** : `id_site` + partition LIST sur `Materiel`.
4. **Performance** : tablespaces, index, cluster, vues métier.

## Schéma logique

Voir `uml/diagramme_uml.puml` et DDL `sql/tables.sql`.

| Entité | Rôle |
|--------|------|
| Site | Cergy (1), Pau (2) |
| Batiment → Salle → Bureau | Localisation (cluster sur `id_site` pour Batiment) |
| Materiel | PC / Imprimante / Ecran, partitionné par site |
| Utilisateur, Role, Permission | RBAC simplifié |
| Reseau, EquipementReseau | Périmètre réseau par site |
| Affectation, Ticket | Exploitation quotidienne |

## Structure physique (MPD)

| Mécanisme | Implémentation |
|-----------|----------------|
| Tablespaces | `ts_data`, `ts_index` (`sql/tablespaces.sql`) |
| Cluster | `cluster_batiment_site` sur `Batiment(id_site)` |
| Partitionnement | `Materiel` PARTITION BY LIST (`id_site`) |
| Index | FK, `numero_serie`, `(statut)`, `login` — `sql/tables.sql` |
| Vues | `V_INVENTAIRE_SITE`, `V_ETAT_MATERIEL`, … — `sql/views_metier.sql` |

## Traçabilité des choix (As-Is → To-Be)

| Constat As-Is | Choix cible |
|---------------|-------------|
| C1 — une table par type d’actif | Table `Materiel` + colonne `type` |
| C2 — polymorphisme | FK directes |
| C5 — pas de fragmentation | `id_site` + partition + BDDR |
| C6/C7 — indexation | Index dédiés + tablespace `ts_index` |
| C3 — soft delete | Statuts métier + pas de `is_deleted` global |

## Scripts

- DDL : `sql/tables.sql`
- Vues : `sql/views_metier.sql`
- As-Is : `docs/reverse_engineering.md`, `uml/glpi_existant.puml`
