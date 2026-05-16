# Résultats de performance — GLPI CY Tech
**Mini-projet Bases de données avancées — ING2 2025-2026**

---

## 1. Volumétrie du jeu de test

Le jeu de données a été généré en PL/SQL pour simuler un environnement réaliste représentant les deux sites de CY Tech (Cergy et Pau).

| Entité              | Nombre de lignes |
|---------------------|-----------------|
| Site                | 2               |
| Utilisateur         | 1 200           |
| Matériel            | 1 350           |
| Affectation         | 415             |
| Ticket              | 5 000           |
| Réseau              | 50              |
| EquipementReseau    | 80              |
| Bâtiment            | 5               |
| Salle               | 115             |
| Bureau              | 251             |
| Rôle                | 5               |
| Permission          | 3               |
| RolePermission      | 8               |

> **Répartition inter-sites (Synthèse finale) :**
> - Cergy : 529 PC, 189 imprimantes, 182 écrans, 800 utilisateurs, 3 358 tickets
> - Pau : 268 PC, 94 imprimantes, 88 écrans, 400 utilisateurs, 1 642 tickets

---

## 2. Partie 1 — Ancienne logique GLPI vs Nouvelle base CY Tech

L'objectif de cette partie est de comparer les plans d'exécution et les temps de réponse entre des requêtes reproduisant la logique GLPI d'origine (jointures coûteuses, sous-requêtes imbriquées, tables de liaison polymorphiques) et les requêtes équivalentes sur la nouvelle architecture.

### Cas 1 — Inventaire matériel par site

**CAS 1A — Logique GLPI (sous-requête imbriquée)**
- Simule : `glpi_computers JOIN glpi_locations JOIN glpi_entities` + sous-requête pour relier l'utilisateur via la table d'affectation
- Plan hash : `1945376179`
- Opération dominante : `HASH JOIN` avec `MERGE JOIN CARTESIAN` sur SITE × UTILISATEUR (1 200 lignes projetées)
- **Coût estimé : 426 000**
- Temps d'exécution : **0,34 s** (pour 222 lignes retournées)

**CAS 1B — Nouvelle base (jointures directes)**
- Plan hash : `1090989713`
- Opération dominante : `HASH JOIN` enchaîné sans produit cartésien
- **Coût estimé : 18**
- Temps d'exécution : **0,04 s** (pour 222 lignes retournées)

> **Gain constaté : réduction du coût de ~99,99 % (426 000 → 18) ; temps divisé par ~8,5 (340 ms → 40 ms)**

L'ancienne logique générait un `MERGE JOIN CARTESIAN` entre SITE et UTILISATEUR avant filtrage, ce qui multipliait les lignes intermédiaires. La nouvelle structure avec FK directes permet à l'optimiseur de choisir des `HASH JOIN` simples et ordonnés.

---

### Cas 2 — Tickets avec liaison utilisateurs

**CAS 2A — Logique GLPI (double table de liaison)**
- Simule : `glpi_tickets JOIN glpi_tickets_users (type=1) JOIN glpi_tickets_users (type=2)`
- Plan hash : `760422821`
- Opérations : double `TABLE ACCESS FULL` sur UTILISATEUR (1 200 lignes × 2), `HASH JOIN` empilés
- **Coût estimé : 55**
- Temps d'exécution : **0,03–0,05 s** (684 lignes)

**CAS 2B — Nouvelle base (FK directes optimisées)**
- Plan hash : `2164608781`
- Opérations : `HASH JOIN` avec `INDEX FULL SCAN` sur SITE, `SORT JOIN` sur MATERIEL
- **Coût estimé : 55** (identique, mais plan réorganisé)
- Temps d'exécution : **0,02 s** (684 lignes)

> **Gain constaté : temps réduit d'environ 30–40 % ; suppression du second accès redondant à UTILISATEUR**

La nouvelle structure élimine la table de liaison polymorphique (`glpi_tickets_users`) en utilisant des FK typées directement sur TICKET (`id_demandeur`, `id_technicien`), ce qui simplifie le plan d'exécution.

---

### Cas 3 — Réseau et équipements réseau

**CAS 3A — Logique GLPI (sous-requête hiérarchique)**
- Simule : `glpi_networkequipments → glpi_locations → glpi_entities` sans IP range natif
- Plan hash : `1670330303`
- Opérations : `NESTED LOOPS` sur SITE + `INDEX RANGE SCAN` sur `IDX_RESEAU_SITE`, `TABLE ACCESS FULL` sur EQUIPEMENTRESEAU
- **Coût estimé : 9**
- Temps d'exécution : **0,01 s** (80 lignes)

**CAS 3B — Nouvelle base (jointure directe + IP range)**
- Plan hash : `3674510967`
- Opérations : `INDEX FULL SCAN` sur `IDX_EQUIPEMENT_RESEAU`, `MERGE JOIN` avec vue consolidée, `NESTED LOOPS` pour RESEAU
- **Coût estimé : 9** (identique)
- Temps d'exécution : **0,01–0,02 s** (6 lignes agrégées par site et type)

> **Gain fonctionnel : la nouvelle base expose nativement l'IP range (ex. `10.10.1.0/24` pour Cergy, `10.20.1.0/24` pour Pau), information absente de la logique GLPI d'origine. Les coûts sont équivalents, mais la requête retourne des données plus riches.**

---

### Tableau récapitulatif — Partie 1

| Cas | Description | Coût GLPI | Coût Nouvelle BDD | Temps GLPI | Temps Nouvelle BDD | Gain |
|-----|-------------|-----------|-------------------|------------|-------------------|------|
| 1 — Inventaire matériel | Sous-requête imbriquée vs jointures directes | 426 000 | 18 | ~340 ms | ~40 ms | **×8,5 en temps, ×23 600 en coût** |
| 2 — Tickets utilisateurs | Double table liaison vs FK directes | 55 | 55 | ~50 ms | ~20 ms | **~30–40 % en temps** |
| 3 — Réseau/équipements | Hiérarchique vs jointure directe + IP range | 9 | 9 | ~10 ms | ~10–20 ms | **Fonctionnellement enrichi** |

---

## 3. Partie 2 — Sans index vs Avec index

Trois requêtes représentatives ont été exécutées dans deux configurations : après suppression de tous les index (Phase 2A) puis après recréation et mise à jour des statistiques (Phase 2B).

### Test P2-1 — Parc matériel Cergy par statut

**Sans index (Phase 2A)**
- Plan hash : `1096501729`
- Opération : `HASH JOIN` + double `TABLE ACCESS FULL` (SITE, MATERIEL)
- **Coût : 10 (20 % CPU)**
- Temps : **0,02 s** (12 lignes)

**Avec index (Phase 2B)**
- Plan hash : `3078288053`
- Opération : `MERGE JOIN` + `TABLE ACCESS BY INDEX ROWID` sur SITE via `INDEX FULL SCAN`
- **Coût : 10 (30 % CPU)**
- Temps : **0,01–0,02 s** (12 lignes)

> **Observation :** Sur une table SITE de 2 lignes, l'optimiseur utilise l'index de PK pour éviter un full scan, mais le coût global reste similaire en raison de la petite taille des tables. Le bénéfice des index deviendra déterminant à plus grande volumétrie.

---

### Test P2-2 — Tickets ouverts par site

**Sans index et Avec index**
- Plan hash identique dans les deux phases : `4131753400`
- Opérations : `HASH GROUP BY` + `NESTED LOOPS` + `TABLE ACCESS FULL` sur TICKET et MATERIEL + `INDEX UNIQUE SCAN` sur PK SITE
- **Coût : 41 (5 % CPU)**
- Temps : **0,02–0,03 s** dans les deux cas

> **Observation :** L'optimiseur utilise déjà l'index de clé primaire de SITE (contrainte système) même en phase "sans index" puisque les index de PK/UK ne sont pas supprimés dans ce protocole. Pour TICKET (684 lignes) et MATERIEL (1 350 lignes), le full scan reste préférable à cette volumétrie.

Résultats : Cergy = 464 tickets ouverts, Pau = 220 tickets ouverts.

---

### Test P2-3 — Affectations actives avec rôle

**Sans index (Phase 2A)**
- Plan hash : `1165275435`
- Opérations : `HASH JOIN` × 2, `TABLE ACCESS FULL` sur AFFECTATION (316 lignes), UTILISATEUR (1 200 lignes), MATERIEL (1 350 lignes) + `MERGE JOIN` + `INDEX FULL SCAN` sur PK SITE
- **Coût : 21 (10 % CPU)**
- Temps : **0,03 s** (316 lignes affectées)

**Avec index (Phase 2B)**
- Plan hash identique : `1165275435`
- **Coût : 21** — même plan
- Temps : **0,04 s**

> **Observation :** Le plan est strictement identique. L'optimiseur exploite déjà l'`INDEX FAST FULL SCAN` sur les contraintes de PK/UK de ROLE (`SYS_C008497`, `SYS_C008498`) dans les deux phases. L'absence d'index supplémentaires sur AFFECTATION et UTILISATEUR n'est pas compensée par des index de FK à cette volumétrie.

---

### Tableau récapitulatif — Partie 2

| Test | Coût sans index | Coût avec index | Temps sans index | Temps avec index | Δ plan |
|------|----------------|----------------|-----------------|-----------------|--------|
| P2-1 — Parc Cergy par statut | 10 | 10 | 20 ms | 10–20 ms | Plan modifié (MERGE JOIN vs HASH JOIN) |
| P2-2 — Tickets ouverts/site | 41 | 41 | 20–30 ms | 20–30 ms | Plan identique |
| P2-3 — Affectations actives | 21 | 21 | 30 ms | 40 ms | Plan identique |

> **Analyse globale :** À la volumétrie actuelle (≤ 5 000 lignes par table), les index n'apportent pas de gain dramatique car l'optimiseur Oracle préfère souvent le full scan pour les petites tables. Les index définis (`IDX_AFFECTATION_MATERIEL`, `IDX_RESEAU_SITE`, `IDX_EQUIPEMENT_RESEAU`) montrent leur valeur dans les jointures de la Partie 1 (notamment le CAS 1A → 1B). À plus grande volumétrie (> 100 000 lignes), les index de FK et les index composites sur `(id_site, statut)` seraient décisifs.

---

## 4. Partie 3 — BDDR Multi-sites (Cergy / Pau)

La base répartie simule une fragmentation horizontale des données entre deux nœuds : `CYGLPI_CERGY` (site principal) et `CYGLPI_PAU` (site secondaire), coordonnés par un hub central `CYGLPI_HUB`.

### BDDR-1 — Parc informatique Cergy vs Pau

| Site  | PC  | Imprimantes | Écrans | Total matériels |
|-------|-----|-------------|--------|-----------------|
| Cergy | 529 | 189         | 182    | 900             |
| Pau   | 268 | 94          | 88     | 450             |

> Ratio Cergy/Pau ≈ 2:1, cohérent avec un campus principal (Cergy) et un campus secondaire (Pau).

### BDDR-2 — Vérification de la fragmentation

La fragmentation horizontale est validée : chaque site ne contient que ses propres données. Les tables de référence (Rôle, Permission, RolePermission) sont répliquées sur les deux sites pour garantir l'autonomie locale.

### BDDR-3 — Vue consolidée des tickets (tous sites)

La vue consolidée agrège les tickets des deux fragments via `UNION ALL`. Les 5 000 tickets sont correctement répartis (3 358 Cergy + 1 642 Pau = 5 000).
- Temps de requête : **0,01 s**

### BDDR-4 — Tables répliquées (Rôles et Permissions)

Les tables de gouvernance (5 rôles, 3 permissions, 8 associations role-permission) sont identiques sur les deux sites, garantissant une cohérence des droits d'accès sans requête inter-sites.

### BDDR-5 — Analyse de charge inter-sites depuis le hub

Le hub central (`CYGLPI_HUB`) permet d'interroger les deux fragments de manière transparente. Les requêtes d'analyse de charge (répartition des tickets, matériels par site) s'exécutent en **0,01–0,02 s**.

### BDDR-6 — Taux d'utilisation des matériels par site et type

| Site  | Type       | Nb total | En service | Taux (%) | Moy. type global |
|-------|------------|----------|------------|----------|-----------------|
| Cergy | PC         | 529      | 0          | 0 %      | 398,5           |
| Cergy | Imprimante | 189      | 0          | 0 %      | 141,5           |
| Cergy | Écran      | 182      | 0          | 0 %      | 135             |
| Pau   | PC         | 268      | 0          | 0 %      | 398,5           |
| Pau   | Imprimante | 94       | 0          | 0 %      | 141,5           |
| Pau   | Écran      | 88       | 0          | 0 %      | 135             |

> **Note :** Le taux "en service" à 0 % reflète le fait que le générateur de données a peuplé le statut `affecte` comme sous-catégorie distincte de `en_service`. Les matériels sont bien répartis entre les statuts `disponible`, `affecte`, `maintenance` et `hors_service` (cf. résultats P2-1). Cela pourrait être corrigé en alignant le libellé du statut dans le générateur.

---

## 5. Analyse globale et conclusions

### Gains principaux mesurés

| Dimension | Résultat |
|-----------|----------|
| Réduction de coût requête la plus critique (CAS 1) | **×23 600** (de 426 000 à 18) |
| Réduction de temps sur l'inventaire matériel | **×8,5** (340 ms → 40 ms) |
| Élimination du MERGE JOIN CARTESIAN | ✅ |
| Plans stabilisés sur requêtes tickets | ✅ (même coût, temps réduit) |
| Enrichissement fonctionnel réseau (IP range) | ✅ |
| Fragmentation BDDR validée | ✅ |
| Réplication des tables de référence | ✅ |

### Limites et perspectives

- À la volumétrie actuelle (1 200–5 000 lignes), les index de FK n'apportent pas encore de différence spectaculaire sur certaines requêtes. Le bénéfice devient significatif au-delà de 100 000 lignes.
- Le taux d'utilisation (BDDR-6) nécessite un alignement des valeurs du statut dans le générateur (`en_service` vs `affecte`).
- Des index composites sur `(id_site, statut)` dans MATERIEL et `(id_site, statut_ticket)` dans TICKET constitueraient la prochaine optimisation à valider par benchmark.
- La stratégie de réplication asynchrone des tables de référence devra être éprouvée sur un vrai environnement multi-nœuds Oracle (Database Link / Streams).