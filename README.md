# GLPI CY Tech — Bases de données avancées

> Mini-projet ING2 · CY Tech Cergy & Pau · 2025-2026

Repenser une partie de la BDD **GLPI** pour le parc multi-sites : matériels, utilisateurs, réseau.

---

## Structure du dépôt

```
GLPI_BDD/
├── ancienne_base/           # Dump GLPI 11.0.7 (As-Is MySQL)
├── docs/
│   ├── reverse_engineering.md    # Fatima — analyse As-Is
│   ├── modele_cible.md           # Marjorie — MPD / choix de conception
│   ├── explain_as_is.txt         # Plans EXPLAIN MySQL (baseline)
│   ├── bddr_strategie.md         # Inès — BDDR
│   ├── optimisation_plans_requetes.md
│   ├── plsql_et_securite.md      # Assia
│   └── resultats_performance.md  # Myriam
├── sql/
│   ├── reset_all.sql             # Tout supprimer (réinstall from scratch)
│   ├── 00_drop_schema.sql
│   ├── tablespaces.sql
│   ├── tables.sql                # DDL principal (cluster, partition, index)
│   ├── views_metier.sql
│   ├── baseline_queries.sql
│   ├── run_explain_as_is.sql
│   └── security_roles_users.sql
├── uml/
│   ├── glpi_existant.puml        # Schéma GLPI As-Is
│   └── diagramme_uml.puml        # Modèle cible
├── plsql/
│   ├── triggers_metier.sql
│   ├── packages_metier.sql
│   └── data_generator.sql
├── bddr/                    # BDDR (schémas HUB + sites)
├── tests/benchmark.sql
├── scripts/
│   ├── demo.sql / demo.sh        # Démo complète
│   └── run_explain_as_is.sh
├── install.sql              # Installation applicative (cyglpi)
└── install_bddr.sql         # BDDR (SYSDBA + HUB/sites)
```

---

## Prérequis

- Docker démarré + conteneur Oracle en marche
- SQLPlus (dans le conteneur)
- Mot de passe équipe : `**amsterdam**`

### Paramètres selon l’environnement


| Profil                    | Conteneur        | Utilisateur | PDB / service |
| ------------------------- | ---------------- | ----------- | ------------- |
| Oracle 19c (Fatima)       | `gallant_turing` | `cyglpi`    | `ORCLPDB1`    |
| Oracle 21 XE (ex. Myriam) | `oracle21xe`     | `C##cyglpi` | `XEPDB1`      |


> Sur le **PDB** (`ORCLPDB1` / `XEPDB1`), créer un utilisateur **sans** préfixe `C##`.  
> `C##cyglpi` est pour l’utilisateur commun CDB sur Oracle 21 XE.

---

## Guide démo — ordre des commandes

### A. Sur le Mac (terminal)

```bash
cd /chemin/vers/GLPI_BDD

# 1. Démarrer le conteneur
docker start gallant_turing          # ou : docker start oracle21xe

# 2. Copier le projet (à refaire après chaque git pull)
docker cp . gallant_turing:/opt/GLPI_BDD
```

### B. Créer l’utilisateur Oracle (une seule fois, SYSDBA)

```bash
docker exec -it gallant_turing sqlplus / as sysdba
```

```sql
ALTER SESSION SET CONTAINER = ORCLPDB1;   -- ou XEPDB1

CREATE USER cyglpi IDENTIFIED BY amsterdam;
GRANT CONNECT, RESOURCE, DBA TO cyglpi;
ALTER USER cyglpi QUOTA UNLIMITED ON USERS;
EXIT;
```

*(Équipe 21 XE qui utilise déjà `C##cyglpi@XEPDB1` : ignorer cette étape.)*

### C. Connexion SQLPlus

```bash
docker exec -it gallant_turing sqlplus cyglpi/amsterdam@ORCLPDB1
```

*(21 XE : `sqlplus 'C##cyglpi/amsterdam@XEPDB1'`)*

### D. Réinstall complète + démo (soutenance / première fois)

Dans SQLPlus — **toujours les chemins complets** :

```sql
@/opt/GLPI_BDD/sql/reset_all.sql              -- 1. Si install cassée ou données à 0
@/opt/GLPI_BDD/install.sql                    -- 2. Schéma + données + contrôle (~1–2 min)
@/opt/GLPI_BDD/scripts/demo_interactive.sql   -- 3. Démo soutenance (ENTREE entre sections)
```

Après `install.sql`, le script `**verify_install.sql**` affiche `PRET POUR LA DEMO` ou les corrections à faire.

Volumétrie attendue : **2 sites**, **~1350 matériels**, **~5000 tickets**.

> `install.sql` nettoie déjà au début. `reset_all.sql` = repartir de zéro (clusters orphelins).

### E. Quel script de démo ?


| Script                     | Quand l’utiliser                                                            |
| -------------------------- | --------------------------------------------------------------------------- |
| `**demo_interactive.sql`** | **Soutenance** — PAUSE, pas de package `CYTECH_DEMO` requis                 |
| `**demo.sql`**             | Enchaînement auto — bannières via `CYTECH_DEMO` (compilé par `install.sql`) |


```sql
@/opt/GLPI_BDD/scripts/demo_interactive.sql
```

### F. Benchmark

```sql
@/opt/GLPI_BDD/tests/benchmark.sql
```

```bash
docker cp gallant_turing:/tmp/resultats_benchmark.txt ./tests/
```

### G. BDDR multi-sites

Voir `install_bddr.sql` (SYSDBA + connexions `CYGLPI_HUB` / `CERGY_SITE` / `PAU_SITE`).

### H. EXPLAIN MySQL GLPI As-Is

Sur le Mac (Docker pour MariaDB) :

```bash
./scripts/run_explain_as_is.sh
```

---

## Démo

```bash
# Terminal
docker start gallant_turing
cd GLPI_BDD && docker cp . gallant_turing:/opt/GLPI_BDD
docker exec -it gallant_turing sqlplus cyglpi/amsterdam@ORCLPDB1
```

```sql
@/opt/GLPI_BDD/sql/reset_all.sql
@/opt/GLPI_BDD/install.sql
@/opt/GLPI_BDD/scripts/demo_interactive.sql
@/opt/GLPI_BDD/tests/benchmark.sql
```

## Équipe


| Membre   | Rôle                        |
| -------- | --------------------------- |
| Fatima   | Reverse engineering & As-Is |
| Marjorie | Modèle cible & DDL          |
| Assia    | Sécurité & PL/SQL           |
| Inès     | BDDR & optimisation         |
| Myriam   | Données de test & benchmark |


---

