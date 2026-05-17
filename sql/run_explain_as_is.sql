-- ============================================================================
--  Exécution des EXPLAIN sur la base GLPI As-Is (MySQL/MariaDB)
--  Prérequis : schéma chargé depuis ancienne_base/glpi-11.0.7-empty.sql
--  Usage     : mysql glpi_asis < sql/run_explain_as_is.sql
-- ============================================================================

SET NAMES utf8mb4;

SELECT '========== Q1 — Inventaire matériel par site (entities_id = 0) ==========' AS '';
EXPLAIN
SELECT 'Computer' AS type_actif,
       c.id, c.name, c.serial, c.states_id,
       l.name AS localisation
FROM   glpi_computers c
LEFT   JOIN glpi_locations l ON l.id = c.locations_id
WHERE  c.entities_id = 0
  AND  c.is_deleted = 0
UNION ALL
SELECT 'Monitor',
       m.id, m.name, m.serial, m.states_id,
       l.name
FROM   glpi_monitors m
LEFT   JOIN glpi_locations l ON l.id = m.locations_id
WHERE  m.entities_id = 0
  AND  m.is_deleted = 0
UNION ALL
SELECT 'Printer',
       p.id, p.name, p.serial, p.states_id,
       l.name
FROM   glpi_printers p
LEFT   JOIN glpi_locations l ON l.id = p.locations_id
WHERE  p.entities_id = 0
  AND  p.is_deleted = 0
UNION ALL
SELECT 'Phone',
       ph.id, ph.name, ph.serial, ph.states_id,
       l.name
FROM   glpi_phones ph
LEFT   JOIN glpi_locations l ON l.id = ph.locations_id
WHERE  ph.entities_id = 0
  AND  ph.is_deleted = 0
UNION ALL
SELECT 'Peripheral',
       pe.id, pe.name, pe.serial, pe.states_id,
       l.name
FROM   glpi_peripherals pe
LEFT   JOIN glpi_locations l ON l.id = pe.locations_id
WHERE  pe.entities_id = 0
  AND  pe.is_deleted = 0
UNION ALL
SELECT 'NetworkEquipment',
       ne.id, ne.name, ne.serial, ne.states_id,
       l.name
FROM   glpi_networkequipments ne
LEFT   JOIN glpi_locations l ON l.id = ne.locations_id
WHERE  ne.entities_id = 0
  AND  ne.is_deleted = 0
ORDER  BY type_actif, name\G

SELECT '========== Q2 — Recherche par numéro de série ==========' AS '';
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
WHERE t.serial = 'SN-DEMO-0001'\G

SELECT '========== Q3 — Cartographie réseau (entities_id = 0) ==========' AS '';
EXPLAIN
SELECT vl.name             AS vlan,
       ipn.name            AS sous_reseau,
       CONCAT(ipn.address, '/', ipn.netmask) AS cidr,
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
WHERE  np.entities_id = 0
  AND  np.is_deleted = 0
ORDER  BY vlan, sous_reseau, adresse_ip\G

SELECT '========== Q4 — Droits effectifs utilisateur × entité ==========' AS '';
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
WHERE  u.name        = 'glpi'
  AND  u.is_deleted  = 0
  AND  u.is_active   = 1
  AND  e.name        = 'Root entity'
ORDER  BY p.name, pr.name\G

SELECT '========== Q5 — Statistiques matériels par type / site / statut ==========' AS '';
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
ORDER BY e.name, type_actif, s.name\G
