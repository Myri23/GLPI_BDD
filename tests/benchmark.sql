-- =============================================================================
-- FICHIER  : tests/benchmark.sql
-- OBJET    : Protocole complet de benchmark en 3 parties :
--            PARTIE 1 : Ancienne base GLPI  vs  Nouvelle base CY Tech
--            PARTIE 2 : Nouvelle base SANS index  vs  AVEC index
--            PARTIE 3 : Requetes BDDR multi-sites (Cergy / Pau)
-- =============================================================================
-- AVANT DE LANCER CE SCRIPT :
--   1. Dans le terminal :
--        docker cp . oracle21xe:/opt/GLPI_BDD  #se mettre a la racine du projet
--   2. Avoir execute tables.sql (nouvelle base + index)
--   3. Avoir execute data_generator.sql (jeu de donnees realiste)
--   4. Dans SQL*Plus :
--        @/opt/GLPI_BDD/tests/benchmark.sql
--   5. Dans le terminal :
--        docker cp oracle21xe:/tmp/resultats_benchmark.txt ./tests/
-- =============================================================================

SET TIMING ON
SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 220
SET PAGESIZE 80

SPOOL /tmp/resultats_benchmark.txt

-- =============================================================================
-- VOLUMETRIE DE LA BASE
-- =============================================================================

BEGIN
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE(' BENCHMARK GLPI CY Tech - Protocole de test de performance');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE('--- 1. Volumetrie de la base ---');
END;
/

SELECT table_name AS ENTITE, nb_lignes FROM (
    SELECT 'Site'             AS table_name, COUNT(*) AS nb_lignes FROM Site             UNION ALL
    SELECT 'Batiment',                       COUNT(*) FROM Batiment                      UNION ALL
    SELECT 'Salle',                          COUNT(*) FROM Salle                         UNION ALL
    SELECT 'Bureau',                         COUNT(*) FROM Bureau                        UNION ALL
    SELECT 'Role',                           COUNT(*) FROM Role                          UNION ALL
    SELECT 'Permission',                     COUNT(*) FROM Permission                    UNION ALL
    SELECT 'RolePermission',                 COUNT(*) FROM RolePermission                UNION ALL
    SELECT 'Utilisateur',                    COUNT(*) FROM Utilisateur                   UNION ALL
    SELECT 'Reseau',                         COUNT(*) FROM Reseau                        UNION ALL
    SELECT 'EquipementReseau',               COUNT(*) FROM EquipementReseau              UNION ALL
    SELECT 'Materiel',                       COUNT(*) FROM Materiel                      UNION ALL
    SELECT 'Affectation',                    COUNT(*) FROM Affectation                   UNION ALL
    SELECT 'Ticket',                         COUNT(*) FROM Ticket
) ORDER BY table_name;


-- =============================================================================
-- PARTIE 1 : ANCIENNE BASE GLPI vs NOUVELLE BASE CY Tech
-- =============================================================================
-- GLPI (glpi-11_0_7-empty.sql) est une base MySQL generique avec :
--   glpi_computers  : 28 colonnes, pas de site direct, statut code numerique
--   glpi_users      : 70+ colonnes, pas de role simplifie
--   glpi_tickets    : 50+ colonnes, utilisateurs dans table de liaison separee
--   glpi_locations  : site gere via hierarchie entities -> locations (3 jointures)
--   glpi_networks   : juste un nom, sans IP range ni lien direct aux equipements
--
-- Problemes identifies par le reverse engineering :
--   1. Acces au site d'un materiel : 3-4 jointures (computers->locations->entities)
--   2. Acces technicien d'un ticket : table de liaison glpi_tickets_users (type=2)
--   3. Pas de fragmentation multi-sites native
--   4. Gestion des roles via glpi_profiles (complexe, non normalise)
-- =============================================================================

BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE(' PARTIE 1 : ANCIENNE BASE GLPI vs NOUVELLE BASE CY Tech');
    DBMS_OUTPUT.PUT_LINE('============================================================');
END;
/

-- -----------------------------------------------------------
-- CAS 1 : Inventaire materiel par site
-- GLPI : glpi_computers JOIN glpi_locations JOIN glpi_entities (3 jointures)
--         + filtre sur champ texte, statut dans table separee glpi_states
-- Nouvelle base : Materiel JOIN Site (1 jointure directe, FK indexee)
-- -----------------------------------------------------------

BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('--- CAS 1A (LOGIQUE GLPI) : Inventaire materiel via sous-requete imbriquee ---');
    DBMS_OUTPUT.PUT_LINE('Simule : glpi_computers JOIN glpi_locations JOIN glpi_entities');
    DBMS_OUTPUT.PUT_LINE('         + sous-requete pour lier utilisateur via affectation');
END;
/

EXPLAIN PLAN FOR
SELECT m.id, m.nom, m.numero_serie, u.nom AS utilisateur, s.nom AS site
FROM   Materiel m
JOIN   Utilisateur u ON u.id = (
           SELECT a.id_utilisateur FROM Affectation a
           WHERE  a.id_materiel = m.id
             AND  a.date_fin IS NULL
             AND  ROWNUM = 1
       )
JOIN   Site s ON s.id = m.id_site
WHERE  s.ville = 'Cergy'
  AND  m.type  = 'PC';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +COST +ROWS'));

SELECT m.id, m.nom, m.numero_serie, u.nom AS utilisateur, s.nom AS site
FROM   Materiel m
JOIN   Utilisateur u ON u.id = (
           SELECT a.id_utilisateur FROM Affectation a
           WHERE  a.id_materiel = m.id
             AND  a.date_fin IS NULL
             AND  ROWNUM = 1
       )
JOIN   Site s ON s.id = m.id_site
WHERE  s.ville = 'Cergy'
  AND  m.type  = 'PC';

BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('--- CAS 1B (NOUVELLE BASE) : Inventaire materiel par site - jointures directes ---');
END;
/

EXPLAIN PLAN FOR
SELECT m.id, m.nom, m.numero_serie, m.statut,
       u.nom AS utilisateur, s.nom AS site
FROM   Materiel    m
JOIN   Affectation a ON a.id_materiel  = m.id AND a.date_fin IS NULL
JOIN   Utilisateur u ON u.id           = a.id_utilisateur
JOIN   Site        s ON s.id           = m.id_site
WHERE  s.ville = 'Cergy'
  AND  m.type  = 'PC';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +COST +ROWS'));

SELECT m.id, m.nom, m.numero_serie, m.statut,
       u.nom AS utilisateur, s.nom AS site
FROM   Materiel    m
JOIN   Affectation a ON a.id_materiel  = m.id AND a.date_fin IS NULL
JOIN   Utilisateur u ON u.id           = a.id_utilisateur
JOIN   Site        s ON s.id           = m.id_site
WHERE  s.ville = 'Cergy'
  AND  m.type  = 'PC';


-- -----------------------------------------------------------
-- CAS 2 : Tickets ouverts avec demandeur et technicien
-- GLPI : glpi_tickets + 2x glpi_tickets_users (type=1 et type=2) + 2x glpi_users
--         = 4 jointures dont 2 sur la meme table de liaison avec filtre
-- Nouvelle base : Ticket JOIN Utilisateur (x2) = 2 FK directes
-- -----------------------------------------------------------

BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('--- CAS 2A (LOGIQUE GLPI) : Tickets avec double table de liaison users ---');
    DBMS_OUTPUT.PUT_LINE('Simule : glpi_tickets JOIN glpi_tickets_users (type=1) JOIN glpi_tickets_users (type=2)');
END;
/

EXPLAIN PLAN FOR
WITH demandeurs AS (
    SELECT t.id AS ticket_id, u.nom AS nom_dem, u.id_site
    FROM   Ticket t JOIN Utilisateur u ON u.id = t.id_utilisateur
),
techniciens AS (
    SELECT t.id AS ticket_id, u.nom AS nom_tec
    FROM   Ticket t JOIN Utilisateur u ON u.id = t.id_technicien
)
SELECT d.ticket_id, d.nom_dem, tec.nom_tec,
       m.nom AS materiel, s.ville
FROM   demandeurs  d
JOIN   techniciens tec ON tec.ticket_id = d.ticket_id
JOIN   Ticket       t  ON t.id          = d.ticket_id
JOIN   Materiel     m  ON m.id          = t.id_materiel
JOIN   Site         s  ON s.id          = d.id_site
WHERE  t.statut IN ('ouvert', 'en_cours')
ORDER  BY t.date_creation DESC;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +COST +ROWS'));

WITH demandeurs AS (
    SELECT t.id AS ticket_id, u.nom AS nom_dem, u.id_site
    FROM   Ticket t JOIN Utilisateur u ON u.id = t.id_utilisateur
),
techniciens AS (
    SELECT t.id AS ticket_id, u.nom AS nom_tec
    FROM   Ticket t JOIN Utilisateur u ON u.id = t.id_technicien
)
SELECT d.ticket_id, d.nom_dem, tec.nom_tec,
       m.nom AS materiel, s.ville
FROM   demandeurs  d
JOIN   techniciens tec ON tec.ticket_id = d.ticket_id
JOIN   Ticket       t  ON t.id          = d.ticket_id
JOIN   Materiel     m  ON m.id          = t.id_materiel
JOIN   Site         s  ON s.id          = d.id_site
WHERE  t.statut IN ('ouvert', 'en_cours')
ORDER  BY t.date_creation DESC;

BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('--- CAS 2B (NOUVELLE BASE) : Tickets ouverts - FK directes optimisees ---');
END;
/

EXPLAIN PLAN FOR
SELECT t.id, t.statut, t.date_creation,
       u_dem.nom AS demandeur,
       u_tec.nom AS technicien,
       m.nom     AS materiel,
       s.ville   AS site
FROM   Ticket      t
JOIN   Utilisateur u_dem ON u_dem.id = t.id_utilisateur
JOIN   Utilisateur u_tec ON u_tec.id = t.id_technicien
JOIN   Materiel    m     ON m.id     = t.id_materiel
JOIN   Site        s     ON s.id     = m.id_site
WHERE  t.statut IN ('ouvert', 'en_cours')
ORDER  BY t.date_creation DESC;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +COST +ROWS'));

SELECT t.id, t.statut, t.date_creation,
       u_dem.nom AS demandeur,
       u_tec.nom AS technicien,
       m.nom     AS materiel,
       s.ville   AS site
FROM   Ticket      t
JOIN   Utilisateur u_dem ON u_dem.id = t.id_utilisateur
JOIN   Utilisateur u_tec ON u_tec.id = t.id_technicien
JOIN   Materiel    m     ON m.id     = t.id_materiel
JOIN   Site        s     ON s.id     = m.id_site
WHERE  t.statut IN ('ouvert', 'en_cours')
ORDER  BY t.date_creation DESC;


-- -----------------------------------------------------------
-- CAS 3 : Equipements reseau par site
-- GLPI : glpi_networkequipments -> locations_id -> glpi_locations -> entities_id
--         La table glpi_networks ne contient que le nom, sans IP range
-- Nouvelle base : EquipementReseau -> Reseau (ip_range inclus) -> Site
-- -----------------------------------------------------------

BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('--- CAS 3A (LOGIQUE GLPI) : Reseau via sous-requete hierarchique ---');
    DBMS_OUTPUT.PUT_LINE('Simule : glpi_networkequipments -> glpi_locations -> glpi_entities');
    DBMS_OUTPUT.PUT_LINE('         glpi_networks = juste un nom, pas d IP range directement');
END;
/

EXPLAIN PLAN FOR
SELECT er.nom AS equipement, er.type,
       r.ip_range, r.wan,
       s.ville
FROM   EquipementReseau er
JOIN   Reseau r ON r.id = er.id_reseau
JOIN   (SELECT id, ville FROM Site) s ON s.id = r.id_site
WHERE  er.type IN ('Serveur', 'Switch', 'Routeur')
ORDER  BY s.ville, er.type;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +COST +ROWS'));

SELECT er.nom AS equipement, er.type,
       r.ip_range, r.wan,
       s.ville
FROM   EquipementReseau er
JOIN   Reseau r ON r.id = er.id_reseau
JOIN   (SELECT id, ville FROM Site) s ON s.id = r.id_site
WHERE  er.type IN ('Serveur', 'Switch', 'Routeur')
ORDER  BY s.ville, er.type;

BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('--- CAS 3B (NOUVELLE BASE) : Reseau - jointure directe avec IP range ---');
END;
/

EXPLAIN PLAN FOR
SELECT s.ville, er.type,
       COUNT(*)          AS nb_equipements,
       MIN(r.ip_range)   AS exemple_ip_range
FROM   EquipementReseau er
JOIN   Reseau r ON r.id = er.id_reseau
JOIN   Site   s ON s.id = r.id_site
GROUP  BY s.ville, er.type
ORDER  BY s.ville, er.type;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +COST +ROWS'));

SELECT s.ville, er.type,
       COUNT(*)          AS nb_equipements,
       MIN(r.ip_range)   AS exemple_ip_range
FROM   EquipementReseau er
JOIN   Reseau r ON r.id = er.id_reseau
JOIN   Site   s ON s.id = r.id_site
GROUP  BY s.ville, er.type
ORDER  BY s.ville, er.type;


-- =============================================================================
-- PARTIE 2 : SANS INDEX vs AVEC INDEX
-- =============================================================================

BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE(' PARTIE 2 : SANS INDEX vs AVEC INDEX');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE('--- Suppression des index ---');
END;
/

BEGIN EXECUTE IMMEDIATE 'DROP INDEX idx_materiel_site';           EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP INDEX idx_materiel_statut';         EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP INDEX idx_utilisateur_site';        EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP INDEX idx_utilisateur_role';        EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP INDEX idx_ticket_statut';           EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP INDEX idx_ticket_utilisateur';      EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP INDEX idx_ticket_technicien';       EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP INDEX idx_affectation_utilisateur'; EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP INDEX idx_affectation_materiel';    EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP INDEX idx_equipement_reseau';       EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP INDEX idx_reseau_site';             EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP INDEX idx_batiment_site';           EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP INDEX idx_salle_batiment';          EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP INDEX idx_materiel_site_statut';    EXCEPTION WHEN OTHERS THEN NULL; END;
/
BEGIN EXECUTE IMMEDIATE 'DROP INDEX idx_ticket_statut_date';      EXCEPTION WHEN OTHERS THEN NULL; END;
/

BEGIN
    DBMS_OUTPUT.PUT_LINE('--- PHASE 2A : SANS INDEX (Full Table Scan attendu) ---');
END;
/

-- TEST P2-1 SANS INDEX : Parc materiel par statut
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('--- TEST P2-1 SANS INDEX : Parc materiel Cergy par statut ---');
END;
/
EXPLAIN PLAN FOR
SELECT m.type, m.statut, COUNT(*) AS nb
FROM   Materiel m JOIN Site s ON s.id = m.id_site
WHERE  s.ville = 'Cergy'
GROUP  BY m.type, m.statut ORDER BY m.type, nb DESC;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +COST +ROWS'));
SELECT m.type, m.statut, COUNT(*) AS nb
FROM   Materiel m JOIN Site s ON s.id = m.id_site
WHERE  s.ville = 'Cergy'
GROUP  BY m.type, m.statut ORDER BY m.type, nb DESC;

-- TEST P2-2 SANS INDEX : Tickets ouverts par site
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('--- TEST P2-2 SANS INDEX : Tickets ouverts par site ---');
END;
/
EXPLAIN PLAN FOR
SELECT s.ville, COUNT(*) AS nb_tickets_ouverts
FROM   Ticket t JOIN Materiel m ON m.id = t.id_materiel JOIN Site s ON s.id = m.id_site
WHERE  t.statut IN ('ouvert', 'en_cours') GROUP BY s.ville;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +COST +ROWS'));
SELECT s.ville, COUNT(*) AS nb_tickets_ouverts
FROM   Ticket t JOIN Materiel m ON m.id = t.id_materiel JOIN Site s ON s.id = m.id_site
WHERE  t.statut IN ('ouvert', 'en_cours') GROUP BY s.ville;

-- TEST P2-3 SANS INDEX : Affectations actives avec role
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('--- TEST P2-3 SANS INDEX : Affectations actives avec role ---');
END;
/
EXPLAIN PLAN FOR
SELECT u.nom, r.nom AS role, s.ville, m.nom AS materiel, m.type
FROM   Affectation a
JOIN   Utilisateur u ON u.id = a.id_utilisateur
JOIN   Materiel    m ON m.id = a.id_materiel
JOIN   Role        r ON r.id = u.id_role
JOIN   Site        s ON s.id = u.id_site
WHERE  a.date_fin IS NULL ORDER BY s.ville, r.nom, u.nom;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +COST +ROWS'));
SELECT u.nom, r.nom AS role, s.ville, m.nom AS materiel, m.type
FROM   Affectation a
JOIN   Utilisateur u ON u.id = a.id_utilisateur
JOIN   Materiel    m ON m.id = a.id_materiel
JOIN   Role        r ON r.id = u.id_role
JOIN   Site        s ON s.id = u.id_site
WHERE  a.date_fin IS NULL ORDER BY s.ville, r.nom, u.nom;

-- TEST P2-4 SANS INDEX : Performance techniciens
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('--- TEST P2-4 SANS INDEX : Performance des techniciens ---');
END;
/
EXPLAIN PLAN FOR
SELECT u.nom, s.ville,
       COUNT(*) AS total,
       SUM(CASE WHEN t.statut='resolu' THEN 1 ELSE 0 END) AS resolus,
       ROUND(SUM(CASE WHEN t.statut='resolu' THEN 1 ELSE 0 END)*100.0/NULLIF(COUNT(*),0),1) AS pct
FROM   Ticket t JOIN Utilisateur u ON u.id = t.id_technicien JOIN Site s ON s.id = u.id_site
GROUP  BY u.nom, s.ville HAVING COUNT(*) > 5 ORDER BY pct DESC, total DESC;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +COST +ROWS'));
SELECT u.nom, s.ville,
       COUNT(*) AS total,
       SUM(CASE WHEN t.statut='resolu' THEN 1 ELSE 0 END) AS resolus,
       ROUND(SUM(CASE WHEN t.statut='resolu' THEN 1 ELSE 0 END)*100.0/NULLIF(COUNT(*),0),1) AS pct
FROM   Ticket t JOIN Utilisateur u ON u.id = t.id_technicien JOIN Site s ON s.id = u.id_site
GROUP  BY u.nom, s.ville HAVING COUNT(*) > 5 ORDER BY pct DESC, total DESC;

-- TEST P2-5 SANS INDEX : Materiels disponibles
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('--- TEST P2-5 SANS INDEX : Materiels disponibles non affectes ---');
END;
/
EXPLAIN PLAN FOR
SELECT m.id, m.nom, m.type, s.ville
FROM   Materiel m JOIN Site s ON s.id = m.id_site
WHERE  m.statut = 'disponible'
  AND  NOT EXISTS (SELECT 1 FROM Affectation a WHERE a.id_materiel = m.id AND a.date_fin IS NULL)
ORDER  BY s.ville, m.type;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +COST +ROWS'));
SELECT m.id, m.nom, m.type, s.ville
FROM   Materiel m JOIN Site s ON s.id = m.id_site
WHERE  m.statut = 'disponible'
  AND  NOT EXISTS (SELECT 1 FROM Affectation a WHERE a.id_materiel = m.id AND a.date_fin IS NULL)
ORDER  BY s.ville, m.type;


-- Recreation des index
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('--- Recreation de tous les index ---');
END;
/

CREATE INDEX idx_batiment_site           ON Batiment(id_site);
CREATE INDEX idx_salle_batiment          ON Salle(id_batiment);
CREATE INDEX idx_reseau_site             ON Reseau(id_site);
CREATE INDEX idx_equipement_reseau       ON EquipementReseau(id_reseau);
CREATE INDEX idx_materiel_site           ON Materiel(id_site);
CREATE INDEX idx_materiel_statut         ON Materiel(statut);
CREATE INDEX idx_materiel_site_statut    ON Materiel(id_site, statut);
CREATE INDEX idx_utilisateur_site        ON Utilisateur(id_site);
CREATE INDEX idx_utilisateur_role        ON Utilisateur(id_role);
CREATE INDEX idx_affectation_utilisateur ON Affectation(id_utilisateur);
CREATE INDEX idx_affectation_materiel    ON Affectation(id_materiel);
CREATE INDEX idx_ticket_technicien       ON Ticket(id_technicien);
CREATE INDEX idx_ticket_utilisateur      ON Ticket(id_utilisateur);
CREATE INDEX idx_ticket_statut           ON Ticket(statut);
CREATE INDEX idx_ticket_statut_date      ON Ticket(statut, date_creation);

BEGIN
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'MATERIEL',         CASCADE => TRUE);
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'UTILISATEUR',      CASCADE => TRUE);
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'TICKET',           CASCADE => TRUE);
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'AFFECTATION',      CASCADE => TRUE);
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'EQUIPEMENTRESEAU', CASCADE => TRUE);
    DBMS_STATS.GATHER_TABLE_STATS(USER, 'RESEAU',           CASCADE => TRUE);
    DBMS_OUTPUT.PUT_LINE('Statistiques mises a jour. Index prets.');
END;
/

BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('--- PHASE 2B : AVEC INDEX (Index Range Scan attendu) ---');
END;
/

-- TEST P2-1 AVEC INDEX
BEGIN DBMS_OUTPUT.PUT_LINE('--- TEST P2-1 AVEC INDEX : Parc materiel Cergy par statut ---'); END;
/
EXPLAIN PLAN FOR
SELECT m.type, m.statut, COUNT(*) AS nb
FROM   Materiel m JOIN Site s ON s.id = m.id_site
WHERE  s.ville = 'Cergy'
GROUP  BY m.type, m.statut ORDER BY m.type, nb DESC;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +COST +ROWS'));
SELECT m.type, m.statut, COUNT(*) AS nb
FROM   Materiel m JOIN Site s ON s.id = m.id_site
WHERE  s.ville = 'Cergy'
GROUP  BY m.type, m.statut ORDER BY m.type, nb DESC;

-- TEST P2-2 AVEC INDEX
BEGIN DBMS_OUTPUT.PUT_LINE('--- TEST P2-2 AVEC INDEX : Tickets ouverts par site ---'); END;
/
EXPLAIN PLAN FOR
SELECT s.ville, COUNT(*) AS nb_tickets_ouverts
FROM   Ticket t JOIN Materiel m ON m.id = t.id_materiel JOIN Site s ON s.id = m.id_site
WHERE  t.statut IN ('ouvert', 'en_cours') GROUP BY s.ville;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +COST +ROWS'));
SELECT s.ville, COUNT(*) AS nb_tickets_ouverts
FROM   Ticket t JOIN Materiel m ON m.id = t.id_materiel JOIN Site s ON s.id = m.id_site
WHERE  t.statut IN ('ouvert', 'en_cours') GROUP BY s.ville;

-- TEST P2-3 AVEC INDEX
BEGIN DBMS_OUTPUT.PUT_LINE('--- TEST P2-3 AVEC INDEX : Affectations actives avec role ---'); END;
/
EXPLAIN PLAN FOR
SELECT u.nom, r.nom AS role, s.ville, m.nom AS materiel, m.type
FROM   Affectation a
JOIN   Utilisateur u ON u.id = a.id_utilisateur
JOIN   Materiel    m ON m.id = a.id_materiel
JOIN   Role        r ON r.id = u.id_role
JOIN   Site        s ON s.id = u.id_site
WHERE  a.date_fin IS NULL ORDER BY s.ville, r.nom, u.nom;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +COST +ROWS'));
SELECT u.nom, r.nom AS role, s.ville, m.nom AS materiel, m.type
FROM   Affectation a
JOIN   Utilisateur u ON u.id = a.id_utilisateur
JOIN   Materiel    m ON m.id = a.id_materiel
JOIN   Role        r ON r.id = u.id_role
JOIN   Site        s ON s.id = u.id_site
WHERE  a.date_fin IS NULL ORDER BY s.ville, r.nom, u.nom;

-- TEST P2-4 AVEC INDEX
BEGIN DBMS_OUTPUT.PUT_LINE('--- TEST P2-4 AVEC INDEX : Performance des techniciens ---'); END;
/
EXPLAIN PLAN FOR
SELECT u.nom, s.ville,
       COUNT(*) AS total,
       SUM(CASE WHEN t.statut='resolu' THEN 1 ELSE 0 END) AS resolus,
       ROUND(SUM(CASE WHEN t.statut='resolu' THEN 1 ELSE 0 END)*100.0/NULLIF(COUNT(*),0),1) AS pct
FROM   Ticket t JOIN Utilisateur u ON u.id = t.id_technicien JOIN Site s ON s.id = u.id_site
GROUP  BY u.nom, s.ville HAVING COUNT(*) > 5 ORDER BY pct DESC, total DESC;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +COST +ROWS'));
SELECT u.nom, s.ville,
       COUNT(*) AS total,
       SUM(CASE WHEN t.statut='resolu' THEN 1 ELSE 0 END) AS resolus,
       ROUND(SUM(CASE WHEN t.statut='resolu' THEN 1 ELSE 0 END)*100.0/NULLIF(COUNT(*),0),1) AS pct
FROM   Ticket t JOIN Utilisateur u ON u.id = t.id_technicien JOIN Site s ON s.id = u.id_site
GROUP  BY u.nom, s.ville HAVING COUNT(*) > 5 ORDER BY pct DESC, total DESC;

-- TEST P2-5 AVEC INDEX
BEGIN DBMS_OUTPUT.PUT_LINE('--- TEST P2-5 AVEC INDEX : Materiels disponibles non affectes ---'); END;
/
EXPLAIN PLAN FOR
SELECT m.id, m.nom, m.type, s.ville
FROM   Materiel m JOIN Site s ON s.id = m.id_site
WHERE  m.statut = 'disponible'
  AND  NOT EXISTS (SELECT 1 FROM Affectation a WHERE a.id_materiel = m.id AND a.date_fin IS NULL)
ORDER  BY s.ville, m.type;
SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +COST +ROWS'));
SELECT m.id, m.nom, m.type, s.ville
FROM   Materiel m JOIN Site s ON s.id = m.id_site
WHERE  m.statut = 'disponible'
  AND  NOT EXISTS (SELECT 1 FROM Affectation a WHERE a.id_materiel = m.id AND a.date_fin IS NULL)
ORDER  BY s.ville, m.type;


-- =============================================================================
-- PARTIE 3 : BDDR MULTI-SITES (Cergy / Pau)
-- =============================================================================
-- Architecture BDDR :
--   CYGLPI_HUB  : noeud central avec vues V_ALL_* (UNION de cergy_link + pau_link)
--   CERGY_SITE  : fragmentation horizontale, id_site = 1
--   PAU_SITE    : fragmentation horizontale, id_site = 2
--   Replication : Site, Role, Permission, RolePermission via vues materialisees
-- Les requetes ci-dessous simulent ce que CYGLPI_HUB execute via les DB Links.
-- =============================================================================

BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE(' PARTIE 3 : BDDR MULTI-SITES (Cergy / Pau)');
    DBMS_OUTPUT.PUT_LINE('============================================================');
END;
/

-- BDDR-1 : Comparaison du parc entre les deux sites (V_ALL_MATERIELS)
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('--- BDDR-1 : Parc informatique Cergy vs Pau ---');
    DBMS_OUTPUT.PUT_LINE('Equivalent HUB : SELECT ... FROM V_ALL_MATERIELS GROUP BY id_site');
END;
/
SELECT
    s.ville                                                AS SITE,
    SUM(CASE WHEN m.type='PC'         THEN 1 ELSE 0 END)  AS NB_PC,
    SUM(CASE WHEN m.type='Imprimante' THEN 1 ELSE 0 END)  AS NB_IMPRIMANTES,
    SUM(CASE WHEN m.type='Ecran'      THEN 1 ELSE 0 END)  AS NB_ECRANS,
    COUNT(*)                                               AS TOTAL,
    ROUND(COUNT(*)*100.0/SUM(COUNT(*)) OVER (), 1)        AS PCT_GLOBAL
FROM   Materiel m JOIN Site s ON s.id = m.id_site
GROUP  BY s.ville ORDER BY s.ville;

-- BDDR-2 : Verification fragmentation horizontale
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('--- BDDR-2 : Verification fragmentation - chaque site a ses donnees ---');
END;
/
SELECT s.ville AS SITE, 'Utilisateur' AS ENTITE, COUNT(*) AS NB
FROM   Utilisateur u JOIN Site s ON s.id = u.id_site GROUP BY s.ville
UNION ALL
SELECT s.ville, 'Materiel', COUNT(*)
FROM   Materiel m JOIN Site s ON s.id = m.id_site GROUP BY s.ville
UNION ALL
SELECT s.ville, 'Ticket', COUNT(*)
FROM   Ticket t JOIN Materiel m ON m.id = t.id_materiel JOIN Site s ON s.id = m.id_site
GROUP  BY s.ville
ORDER  BY 2, 1;

-- BDDR-3 : Vue consolidee tickets (V_ALL_TICKETS depuis HUB)
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('--- BDDR-3 : Vue consolidee tickets tous sites ---');
    DBMS_OUTPUT.PUT_LINE('Equivalent HUB : SELECT ... FROM V_ALL_TICKETS JOIN V_ALL_UTILISATEURS');
END;
/
SELECT
    s.ville, t.statut,
    COUNT(*) AS NB_TICKETS,
    ROUND(COUNT(*)*100.0/SUM(COUNT(*)) OVER (PARTITION BY s.ville), 1) AS PCT_PAR_SITE
FROM   Ticket t JOIN Materiel m ON m.id = t.id_materiel JOIN Site s ON s.id = m.id_site
GROUP  BY s.ville, t.statut ORDER BY s.ville, NB_TICKETS DESC;

-- BDDR-4 : Tables repliquees - coherence roles et permissions sur les deux sites
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('--- BDDR-4 : Tables repliquees - roles et permissions (memes sur les 2 sites) ---');
END;
/
SELECT r.nom AS ROLE,
       COUNT(rp.id_permission) AS NB_PERMISSIONS,
       LISTAGG(p.nom, ', ') WITHIN GROUP (ORDER BY p.nom) AS PERMISSIONS
FROM   Role r
JOIN   RolePermission rp ON rp.id_role     = r.id
JOIN   Permission     p  ON p.id           = rp.id_permission
GROUP  BY r.nom ORDER BY r.nom;

-- BDDR-5 : Analyse inter-sites - charge de travail globale depuis HUB
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('--- BDDR-5 : Analyse de charge inter-sites depuis CYGLPI_HUB ---');
END;
/
SELECT
    s.ville                                                           AS SITE,
    u.nb_utilisateurs                                                 AS NB_UTILISATEURS,
    m.nb_materiels                                                    AS NB_MATERIELS,
    t.nb_tickets                                                      AS NB_TICKETS,
    ROUND(t.nb_tickets*1.0/NULLIF(u.nb_utilisateurs,0),2)            AS TICKETS_PAR_USER
FROM   Site s
JOIN   (SELECT id_site, COUNT(*) AS nb_utilisateurs FROM Utilisateur GROUP BY id_site) u ON u.id_site = s.id
JOIN   (SELECT id_site, COUNT(*) AS nb_materiels    FROM Materiel    GROUP BY id_site) m ON m.id_site = s.id
JOIN   (SELECT m2.id_site, COUNT(*) AS nb_tickets
        FROM   Ticket t2 JOIN Materiel m2 ON m2.id = t2.id_materiel
        GROUP  BY m2.id_site) t ON t.id_site = s.id
ORDER  BY s.ville;

-- BDDR-6 : Requete analytique multi-sites (fenetre OVER PARTITION BY)
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('--- BDDR-6 : Taux utilisation materiels par site et type ---');
END;
/
SELECT
    s.ville, m.type,
    COUNT(*)                                                              AS NB_TOTAL,
    SUM(CASE WHEN m.statut='en_service' THEN 1 ELSE 0 END)               AS EN_SERVICE,
    ROUND(SUM(CASE WHEN m.statut='en_service' THEN 1 ELSE 0 END)
          *100.0/NULLIF(COUNT(*),0), 1)                                   AS TAUX_PCT,
    ROUND(AVG(COUNT(*)) OVER (PARTITION BY m.type), 1)                   AS MOY_TYPE_GLOBAL
FROM   Materiel m JOIN Site s ON s.id = m.id_site
GROUP  BY s.ville, m.type ORDER BY s.ville, m.type;


-- =============================================================================
-- SYNTHESE FINALE
-- =============================================================================

BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE(' SYNTHESE FINALE - Tableau de bord CY Tech');
    DBMS_OUTPUT.PUT_LINE('============================================================');
END;
/

SELECT s.ville                                              AS SITE,
       SUM(CASE WHEN m.type='PC'         THEN 1 ELSE 0 END) AS NB_PC,
       SUM(CASE WHEN m.type='Imprimante' THEN 1 ELSE 0 END) AS NB_IMPRIMANTES,
       SUM(CASE WHEN m.type='Ecran'      THEN 1 ELSE 0 END) AS NB_ECRANS,
       u.nb_utilisateurs                                     AS NB_UTILISATEURS,
       t.nb_tickets                                          AS NB_TICKETS
FROM   Materiel m
JOIN   Site s ON s.id = m.id_site
JOIN   (SELECT id_site, COUNT(*) AS nb_utilisateurs FROM Utilisateur GROUP BY id_site) u ON u.id_site = s.id
JOIN   (SELECT m2.id_site, COUNT(*) AS nb_tickets
        FROM   Ticket t2 JOIN Materiel m2 ON m2.id = t2.id_materiel
        GROUP  BY m2.id_site) t ON t.id_site = s.id
GROUP  BY s.ville, u.nb_utilisateurs, t.nb_tickets
ORDER  BY s.ville;

SPOOL OFF

BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('BENCHMARK TERMINE - resultats dans resultats_benchmark.txt');
END;
/