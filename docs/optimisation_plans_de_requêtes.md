**Contexte :** Projet GLPI Multi-sites (CY Tech - Ing2)  
**Objectif :** Valider l'architecture répartie et démontrer l'optimisation des temps de réponse à l'aide des plans d'exécution Oracle (Cost-Based Optimizer).

## 1. Introduction et Démarche d'Analyse

Dans le cadre d'une architecture de Base de Données Répartie (BDDR), l'analyse des plans de requêtes est essentielle pour s'assurer que le moteur d'optimisation d'Oracle prend les bonnes décisions de routage réseau et d'accès aux données.

Cette documentation présente l'analyse d'une requête de "crash-test" globale unissant les données locales (répliquées) et distantes (fragmentées) afin d'évaluer le comportement de l'optimiseur après l'injection d'un jeu de données conséquent et la génération complète des statistiques de schéma.


## 2. Requête SQL Analysée

La requête cible effectue une jointure complexe entre trois entités stratégiques du modèle :
* Les **Tickets** (fragmentés horizontalement entre Cergy et Pau)
* Les **Utilisateurs** (fragmentés horizontalement entre Cergy et Pau)
* Les **Sites** (données de référence répliquées localement)

```sql
EXPLAIN PLAN FOR 
SELECT t.id, t.titre, u.nom, s.nom AS Site_Nom
FROM V_ALL_TICKETS t
JOIN V_ALL_UTILISATEURS u ON t.id_utilisateur = u.id AND t.id_site = u.id_site
JOIN Site s ON t.id_site = s.id_site;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);
```

## 3. Plan d'Exécution Global (CYGLPI_HUB)

Voici la trace textuelle exacte générée par l'optimiseur d'Oracle (Plan hash value : 4281482087) pour l'analyse de nos requêtes distribuées:

```text
---------------------------------------------------------------------------
| Id  | Operation                     | Name               | Rows  | Bytes
---------------------------------------------------------------------------
|   0 | SELECT STATEMENT              |                    |     1 |    38
|   1 |  NESTED LOOPS                 |                    |     1 |    38
|   2 |   NESTED LOOPS                |                    |     1 |    23
|   3 |    VIEW                       | V_ALL_TICKETS      |   164 |  2755
|   4 |     UNION-ALL                 |                    |       |
|   5 |      REMOTE                   | TICKET             |    82 |  1377
|   6 |      REMOTE                   | TICKET             |    82 |  1377
|   7 |    TABLE ACCESS BY INDEX ROWID| SITE               |     1 |     6
|* 8 |     INDEX UNIQUE SCAN         | SYS_C008303        |     1 |      
|* 9 |   VIEW                        | V_ALL_UTILISATEURS |     9 |   139
|  10 |    UNION-ALL PARTITION        |                    |       |
|  11 |     REMOTE                    | UTILISATEUR        |     1 |    15
|  12 |     REMOTE                    | UTILISATEUR        |     1 |    15
---------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------
   8 - access("T"."ID_SITE"="S"."ID_SITE")
   9 - filter("T"."ID_SITE"="U"."ID_SITE")

Remote SQL Information (identified by operation id):
---------------------------------------------------
   5 - SELECT "ID","TITRE","ID_UTILISATEUR","ID_SITE" FROM "TICKET" "TICK...
   6 - SELECT "ID","TITRE","ID_UTILISATEUR","ID_SITE" FROM "TICKET" "TICK...
  11 - SELECT /*+ INDEX ("UTILISATEUR") */ "ID","NOM","ID_SITE" FROM "UTI...
       "ID"=:1 (accessing 'CERGY_LINK' )
  12 - SELECT /*+ INDEX ("UTILISATEUR") */ "ID","NOM","ID_SITE" FROM "UTI...
       "ID"=:1 (accessing 'PAU_LINK' )

```
## 4. Analyse du Plan d'Exécution
### 4.1. Vue d'Ensemble
Le plan d'exécution révèle une stratégie de jointure en "Nested Loops" (boucles imbriquées) pour combiner les données des tickets, utilisateurs et sites. L'optimiseur a choisi d'exécuter les opérations de manière séquentielle, en commençant par les tickets, puis en joignant les utilisateurs et enfin les sites.
### A. Validation de la Fragmentation Horizontale (Lignes 3 à 6)
L'optimiseur commence par matérialiser la vue `V_ALL_TICKETS` (Ligne 3).
* **L'opération UNION-ALL** (Ligne 4) confirme que le moteur consolide les fragments horizontaux issus des deux sites distants.
* **Les opérations REMOTE** (Lignes 5 et 6) prouvent que le HUB délègue l'extraction des lignes aux serveurs distants en estimant précisément un volume de **82 lignes par site** (grâce aux statistiques à jour calculées via `DBMS_STATS`).

### B. Optimisation de l'Accès Répliqué (Lignes 7 et 8)
* L'opération `TABLE ACCESS BY INDEX ROWID` sur la table `SITE` s'effectue sans aucune mention `REMOTE`. Cela valide notre choix de **réplication des tables de référence** : l'accès aux métadonnées des sites se fait localement sur le HUB.
* L'utilisation d'un `INDEX UNIQUE SCAN` (Ligne 8) sur l'index de clé primaire automatique (`SYS_C008303`) garantit un accès direct en complexité $\mathcal{O}(1)$, minimisant le coût de calcul local.

### C. Jointures Distribuées Avancées (Lignes 1, 2, 9 à 12)
Le choix de l'algorithme de jointure par l'optimiseur met en lumière un comportement distribué extrêmement intelligent :
* Au lieu de rapatrier aveuglément l'intégralité de la table `UTILISATEUR` depuis les deux sites (ce qui saturerait la bande passante réseau), Oracle utilise un mécanisme de **Nested Loops distribué**.
* **Le pousser de prédicat (Predicate Pushdown)** : Dans la section *Remote SQL Information* (Lignes 11 et 12), on observe qu'Oracle injecte une variable de liaison (`"ID"=:1`). Le HUB transmet l'ID de l'utilisateur extrait du ticket directement aux fragments distants.
* **L'injection de "Hint" d'index** : Les requêtes distantes exécutent un avertissement d'optimisation automatique `/*+ INDEX ("UTILISATEUR") */`. Les sites distants exploitent ainsi immédiatement leurs index locaux de clé primaire pour renvoyer uniquement la ligne correspondante au HUB via `CERGY_LINK` et `PAU_LINK`.

## 5. Analyse Comparative : Local vs Global
Pour valider l'impact de la répartition, deux tests de performance ont été menés en parallèle :

| Métrique / Comportement | Requête Globale Consolidated (HUB) | Requête Locale Directe (CERGY_SITE) |
| :--- | :--- | :--- |
| **Opérations Réseau** | `REMOTE via DB Links` requis | Traitement 100% Local (0 réseau) |
| **Algorithme d'accès** | `UNION-ALL` + Pousser de prédicats | `INDEX RANGE/UNIQUE SCAN` direct |
| **Coût Oracle (Cost)** | Modéré (Inclusion du coût de transport réseau) | Très Faible (Optimisation maximale sur disque local) |

# 6. Conclusion
Ce test valide l'ensemble des critères d'évaluation du rôle de **Membre 4** :
* **Preuve de la Localisation des Données** : Les informations opérationnelles lourdes (`TICKET`) restent sur leurs sites d'origine (Cergy/Pau) et ne transitent par le réseau que lorsque c'est strictement nécessaire.
* **Efficacité de la Réplication** : La table `SITE` sert de point d'ancrage local pour éviter les goulets d'étranglement réseaux (pas d'opérations inter-sites pour cette entité).
* **Mise à jour des Statistiques** : L'optimiseur évalue le coût sur des volumes réels (164 tickets au total, soit 82 par site) et applique un algorithme de *Nested Loops* adapté plutôt qu'un lourd *Full Table Scan*.

Cette comparaison démontre que pour les opérations courantes de maintenance ou de gestion des tickets d'un site spécifique, les performances sont maximales en interrogeant directement le fragment local (Cergy ou Pau). La centralisation sur le HUB via les vues globales est à réserver aux besoins décisionnels ou de supervision globale par les administrateurs du parc informatique de **CY Tech**.

