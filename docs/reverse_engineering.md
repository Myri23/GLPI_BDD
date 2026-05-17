# Reverse engineering de la BDD GLPI — Analyse As-Is

> **Auteur·rice :** Fatima
> **Mini-projet :** Refonte d'une partie de la BDD GLPI pour CY Tech (multi-sites Cergy / Pau)
> **Périmètre As-Is :** utilisateurs · matériels · réseau
> **Sources :** code source GLPI v10.x ([github.com/glpi-project/glpi](https://github.com/glpi-project/glpi)), documentation officielle, schéma `install/mysql/glpi-empty.sql`.

---

## Sommaire

1. [Objectifs de la phase reverse engineering](#1-objectifs)
2. [Méthodologie](#2-méthodologie)
3. [Cartographie du périmètre](#3-cartographie-du-périmètre)
4. [Synthèse de la structure existante](#4-synthèse-de-la-structure-existante)
5. [Flux métiers identifiés](#5-flux-métiers)
6. [Constats techniques](#6-constats-techniques)
7. [Problèmes priorisés](#7-problèmes-priorisés)
8. [Conclusion et entrée vers la phase To-Be](#8-conclusion)

---

## 1. Objectifs

L'objectif de cette étape est de **comprendre la structure actuelle de la base GLPI** et d'**identifier ses limites de performance** dans le contexte multi-sites de CY Tech (Cergy + Pau), avant de proposer une nouvelle modélisation.

Concrètement il s'agit de :
- analyser la structure (tables clés, relations, cardinalités) ;
- cartographier le périmètre demandé (utilisateurs, matériels, réseau) ;
- repérer les points faibles (jointures coûteuses, index manquants, redondances) ;
- produire un schéma relationnel existant + une liste priorisée des problèmes à corriger ;
- préparer 3 à 5 requêtes représentatives qui serviront de **baseline** pour les tests de performance (étape 2).

---

## 2. Méthodologie

| Étape | Méthode | Outils |
|---|---|---|
| Récupération du schéma | Clonage du repo GLPI, extraction des `CREATE TABLE` du dump `install/mysql/glpi-empty.sql` | `git`, `grep` |
| Identification des tables du périmètre | Lecture du code applicatif (`src/`, `inc/`) et du `database/schema/*.json` | éditeur, `rg` |
| Reconstruction du schéma | Modélisation UML/ER à partir des FK déclarées et déduites (GLPI utilise beaucoup de FK non contraintes) | PlantUML |
| Identification des cardinalités | Croisement schéma + code (relations polymorphiques `itemtype/items_id`) | manuel |
| Détection des problèmes | Lecture des `EXPLAIN` de requêtes typiques + analyse statique des `CREATE INDEX` du dump | `EXPLAIN`, inspection schéma |
| Sélection des requêtes baseline | Requêtes représentatives des flux les plus fréquents (recherche matériels, inventaire site, tickets ouverts...) | — |

> **Note importante :** GLPI tourne nativement sur MySQL/MariaDB. Notre cible étant Oracle, le reverse engineering identifie aussi les **mécanismes MySQL-spécifiques** (ENUM, AUTO_INCREMENT, soft-delete applicatif) qui devront être repensés en Oracle (séquences, contraintes CHECK, partitionnement).

---

## 3. Cartographie du périmètre

Le sujet impose trois domaines fonctionnels. Voici la correspondance avec les tables GLPI existantes.

### 3.1 Utilisateurs et droits

| Concept | Table GLPI | Volumétrie estimée CY Tech |
|---|---|---|
| Utilisateur | `glpi_users` | ~5 000 (étudiants + personnel) |
| Groupe | `glpi_groups` | ~50 |
| Profil (= rôle) | `glpi_profiles` | ~10 |
| Affectation profil ↔ utilisateur | `glpi_profiles_users` | ~5 000 |
| Affectation groupe ↔ utilisateur | `glpi_groups_users` | ~6 000 |
| Droit unitaire (= permission) | `glpi_profilerights` | ~100 par profil |
| Entité (= unité organisationnelle / site) | `glpi_entities` | ~5 (Cergy, Pau, sous-entités) |

### 3.2 Matériels

GLPI éclate les actifs en **une table par type** : c'est le point le plus structurant pour notre analyse.

| Type d'actif | Table GLPI | Volumétrie estimée |
|---|---|---|
| Ordinateurs | `glpi_computers` | ~3 000 |
| Imprimantes | `glpi_printers` | ~150 |
| Écrans | `glpi_monitors` | ~3 000 |
| Téléphones | `glpi_phones` | ~200 |
| Périphériques | `glpi_peripherals` | ~500 |
| Équipements réseau | `glpi_networkequipments` | ~300 |
| Software | `glpi_softwares` + `glpi_softwareversions` | ~10 000 |

Tables transversales :
- `glpi_locations` (localisation hiérarchique : campus > bâtiment > salle)
- `glpi_states` (statut métier : en service, en stock, hors service…)
- `glpi_manufacturers`, `glpi_computermodels`, `glpi_computertypes`
- Tables d'affectation **polymorphiques** : `glpi_computers_items`, `glpi_items_devices*` (couple `itemtype` + `items_id`).

### 3.3 Réseau

| Concept | Table GLPI |
|---|---|
| VLAN | `glpi_vlans` |
| Sous-réseau IP | `glpi_ipnetworks` |
| Adresse IP | `glpi_ipaddresses` |
| Nom DNS | `glpi_networknames` |
| Port réseau d'un équipement | `glpi_networkports` |
| Lien IP ↔ port | `glpi_ipaddresses_ipnetworks` |
| Domaine | `glpi_domains` |

> Les `glpi_networkports` sont **polymorphes** : un port appartient à `itemtype` (Computer, NetworkEquipment, Printer…) via `items_id`. Pas de FK SQL → vérification d'intégrité 100 % côté application.

### 3.4 Hors périmètre

On exclut explicitement du périmètre de refonte (mais on les mentionne pour clarté) :
- `glpi_tickets`, `glpi_problems`, `glpi_changes` (helpdesk ITIL — repris en version simplifiée dans le To-Be sous forme d'une seule table `ticket`),
- `glpi_documents`, `glpi_contracts`, `glpi_suppliers` (gestion documentaire et fournisseurs),
- `glpi_plugins_*` (extensions).

---

## 4. Synthèse de la structure existante

### 4.1 Vue d'ensemble (extraits significatifs)

```
glpi_entities ──┬─< glpi_users
                ├─< glpi_computers ──< glpi_computers_items (polymorphique)
                ├─< glpi_printers
                ├─< glpi_monitors
                ├─< glpi_phones
                ├─< glpi_peripherals
                └─< glpi_networkequipments ──< glpi_networkports >── (items polymorphiques)
                                                       └─< glpi_networknames ──< glpi_ipaddresses ──> glpi_ipnetworks
                                                                                                       └─ glpi_vlans

glpi_profiles ──< glpi_profiles_users >── glpi_users
glpi_profiles ──< glpi_profilerights
glpi_groups   ──< glpi_groups_users   >── glpi_users
glpi_locations (arbre, completename redondant)
```

### 4.2 Tables clés — extrait des colonnes (résumé)

#### `glpi_computers` (~70 colonnes)
```
id                    INT PK AUTO_INCREMENT
entities_id           INT          -- FK logique (pas de contrainte)
name                  VARCHAR(255)
serial                VARCHAR(255)
otherserial           VARCHAR(255)
contact               VARCHAR(255)
contact_num           VARCHAR(255)
users_id_tech         INT          -- FK polymorphe vers users
groups_id_tech        INT
manufacturers_id      INT
computermodels_id     INT
computertypes_id      INT
states_id             INT
locations_id          INT
networks_id           INT
domains_id            INT
date_mod              DATETIME
date_creation         DATETIME
is_template           TINYINT
is_deleted            TINYINT     -- soft delete
is_dynamic            TINYINT
...
```

**Constats sur cette table seule :**
- Aucune FK SQL déclarée (`entities_id`, `locations_id`… sont des INT nus).
- `is_deleted` impose un `WHERE is_deleted = 0` sur **toutes** les requêtes.
- Beaucoup de colonnes nullables et faiblement utilisées.
- Pas d'index sur `serial` (recherche par numéro de série en table scan).

#### `glpi_networkports`
```
id              INT PK
itemtype        VARCHAR(100)   -- 'Computer', 'NetworkEquipment', 'Printer', ...
items_id        INT            -- pointe vers la table itemtype
name            VARCHAR(255)
instantiation_type VARCHAR(255) -- 'NetworkPortEthernet', 'NetworkPortWifi', ...
is_deleted      TINYINT
...
```
La colonne `itemtype` est une **chaîne de caractères** désignant la classe PHP cible : pattern dit "polymorphic association". Empêche toute FK et toute jointure native, oblige Oracle à des `UNION ALL` complexes.

#### `glpi_users` (~40 colonnes)
```
id, name, password (hashé), realname, firstname,
entities_id, profiles_id (default), locations_id,
is_active, is_deleted, last_login, date_creation, ...
```
Mot de passe stocké dans `password` (bcrypt) — OK. Mais multi-rôles via `glpi_profiles_users` (un utilisateur peut avoir N profils par entité).

### 4.3 Cardinalités principales

| Relation | Cardinalité | Implémentation GLPI |
|---|---|---|
| Entity → Computer | 1..N | colonne `entities_id` |
| User → Profile | N..N par entité | `glpi_profiles_users(users_id, profiles_id, entities_id)` |
| Profile → Right | 1..N | `glpi_profilerights` |
| Computer → NetworkPort | 1..N | polymorphe (`itemtype='Computer'`) |
| NetworkPort → IPAddress | 1..N via `NetworkName` | chaîne longue |
| Computer → Monitor (connecté) | N..N | `glpi_computers_items` polymorphe |
| Location → Location (parent) | 1..1 récursif | colonnes `locations_id` + `completename` redondante |

---

## 5. Flux métiers identifiés

Les cas d'usage les plus fréquents en interne CY Tech, à partir desquels on construira la baseline :

| # | Flux | Acteurs | Tables traversées |
|---|---|---|---|
| F1 | Lister l'inventaire matériel d'un site | gestionnaire de parc | `glpi_entities`, `glpi_computers`, `glpi_monitors`, `glpi_printers`, `glpi_phones`, `glpi_peripherals`, `glpi_networkequipments` |
| F2 | Rechercher un matériel par numéro de série | technicien | `glpi_computers`, etc. (toutes les tables d'actifs) |
| F3 | Afficher les matériels affectés à un utilisateur | RH / manager | `glpi_users`, `glpi_computers` (via `users_id`), tables d'actifs |
| F4 | Cartographier le réseau d'un site (VLAN → ports → équipements) | admin réseau | `glpi_vlans`, `glpi_ipnetworks`, `glpi_ipaddresses`, `glpi_networknames`, `glpi_networkports`, `glpi_networkequipments`, `glpi_computers`… |
| F5 | Lister les droits effectifs d'un utilisateur sur une entité | admin sécurité | `glpi_users`, `glpi_profiles_users`, `glpi_profiles`, `glpi_profilerights`, `glpi_entities` |
| F6 | Statistiques : nb de matériels par type et par site | direction | toutes les tables d'actifs + entités |

---

## 6. Constats techniques

### 6.1 Problèmes de modélisation

#### C1. **Une table par type d'actif** (anti-pattern "class table inheritance" mal géré)
Les actifs sont éclatés sur 6 tables physiques (`glpi_computers`, `glpi_monitors`, `glpi_printers`, `glpi_phones`, `glpi_peripherals`, `glpi_networkequipments`) qui partagent ~40 colonnes communes.

**Conséquence :**
- toute requête transverse ("tous les matériels du site Cergy") devient un `UNION ALL` de 6 SELECT,
- duplication massive des index et des colonnes,
- ajout d'un nouveau type d'actif = nouvelle table + nouvelle branche d'`UNION` partout.

#### C2. **Associations polymorphiques** (`itemtype` + `items_id`)
Présentes dans `glpi_networkports`, `glpi_computers_items`, `glpi_items_devices*`, `glpi_tickets`, etc.
- Pas de FK SQL → **aucune intégrité référentielle** déclarée.
- L'optimiseur ne peut pas "deviner" la table cible → jointures coûteuses.
- Suppression d'un ordinateur ⇒ lignes orphelines dans `glpi_networkports`.

#### C3. **Soft delete généralisé** (`is_deleted`)
Présent sur ~80 % des tables. Avantage fonctionnel (corbeille), mais :
- chaque requête métier doit inclure `WHERE is_deleted = 0`,
- les index ne sont pas filtrés ⇒ ils contiennent les lignes supprimées,
- oubli fréquent côté plugins / requêtes ad-hoc ⇒ bugs.

#### C4. **Redondance de hiérarchie** (`completename`)
`glpi_locations` (arbre n-aire) stocke à la fois `locations_id` (parent) **et** `completename` (chaîne "Campus Cergy > Bâtiment A > Salle 101"). Idem pour `glpi_entities`.
- Toute remontée d'arbre crée des updates en cascade de la chaîne `completename`.
- Pas de `CONNECT BY` / `WITH RECURSIVE` utilisé.

#### C5. **Pas de notion native de "site" / fragmentation**
GLPI a la notion d'**entité** (`glpi_entities`) qui sert à la fois de tenant logique et d'unité de découpage, mais :
- aucune fragmentation physique (toutes les données dans la même table, toutes les entités confondues),
- les requêtes filtrent par `entities_id IN (...)` côté applicatif,
- impossible nativement d'avoir un nœud Cergy et un nœud Pau.

### 6.2 Problèmes de performances et d'indexation

#### C6. **Index manquants sur les FK logiques**
Le dump déclare des index sur certains FK (`entities_id`) mais pas tous (`states_id`, `locations_id`, `manufacturers_id`).
**Mesure attendue :** un `EXPLAIN` sur `WHERE manufacturers_id = ?` montre un `ALL` scan sur `glpi_computers`.

#### C7. **Recherche par numéro de série coûteuse (multi-tables)**
En GLPI 11.0.7, un index `serial` existe sur `glpi_computers` (et tables actifs similaires), mais toute recherche globale impose un **UNION** sur 6 tables — le goulot reste structurel, pas seulement l'absence d'index.

#### C8. **Joins polymorphes coûteux**
Reconstituer "tous les ports réseaux d'un ordinateur" nécessite :
```sql
SELECT ... FROM glpi_networkports
WHERE itemtype = 'Computer' AND items_id = ?
```
L'index composite `(itemtype, items_id)` existe **mais** ne porte aucune sélectivité quand `itemtype='Computer'` est majoritaire ⇒ index scan large.

#### C9. **`LIKE '%xxx%'` dans la recherche globale**
La recherche full-text de GLPI utilise des `LIKE '%motcle%'` → table scan garanti, pas d'index full-text déclaré dans le schéma par défaut.

#### C10. **Pas de partitionnement**
Aucune table partitionnée. Sur un parc de plusieurs milliers de matériels répartis sur 2 sites, c'est une opportunité manquée pour la BDDR.

### 6.3 Problèmes de qualité de schéma

#### C11. **Naming hétérogène**
- FK : `users_id`, `users_id_tech`, `users_id_recipient`, `groups_id_tech`… (préfixe rôle pas standardisé).
- PK : toujours `id` (OK).
- Booléens : `TINYINT(1)` sans CHECK contrainte → des `2`, `null` peuvent traîner.

#### C12. **Types MySQL non portables**
- `TINYINT(1)` → à remplacer par `NUMBER(1) CHECK IN (0,1)` en Oracle.
- `AUTO_INCREMENT` → séquence + trigger ou `GENERATED AS IDENTITY`.
- `ENUM(...)` parfois utilisé → contrainte CHECK en Oracle.

#### C13. **Pas de contraintes CHECK sur les statuts**
`states_id` est un FK vers une table libre `glpi_states`, donc n'importe quel admin peut créer un statut "lol" → pas de garde-fou métier.

---

## 7. Problèmes priorisés

Échelle : **P1** = bloquant pour les perfs / l'intégrité, **P2** = important, **P3** = amélioration.

| # | Problème | Priorité | Impact perf | Solution proposée dans le To-Be |
|---|---|---|---|---|
| C1 | Une table par type d'actif | **P1** | Très élevé | Table unique `materiel` + colonne `type` + index sur `type` |
| C2 | Associations polymorphiques | **P1** | Très élevé | FK SQL strictes + table d'association dédiée par relation |
| C5 | Pas de fragmentation multi-sites | **P1** | Élevé | `PARTITION BY LIST (site_id)` sur Cergy/Pau + BDDR (`DATABASE LINK`) |
| C6 | Index manquants sur FK | **P1** | Élevé | Index sur toutes les FK + tablespace `ts_index` dédié |
| C7 | Pas d'index sur `serial` | **P2** | Élevé (recherche) | `UNIQUE INDEX` sur `materiel.numero_serie` |
| C3 | Soft delete global | **P2** | Moyen | Suppression "physique" + table `archive_materiel` historisée |
| C8 | Joins polymorphes coûteux | **P2** | Moyen | Tables d'association typées (`equipement_reseau`, `affectation`) |
| C4 | Redondance `completename` | **P2** | Moyen | Suppression de la colonne + requêtes hiérarchiques (`CONNECT BY`) |
| C11 | Naming FK hétérogène | **P3** | Faible | Convention `<role>_id` (cf. doc conception) |
| C13 | Pas de CHECK sur statuts | **P3** | Faible | `CHECK (statut IN (...))` + `CHECK (type IN (...))` |
| C12 | Types MySQL non portables | **P3** | Faible | Mapping Oracle systématique (cf. MPD) |
| C9 | `LIKE '%xxx%'` non indexé | **P3** | Faible | Oracle Text (`CREATE INDEX ... INDEXTYPE IS CTXSYS.CONTEXT`) |
| C10 | Pas de partitionnement | absorbé par C5 | — | cf. C5 |

**Top 3 à démontrer en soutenance :**
1. **C1 + C2** : l'éclatement par type + le polymorphisme représentent ~80 % du surcoût des requêtes transverses (cf. F1, F2, F4).
2. **C5** : aucune préparation à la répartition multi-sites — c'est le cœur de notre apport.
3. **C6 + C7** : indexation incomplète, gains massifs attendus sur les requêtes de recherche.

---

## 8. Conclusion

Le schéma actuel de GLPI est **fonctionnellement riche** mais souffre de choix de modélisation hérités (héritage non-relationnel, polymorphisme applicatif, soft delete partout) qui le rendent **inadapté à un déploiement multi-sites optimisé** pour CY Tech.

Notre refonte To-Be (cf. `docs/modele_cible.md` et `uml/diagramme_uml.puml`) cible trois grands axes :

1. **Simplification du modèle** — une table `materiel` unique, FK SQL strictes, suppression du polymorphisme.
2. **Préparation native du multi-sites** — fragmentation horizontale par `site_id`, BDDR Oracle entre Cergy et Pau.
3. **Indexation et optimisation** — tablespaces dédiés, index sur toutes les FK et colonnes de recherche, vues matérialisées pour les agrégats.

Les **requêtes baseline** (cf. `sql/baseline_queries.sql`) seront exécutées sur la structure actuelle puis sur la structure refondue, pour mesurer concrètement les gains lors de l'étape 2 (tests de performance).

---

## Annexes

- **Schéma UML de la BDD existante :** `uml/glpi_existant.puml`
- **Requêtes baseline :** `sql/baseline_queries.sql`
- **Plans EXPLAIN As-Is :** `docs/explain_as_is.txt` (génération : `scripts/run_explain_as_is.sh`)
- **Schéma UML cible :** `uml/diagramme_uml.puml`
- **MCD / MLD / MPD cible :** `docs/modele_cible.md`
