# Stratégie BDDR — Cergy / Pau

> **Responsable :** Inès — BDDR multi-sites & optimisation des requêtes  
> **Complément :** `docs/Strategie.md` (justification détaillée fragmentation / réplication)  
> **Scripts :** répertoire `bddr/` · installation : `install_bddr.sql`

---

## 1. Objectif BDDR

Simuler une base **répartie** entre deux campus CY Tech :

| Schéma Oracle | Rôle |
|---------------|------|
| `CYGLPI_HUB` | Nœud central : référentiels partagés + vues globales `V_ALL_*` |
| `CERGY_SITE` | Données opérationnelles du site Cergy (`id_site = 1`) |
| `PAU_SITE` | Données opérationnelles du site Pau (`id_site = 2`) |

**Mécanismes :** fragmentation horizontale par site, `DATABASE LINK`, vues `UNION ALL`, vues matérialisées pour la réplication des tables de référence.

---

## 2. Architecture (inchangée dans le principe)

```
                    CYGLPI_HUB
              (Site, Role, Permission,
               V_ALL_MATERIELS, V_ALL_TICKETS, …)
                    /         \
            cergy_link       pau_link
                  /               \
          CERGY_SITE           PAU_SITE
     (Materiel, Utilisateur,   (même schéma,
      Ticket, Reseau, …)       id_site = 2)
```

### Fragmentation horizontale

Chaque site ne stocke que **ses** lignes (filtre `id_site` ou défaut à la création) :

`Utilisateur`, `Materiel`, `Affectation`, `Ticket`, `Batiment`, `Salle`, `Reseau`, `EquipementReseau`.

### Réplication

- **Maître (HUB) :** `Site`, `Role`, `Permission`, `RolePermission`
- **Esclaves (sites) :** `MV_Site`, `MV_Role`, `MV_Permission`, `MV_RolePermission` (rafraîchissement `ON DEMAND`)

---

## 3. Tableau avant / après — fichier par fichier

Légende : **Réorg.** = découpage / clarification ; **Modèle** = alignement colonnes avec `sql/tables.sql` ; **Install** = procédure d’exécution.

| Fichier | Version initiale (équipe) | Version actuelle | Nature du changement |
|---------|---------------------------|------------------|----------------------|
| **`01_Creation_utilisateurs_et_privileges.sql`** | Création `CYGLPI_HUB`, `CERGY_SITE`, `PAU_SITE` + grants | **Identique** (contenu conservé) | Inchangé — toujours exécuté en **SYSDBA** dans le PDB |
| **`02_Creation_database_link.sql`** | DB links `cergy_link`, `pau_link` vers `XEPDB1` **en dur** + requêtes `SELECT` de test en fin de fichier | Links vers `&pdb_service` (`00_service_name.sql`) ; tests retirés du script | **Réorg.** + compatibilité **ORCLPDB1** / **XEPDB1** |
| **`03_Distribution.sql`** | **Un seul gros fichier** : DDL Cergy + DDL Pau + vues HUB `V_ALL_*` | Redirige vers `03_hub_views.sql` (rétrocompatibilité) | **Réorg.** — logique des vues conservée |
| **`03_site_schema.sql`** | *(n’existait pas)* — tout était dans `03_Distribution.sql` | DDL des tables **CERGY_SITE** aligné `tables.sql` | **Nouveau** + **Modèle** |
| **`03_pau_site_schema.sql`** | *(idem, section Pau mélangée)* | DDL **PAU_SITE** (`DEFAULT id_site = 2`) | **Nouveau** + **Modèle** |
| **`03_hub_views.sql`** | Vues `V_ALL_*` en bas de `03_Distribution.sql` | Fichier dédié : `UNION ALL` via `@cergy_link` / `@pau_link` | **Réorg.** |
| **`04_Replication.sql`** | **Un fichier** : tables maîtres HUB **et** MV sur les sites ; `Site(id_site, nom)` | Redirige vers `04_hub_master.sql` | **Réorg.** |
| **`04_hub_master.sql`** | *(partie HUB dans `04_Replication.sql`)* | Tables maîtres : `Site(id, nom, ville)`, `Role`, `Permission`, `RolePermission` + données initiales | **Nouveau** + **Modèle** (aligné hub applicatif) |
| **`04_site_mviews.sql`** | MV nommées `Site`, `Role`, … (même nom que tables → confusion) | MV **`MV_Site`**, `MV_Role`, … + `hub_link` configurable | **Nouveau** + **Modèle** + clarté nommage |
| **`04b_Replication_Refresh.sql`** | `REFRESH` sur `Site`, `Role`, … | `REFRESH` sur **`MV_Site`**, `MV_Role`, … | **Modèle** (noms MV) |
| **`Verifications_Setup.sql`** | Vérifications avec colonnes `id_ticket`, `id_utilisateur`, table `Site` sur site | Requêtes sur `MV_*`, jointures avec `id` / `id_materiel` cohérents | **Modèle** + corrections |
| **`00_service_name.sql`** | — | `DEFINE pdb_service = 'ORCLPDB1'` (ou `XEPDB1`) | **Nouveau** — multi-environnement |
| **`05_seed_sites_demo.sql`** | — | Jeu minimal (1 PC Cergy, 1 user) pour tester `V_ALL_*` | **Nouveau** — démo / soutenance |
| **`install.sql` (racine)** | Enchaînait **tout** dont `bddr/01` en user `cyglpi` | BDDR **retiré** → voir `install_bddr.sql` | **Install** — évite `ORA-` sur CREATE USER |
| **`install_bddr.sql`** | — | Procédure **étapes A → G** (SYSDBA, par schéma) | **Nouveau** — guide d’installation |

---

## 4. Changement majeur : unification du modèle de données

### Avant (schéma BDDR isolé)

Exemples de colonnes sur les sites :

| Table | Ancien nom PK / colonnes | Schéma central `tables.sql` |
|-------|--------------------------|-----------------------------|
| `Materiel` | `id_materiel` | `id` |
| `Utilisateur` | `id_utilisateur` | `id` |
| `Ticket` | `id_ticket`, `titre`, `id_site` sur ticket | `id`, `description`, pas de `id_site` sur ticket |
| `Site` (réplication) | `id_site` | `id`, `ville` |

→ Les vues `V_ALL_*` et le générateur central (`cyglpi`) parlaient **deux langages** différents.

### Après (schéma unifié)

Les tables `CERGY_SITE` / `PAU_SITE` reprennent les **mêmes noms de colonnes** que `sql/tables.sql` (`id`, `id_site`, `numero_serie`, `statut`, `vlan`, `priorite`, etc.).

**Bénéfices :**

- Requêtes et vues HUB lisibles par toute l’équipe ;
- `Verifications_Setup.sql` cohérent ;
- Documentation / UML / DDL central alignés.

**Limite assumée :** le peuplement massif (`plsql/data_generator.sql`) reste sur le schéma **`cyglpi`** ; le BDDR est structuré + `05_seed_sites_demo.sql` pour valider les liens. Un chargement distribué complet reste une évolution possible.

---

## 5. Ce qui n’a **pas** changé (contribution BDDR)

- Choix **3 schémas** + séparation référentiel / opérationnel ;
- **Fragmentation** des tables métier par site ;
- **Réplication** des référentiels via vues matérialisées ;
- **Transparence** pour l’admin via `V_ALL_MATERIELS`, `V_ALL_TICKETS`, etc. ;
- Argumentaire dans `docs/Strategie.md` (perf locale, réduction trafic réseau, cohérence).

---

## 6. Procédure d’installation BDDR

Prérequis : `install.sql` exécuté sur le schéma applicatif **`cyglpi`**.

| Étape | Connexion | Script |
|-------|-----------|--------|
| A | `SYSDBA` → PDB | `bddr/01_Creation_utilisateurs_et_privileges.sql` |
| B | — | Adapter `bddr/00_service_name.sql` (`ORCLPDB1` ou `XEPDB1`) |
| C | `CERGY_SITE` | `bddr/03_site_schema.sql` |
| D | `PAU_SITE` | `bddr/03_pau_site_schema.sql` |
| E | `CYGLPI_HUB` | `00_service_name.sql` → `04_hub_master.sql` → `02_Creation_database_link.sql` → `03_hub_views.sql` |
| E bis | `CERGY_SITE` + `PAU_SITE` | `bddr/04_site_mviews.sql` (sur chaque site) |
| F | Chaque site | `bddr/05_seed_sites_demo.sql` (optionnel) |
| G | Cergy + Pau | `bddr/04b_Replication_Refresh.sql` |
| — | `CYGLPI_HUB` | `bddr/Verifications_Setup.sql` |

Récapitulatif : `@/opt/GLPI_BDD/install_bddr.sql` (commentaires détaillés).

---

## 7. Exemple de requête consolidée (HUB)

```sql
-- Parc matériel total par site (vue distribuée)
SELECT id_site, type, COUNT(*) AS nb
FROM V_ALL_MATERIELS
GROUP BY id_site, type
ORDER BY id_site;
```

---

## 8. Synthèse pour le rapport / soutenance

| Question | Réponse courte |
|----------|----------------|
| La stratégie BDDR a-t-elle changé ? | **Non** sur le fond (hub, fragmentation, réplication, vues globales). |
| Les scripts ont-ils seulement été découpés ? | **Non** — découpage **+** alignement du modèle **+** installation corrigée. |
| Pourquoi ? | Cohérence avec Marjorie (`tables.sql`), install multi-Oracle, démo vérifiable. |
| Fichier à citer en soutenance | `docs/Strategie.md` (texte) + ce document (mapping technique). |

---

*Dernière mise à jour : alignement avec la refonte homogène du dépôt GLPI_BDD (2026).*
