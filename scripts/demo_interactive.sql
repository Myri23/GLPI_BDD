-- =====================================================================
-- DEMO INTERACTIVE — soutenance / présentation
-- Appuyez sur ENTREE entre chaque section (PAUSE).
-- Ne dépend PAS du package CYTECH_DEMO.
--
-- Prérequis : @/opt/GLPI_BDD/install.sql  puis  @verify_install.sql
-- =====================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 60
SET TIMING ON
SET ECHO OFF

PROMPT
PROMPT ################################################################
PROMPT  DEMO GLPI CY Tech — 6 sections (ENTREE entre chaque)
PROMPT ################################################################

-- -----------------------------------------------------------------
-- 1. ARCHITECTURE
-- -----------------------------------------------------------------
PROMPT
PROMPT ===== [1/6] ARCHITECTURE — volumetrie =====
SELECT 'Site' entite, COUNT(*) nb FROM Site
UNION ALL SELECT 'Materiel', COUNT(*) FROM Materiel
UNION ALL SELECT 'Utilisateur', COUNT(*) FROM Utilisateur
UNION ALL SELECT 'Ticket', COUNT(*) FROM Ticket
UNION ALL SELECT 'Reseau', COUNT(*) FROM Reseau;

PROMPT Matériels par site et type :
SELECT s.nom site, m.type, COUNT(*) nb
FROM Materiel m JOIN Site s ON s.id = m.id_site
GROUP BY s.nom, m.type ORDER BY s.nom, m.type;

PAUSE [1/6] ENTREE pour continuer...

-- -----------------------------------------------------------------
-- 2. STRUCTURE PHYSIQUE
-- -----------------------------------------------------------------
PROMPT
PROMPT ===== [2/6] STRUCTURE PHYSIQUE — tablespaces, partition, cluster =====
SELECT tablespace_name, status FROM user_tablespaces
WHERE tablespace_name IN ('TS_DATA','TS_INDEX','USERS') ORDER BY 1;

SELECT table_name, partitioning_type, partition_count
FROM user_part_tables WHERE table_name = 'MATERIEL';

SELECT cluster_name, tablespace_name FROM user_clusters;

PAUSE [2/6] ENTREE pour continuer...

-- -----------------------------------------------------------------
-- 3. VUES METIER
-- -----------------------------------------------------------------
PROMPT
PROMPT ===== [3/6] VUES METIER =====
SELECT site, type_materiel, statut, nombre
FROM V_ETAT_MATERIEL
ORDER BY site, type_materiel, statut;

PROMPT Extrait inventaire (3 lignes) :
SELECT site, materiel, type_materiel, statut
FROM V_INVENTAIRE_SITE WHERE ROWNUM <= 3;

PAUSE [3/6] ENTREE pour continuer...

-- -----------------------------------------------------------------
-- 4. PL/SQL
-- -----------------------------------------------------------------
PROMPT
PROMPT ===== [4/6] PL/SQL — package PKG_GLPI_METIER =====
DECLARE
    v_id    NUMBER;
    v_dispo NUMBER;
BEGIN
    SELECT id INTO v_id FROM Materiel WHERE statut = 'disponible' AND ROWNUM = 1;
    v_dispo := PKG_GLPI_METIER.fn_est_disponible(v_id);
    DBMS_OUTPUT.PUT_LINE('fn_est_disponible(materiel ' || v_id || ') = ' || v_dispo);
    PKG_GLPI_METIER.audit_materiel_site(1);
END;
/

PAUSE [4/6] ENTREE pour continuer...

-- -----------------------------------------------------------------
-- 5. OPTIMISATION
-- -----------------------------------------------------------------
PROMPT
PROMPT ===== [5/6] OPTIMISATION — plan d execution =====
EXPLAIN PLAN FOR
SELECT m.id, m.nom, m.statut, s.nom site
FROM Materiel m
JOIN Site s ON s.id = m.id_site
WHERE s.ville = 'Cergy' AND m.type = 'PC';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +COST +ROWS'));

PAUSE [5/6] ENTREE pour continuer...

-- -----------------------------------------------------------------
-- 6. SECURITE
-- -----------------------------------------------------------------
PROMPT
PROMPT ===== [6/6] SECURITE — roles et vues =====
SELECT role FROM dba_roles WHERE role LIKE 'ROLE_%' ORDER BY 1;
SELECT view_name FROM user_views WHERE view_name LIKE 'V_%' ORDER BY 1;

PAUSE [6/6] FIN — ENTREE pour terminer...

PROMPT
PROMPT === FIN DEMO INTERACTIVE ===
PROMPT Benchmark (optionnel) : @/opt/GLPI_BDD/tests/benchmark.sql
PROMPT BDDR (optionnel)      : @/opt/GLPI_BDD/install_bddr.sql
