-- ============================================================================
--  Mini-projet GLPI — CY Tech (Cergy / Pau)
--  Auteur·rice : Fatima
--  Fichier     : baseline_queries.sql
--
--  Objectif :
--    Définir 5 requêtes représentatives des flux métiers les plus fréquents
--    sur la base GLPI ACTUELLE (As-Is). Elles seront exécutées :
--      1) sur la base existante (MySQL/MariaDB) en l'état,
--      2) sur la nouvelle base refondue (Oracle, multi-sites BDDR),
--    afin de comparer les temps de réponse et de valider les gains.
--
--  Mode d'emploi :
--    - Sur MySQL/MariaDB : utiliser EXPLAIN puis SHOW PROFILES;
--    - Sur Oracle       : utiliser EXPLAIN PLAN FOR + DBMS_XPLAN.DISPLAY,
--                         et SET TIMING ON pour mesurer les temps.
--
--  Notes :
--    - Toutes les requêtes ajoutent le filtre is_deleted = 0 (soft delete GLPI).
--    - Pour les tests, remplacer les paramètres :site_id, :user_id, etc.
--      par des valeurs réelles ou utiliser des variables de session.
-- ============================================================================


-- ============================================================================
-- REQUÊTE Q1 — Inventaire matériel d'un site (flux F1 du reverse engineering)
-- ----------------------------------------------------------------------------
--  Objectif métier :
--    "Lister tous les matériels (PC, écrans, imprimantes, téléphones,
--     périphériques, équipements réseau) d'un site donné, avec leur statut
--     et leur localisation."
--
--  Pourquoi cette requête est représentative :
--    Démontre le coût de l'éclatement "une table par type d'actif" :
--    obligation de faire un UNION ALL de 6 SELECT pour reconstituer
--    une simple liste de matériels.
--
--  Points de mesure attendus :
--    - 6 accès séquentiels aux tables d'actifs,
--    - 6 jointures vers glpi_locations,
--    - tri global sur l'UNION (table temporaire).
-- ============================================================================
EXPLAIN
SELECT 'Computer' AS type_actif,
       c.id, c.name, c.serial, c.states_id,
       l.name AS localisation
FROM   glpi_computers c
LEFT   JOIN glpi_locations l ON l.id = c.locations_id
WHERE  c.entities_id = :site_id
  AND  c.is_deleted = 0
UNION ALL
SELECT 'Monitor',
       m.id, m.name, m.serial, m.states_id,
       l.name
FROM   glpi_monitors m
LEFT   JOIN glpi_locations l ON l.id = m.locations_id
WHERE  m.entities_id = :site_id
  AND  m.is_deleted = 0
UNION ALL
SELECT 'Printer',
       p.id, p.name, p.serial, p.states_id,
       l.name
FROM   glpi_printers p
LEFT   JOIN glpi_locations l ON l.id = p.locations_id
WHERE  p.entities_id = :site_id
  AND  p.is_deleted = 0
UNION ALL
SELECT 'Phone',
       ph.id, ph.name, ph.serial, ph.states_id,
       l.name
FROM   glpi_phones ph
LEFT   JOIN glpi_locations l ON l.id = ph.locations_id
WHERE  ph.entities_id = :site_id
  AND  ph.is_deleted = 0
UNION ALL
SELECT 'Peripheral',
       pe.id, pe.name, pe.serial, pe.states_id,
       l.name
FROM   glpi_peripherals pe
LEFT   JOIN glpi_locations l ON l.id = pe.locations_id
WHERE  pe.entities_id = :site_id
  AND  pe.is_deleted = 0
UNION ALL
SELECT 'NetworkEquipment',
       ne.id, ne.name, ne.serial, ne.states_id,
       l.name
FROM   glpi_networkequipments ne
LEFT   JOIN glpi_locations l ON l.id = ne.locations_id
WHERE  ne.entities_id = :site_id
  AND  ne.is_deleted = 0
ORDER  BY type_actif, name;


-- ============================================================================
-- REQUÊTE Q2 — Recherche d'un matériel par numéro de série (flux F2)
-- ----------------------------------------------------------------------------
--  Objectif métier :
--    "Un technicien scanne un numéro de série et veut savoir ce que c'est,
--     où il est, et qui l'a en charge."
--
--  Pourquoi cette requête est représentative :
--    - colonne `serial` souvent non indexée → full scan sur chaque table,
--    - 6 tables à interroger (encore le coût de la fragmentation par type),
--    - obligation de joindre vers glpi_users (technicien) et glpi_locations.
--
--  Points de mesure attendus :
--    - Full scan attendu sur les 6 tables sans index sur `serial`,
--    - amélioration majeure attendue dans le To-Be (1 seule table indexée).
-- ============================================================================
EXPLAIN
SELECT t.type_actif, t.id, t.name, t.serial,
       u.name  AS technicien,
       l.name  AS localisation,
       s.name  AS statut
FROM (
        SELECT 'Computer' AS type_actif, id, name, serial,
               users_id_tech, locations_id, states_id
        FROM   glpi_computers
        WHERE  is_deleted = 0
        UNION ALL
        SELECT 'Monitor',  id, name, serial,
               users_id_tech, locations_id, states_id
        FROM   glpi_monitors
        WHERE  is_deleted = 0
        UNION ALL
        SELECT 'Printer',  id, name, serial,
               users_id_tech, locations_id, states_id
        FROM   glpi_printers
        WHERE  is_deleted = 0
        UNION ALL
        SELECT 'Phone',    id, name, serial,
               NULL, locations_id, states_id
        FROM   glpi_phones
        WHERE  is_deleted = 0
        UNION ALL
        SELECT 'Peripheral', id, name, serial,
               NULL, locations_id, states_id
        FROM   glpi_peripherals
        WHERE  is_deleted = 0
        UNION ALL
        SELECT 'NetworkEquipment', id, name, serial,
               NULL, locations_id, states_id
        FROM   glpi_networkequipments
        WHERE  is_deleted = 0
     ) t
LEFT  JOIN glpi_users     u ON u.id = t.users_id_tech
LEFT  JOIN glpi_locations l ON l.id = t.locations_id
LEFT  JOIN glpi_states    s ON s.id = t.states_id
WHERE t.serial = :serial_recherche;


-- ============================================================================
-- REQUÊTE Q3 — Cartographie réseau d'un site (flux F4)
-- ----------------------------------------------------------------------------
--  Objectif métier :
--    "Pour le site Cergy, lister tous les équipements connectés au réseau
--     avec leur VLAN, leur sous-réseau IP, leur adresse IP et l'équipement
--     porteur du port (PC, switch, imprimante...)."
--
--  Pourquoi cette requête est représentative :
--    - met en scène la cascade polymorphique
--      IPAddress → NetworkName → NetworkPort → (Computer | NetworkEquipment | Printer)
--    - chaîne de jointures avec itemtype + items_id, sans FK SQL,
--    - filtres sur 3 tables d'entité multi-tenant.
--
--  Points de mesure attendus :
--    - jointures imbriquées coûteuses (estimation OPTIMIZER quasi nulle),
--    - prédicat sur `itemtype` faiblement sélectif,
--    - gain attendu énorme dans le To-Be (FK SQL strictes + index dédiés).
-- ============================================================================
EXPLAIN
SELECT vl.name             AS vlan,
       ipn.name            AS sous_reseau,
       CONCAT(ipn.address, '/', ipn.netmask) AS cidr,  -- MySQL ; Oracle : ||
       ip.name             AS adresse_ip,
       nn.name             AS dns,
       np.name             AS port,
       np.mac              AS mac,
       np.itemtype         AS type_equipement,
       CASE np.itemtype
         WHEN 'Computer'         THEN (SELECT name FROM glpi_computers         WHERE id = np.items_id)
         WHEN 'NetworkEquipment' THEN (SELECT name FROM glpi_networkequipments WHERE id = np.items_id)
         WHEN 'Printer'          THEN (SELECT name FROM glpi_printers          WHERE id = np.items_id)
       END                 AS nom_equipement
FROM   glpi_networkports np
JOIN   glpi_networknames  nn  ON nn.itemtype = 'NetworkPort'
                              AND nn.items_id  = np.id
                              AND nn.is_deleted = 0
JOIN   glpi_ipaddresses   ip  ON ip.itemtype = 'NetworkName'
                              AND ip.items_id  = nn.id
                              AND ip.is_deleted = 0
JOIN   glpi_ipaddresses_ipnetworks  rel ON rel.ipaddresses_id = ip.id
JOIN   glpi_ipnetworks    ipn ON ipn.id = rel.ipnetworks_id
LEFT   JOIN glpi_vlans    vl  ON vl.entities_id = ipn.entities_id
WHERE  np.entities_id = :site_id
  AND  np.is_deleted = 0
ORDER  BY vlan, sous_reseau, adresse_ip;


-- ============================================================================
-- REQUÊTE Q4 — Droits effectifs d'un utilisateur sur une entité (flux F5)
-- ----------------------------------------------------------------------------
--  Objectif métier :
--    "Pour l'utilisateur 'jdupont' sur le site Pau, lister toutes les
--     permissions effectives (héritées des profils + groupes)."
--
--  Pourquoi cette requête est représentative :
--    - met en jeu la chaîne RBAC complète : users → profiles_users
--      → profiles → profilerights, avec une dimension entité,
--    - démontre la profondeur de la jointure pour répondre à une question
--      pourtant simple : "qu'a-t-il le droit de faire ?".
--
--  Points de mesure attendus :
--    - jointures sur ~5 tables avec filtres entité,
--    - dans le To-Be : table role_permission directe + index → 2 joins max.
-- ============================================================================
EXPLAIN
SELECT u.id              AS user_id,
       u.name            AS login,
       p.name            AS profil,
       e.name            AS entite,
       pr.name           AS permission_name,
       pr.rights         AS bitmask_droits,
       pu.is_recursive
FROM   glpi_users          u
JOIN   glpi_profiles_users pu ON pu.users_id = u.id
JOIN   glpi_profiles       p  ON p.id        = pu.profiles_id
JOIN   glpi_entities       e  ON e.id        = pu.entities_id
LEFT   JOIN glpi_profilerights pr ON pr.profiles_id = p.id
WHERE  u.name        = :login_utilisateur
  AND  u.is_deleted  = 0
  AND  u.is_active   = 1
  AND  e.name        = :nom_site            -- ex: 'CY Tech Pau'
ORDER  BY p.name, pr.name;


-- ============================================================================
-- REQUÊTE Q5 — Statistiques globales : matériels par type et par site (flux F6)
-- ----------------------------------------------------------------------------
--  Objectif métier :
--    "Tableau de bord : combien de matériels de chaque type sur chaque site,
--     dont combien en service / en maintenance / hors service ?"
--
--  Pourquoi cette requête est représentative :
--    - agrégat transverse sur les 6 tables d'actifs,
--    - couplé à un filtre fonctionnel (statut),
--    - typiquement le genre de requête où une vue matérialisée
--      apportera un gain énorme dans le To-Be.
--
--  Points de mesure attendus :
--    - 6 GROUP BY puis agrégation finale,
--    - sans index sur (entities_id, states_id) → mauvais plan,
--    - To-Be : 1 GROUP BY sur la table materiel partitionnée par site.
-- ============================================================================
EXPLAIN
SELECT type_actif,
       e.name AS site,
       s.name AS statut,
       COUNT(*) AS nb
FROM (
        SELECT 'Computer'   AS type_actif, entities_id, states_id FROM glpi_computers         WHERE is_deleted = 0
        UNION ALL
        SELECT 'Monitor',          entities_id, states_id        FROM glpi_monitors          WHERE is_deleted = 0
        UNION ALL
        SELECT 'Printer',          entities_id, states_id        FROM glpi_printers          WHERE is_deleted = 0
        UNION ALL
        SELECT 'Phone',            entities_id, states_id        FROM glpi_phones            WHERE is_deleted = 0
        UNION ALL
        SELECT 'Peripheral',       entities_id, states_id        FROM glpi_peripherals       WHERE is_deleted = 0
        UNION ALL
        SELECT 'NetworkEquipment', entities_id, states_id        FROM glpi_networkequipments WHERE is_deleted = 0
     ) t
JOIN  glpi_entities e ON e.id = t.entities_id
LEFT  JOIN glpi_states s ON s.id = t.states_id
GROUP BY type_actif, e.name, s.name
ORDER BY e.name, type_actif, s.name;


-- ============================================================================
-- PROTOCOLE DE BENCHMARK
-- ----------------------------------------------------------------------------
-- 1. Charger le jeu de test conséquent (PL/SQL côté To-Be, dump généré pour
--    l'As-Is) : ~3000 PC, ~3000 écrans, ~300 imprimantes, ~5000 utilisateurs,
--    répartis 50/50 entre Cergy et Pau.
--
-- 2. Vider le cache avant chaque mesure :
--      MySQL/MariaDB :  RESET QUERY CACHE;  FLUSH TABLES;
--      Oracle        :  ALTER SYSTEM FLUSH BUFFER_CACHE;
--                       ALTER SYSTEM FLUSH SHARED_POOL;
--
-- 3. Exécuter chaque requête 5 fois, conserver la médiane des temps.
--
-- 4. Pour chaque requête, capturer :
--      - le temps d'exécution (SET TIMING ON / SHOW PROFILES),
--      - le plan d'exécution (EXPLAIN PLAN / EXPLAIN ANALYZE),
--      - le nombre de lectures logiques (consistent gets / Handler_read_*).
--
-- 5. Rejouer les mêmes requêtes (réécrites avec le nouveau schéma) sur la
--    base To-Be Oracle, et comparer dans le rapport sous forme de graphiques.
-- ============================================================================
