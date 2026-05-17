# GLPI CY Tech — Base de données avancées
> Mini-projet ING2 · Bases de données avancées · Année 2025-2026  
> CY Tech — Cergy & Pau

---

## Présentation du projet

Ce projet consiste à repenser une partie de la base de données de **GLPI** (Gestionnaire Libre de Parc Informatique) pour améliorer les performances du parc informatique de CY Tech, en prenant en compte l'aspect **multi-sites** (Cergy et Pau).

Le périmètre couvre la gestion des matériels informatiques, des utilisateurs et des informations sur la structure des réseaux.

---

## Structure du dépôt

```
GLPI_BDD/
│
├── sql/
│   ├── tables.sql                        # DDL : tables, séquences, triggers auto-incrément, index, données initiales
│   └── security_roles_users.sql          # Rôles BDD Oracle et attribution des privilèges
│
├── plsql/
│   ├── triggers_metier.sql               # Triggers de cohérence métier
│   ├── packages_metier.sql               # Package PKG_GLPI_METIER (procédures, curseurs)
│   └── data_generator.sql                # Générateur PL/SQL de données de test (seed fixe)
│
├── bddr/
│   ├── 01_Creation_utilisateurs_et_ privileges.sql  # Création des users Oracle (SYSDBA)
│   ├── 02_Creation_database_link.sql     # DB Links HUB → CERGY_SITE et PAU_SITE
│   ├── 03_Distribution.sql               # Fragmentation horizontale + vues UNION ALL sur HUB
│   ├── 04_Replication.sql                # Vues matérialisées (Site, Role, Permission, RolePermission)
│   └── 04b_Replication_Refresh.sql       # Rafraîchissement des vues matérialisées
│
├── tests/
│   ├── benchmark.sql                     # Protocole de benchmark (3 parties)
│   └── resultats_benchmark.txt           # Résultats exportés depuis SQL*Plus
│
├── docs/
│   └── resultats_performance.md          # Analyse des résultats de performance
│
├── Verifications_Setup.sql               # Vérifications post-installation (fragmentation + réplication)
└── install.sql                           # Script d'installation complet (ordre d'exécution)
```

---

## Prérequis

- **Oracle Database 21c Express Edition** (XE) dans Docker
- **SQL\*Plus** pour l'exécution des scripts
- **Docker** installé et démarré
- Droits SYSDBA pour la création des utilisateurs BDDR

---

## Installation

### 1. Copier les fichiers dans le conteneur

```bash
# Depuis la racine du projet
docker cp . oracle21xe:/opt/GLPI_BDD
```

### 2. Se connecter en SYSDBA

```bash
docker exec -it oracle21xe sqlplus / as sysdba
```

### 3. (BDDR uniquement) Créer les utilisateurs dans le PDB

```sql
ALTER SESSION SET CONTAINER = XEPDB1;
@/opt/GLPI_BDD/bddr/01_Creation_utilisateurs_et_privileges.sql
```

> ⚠️ Les utilisateurs `CYGLPI_HUB`, `CERGY_SITE` et `PAU_SITE` doivent être créés dans le PDB (`XEPDB1`), pas dans le CDB root (contrainte Oracle 21c XE).

### 4. Se connecter en tant qu'utilisateur applicatif

```bash
docker exec -it oracle21xe sqlplus C\#\#CYGLPI/password@XEPDB1
```

### 5. Lancer l'installation complète

```sql
@/opt/GLPI_BDD/install.sql
```

Ce script exécute dans l'ordre :
1. `tables.sql` — structure physique
2. `triggers_metier.sql` + `packages_metier.sql` — PL/SQL métier
3. Scripts BDDR (`01` → `04b`)
4. `data_generator.sql` — jeu de données
5. `security_roles_users.sql` — sécurité
6. Rafraîchissement des vues matérialisées
7. `benchmark.sql` — tests de performance

---

## Génération des données de test

Le générateur `data_generator.sql` utilise une **graine fixe** (`DBMS_RANDOM.SEED(42)`) pour garantir des données identiques sur toutes les machines du groupe.

| Entité          | Volumétrie |
|-----------------|-----------|
| Site            | 2         |
| Utilisateur     | 1 200     |
| Matériel        | 1 350     |
| Affectation     | ~415      |
| Ticket          | 5 000     |
| Réseau          | 50        |
| EquipementReseau| 80        |
| Bâtiment        | 5         |
| Salle           | 115       |
| Bureau          | 251       |

Répartition : **Cergy ≈ 2/3**, **Pau ≈ 1/3** (cohérent avec la taille réelle des deux campus).

---

## Architecture BDDR

```
        ┌──────────────────────────────────────┐
        │           CYGLPI_HUB                 │
        │  Tables maîtres : Site, Role,         │
        │  Permission, RolePermission           │
        │  Vues : V_ALL_MATERIELS,              │
        │         V_ALL_TICKETS,                │
        │         V_ALL_UTILISATEURS, ...       │
        └───────────┬──────────────┬───────────┘
                    │ cergy_link   │ pau_link
                    ▼              ▼
        ┌──────────────┐  ┌──────────────┐
        │  CERGY_SITE  │  │   PAU_SITE   │
        │  id_site = 1 │  │  id_site = 2 │
        │  Utilisateur │  │  Utilisateur │
        │  Materiel    │  │  Materiel    │
        │  Ticket ...  │  │  Ticket ...  │
        └──────────────┘  └──────────────┘
              ↑ Vues matérialisées ↑
         (Site, Role, Permission, RolePermission)
```

**Fragmentation horizontale** : chaque site ne stocke que ses propres données (`id_site`).  
**Réplication** : les tables de référence sont répliquées via des vues matérialisées (`REFRESH COMPLETE ON DEMAND`).

---

## Modèle de données

Tables principales :

| Table            | Description                                      |
|------------------|--------------------------------------------------|
| `Site`           | Cergy (id=1) et Pau (id=2)                       |
| `Batiment`       | Bâtiments par site                               |
| `Salle`          | Salles par bâtiment                              |
| `Bureau`         | Bureaux                                          |
| `Reseau`         | Réseaux avec `ip_range` et `wan` par site        |
| `EquipementReseau` | Serveurs, switches, routeurs                   |
| `Role`           | Admin, Technicien, Utilisateur, enseignant, etudiant |
| `Permission`     | READ, WRITE, DELETE                              |
| `RolePermission` | Association many-to-many rôle ↔ permission       |
| `Utilisateur`    | Utilisateurs avec `id_role` et `id_site`         |
| `Materiel`       | PC, Imprimante, Ecran avec statut et numéro de série unique |
| `Affectation`    | Affectation matériel ↔ utilisateur avec dates    |
| `Ticket`         | Tickets avec demandeur, technicien, matériel     |

---

## Sécurité (RBAC)

Trois rôles Oracle définis dans `security_roles_users.sql` :

| Rôle Oracle         | Droits                                              |
|---------------------|-----------------------------------------------------|
| `ROLE_UTILISATEUR`  | SELECT sur Materiel/Affectation, SELECT+INSERT Ticket |
| `ROLE_TECHNICIEN`   | SELECT/INSERT/UPDATE sur Materiel, Affectation, Ticket + lecture des autres tables |
| `ROLE_ADMIN`        | ALL PRIVILEGES sur l'ensemble des tables            |

---

## PL/SQL métier

### Triggers (`triggers_metier.sql`)

| Trigger                      | Événement             | Action                                              |
|------------------------------|-----------------------|-----------------------------------------------------|
| `trg_check_dispo_materiel`   | BEFORE INSERT Affectation | Vérifie que le matériel est `disponible`        |
| `trg_maj_statut_materiel`    | AFTER INSERT/UPDATE Affectation | Met le matériel à `affecte` ou `disponible` |
| `trg_verif_ticket_ferme`     | BEFORE UPDATE Ticket  | Bloque la modification d'un ticket fermé/résolu     |

### Package `PKG_GLPI_METIER` (`packages_metier.sql`)

| Procédure                    | Description                                         |
|------------------------------|-----------------------------------------------------|
| `declarer_incident`          | Crée un ticket et passe le matériel en `maintenance` |
| `cloturer_ticket`            | Résout un ticket et remet le matériel en `disponible` |
| `audit_materiel_site`        | Liste les matériels en panne d'un site (curseur FOR) |

---

## Benchmark de performance

Lancer le benchmark :

```sql
@/opt/GLPI_BDD/tests/benchmark.sql
```

Récupérer les résultats :

```bash
docker cp oracle21xe:/tmp/resultats_benchmark.txt ./tests/
```

### Résultats clés

**Partie 1 — Ancienne logique GLPI vs Nouvelle base**

| Cas | Coût GLPI | Coût Nouvelle BDD | Gain |
|-----|-----------|-------------------|------|
| Inventaire matériel par site | 426 000 | 18 | **×23 600 en coût, ×8,5 en temps** |
| Tickets avec liaison utilisateurs | 55 | 55 | ~30-40 % en temps |
| Réseau/équipements | 9 | 9 | Fonctionnellement enrichi (IP range) |

**Partie 2 — Sans index vs Avec index** : gains visibles sur les plans d'exécution (HASH JOIN → MERGE JOIN avec index). À grande volumétrie (>100 000 lignes), les index composites sur `(id_site, statut)` seraient décisifs.

**Partie 3 — BDDR** : fragmentation validée, réplication fonctionnelle, vues consolidées sur le HUB en < 20 ms.

---

## Points d'attention connus

| Problème | Cause | Statut |
|---|---|---|
| `DROP TABLE IF EXISTS` échoue | Syntaxe MySQL non supportée par Oracle | Ignorable (les tables existent déjà) |
| `ORA-65096` sur création users BDDR | Connexion au CDB root au lieu du PDB | Corriger avec `ALTER SESSION SET CONTAINER = XEPDB1` |
| `ORA-00001` sur INSERT Role/Permission | Données déjà présentes (double exécution) | Ignorable |

---

## Équipe

Projet réalisé par une équipe de 5 membres — ING2, CY Tech 2025-2026.

| Membre | Rôle |
|--------|------|
| Fatima | Reverse engineering & modèle existant |
| Marjorie | Modélisation cible & structure physique |
| Assia | Sécurité BDD & PL/SQL métier (`triggers`, `packages`, `security`) |
| Inès | BDDR multi-sites & optimisation requêtes |
| Myriam | Génération de données, benchmark & rapport de performance |