-- =====================================================================
-- DEMO GLPI CY Tech — architecture, structure, optimisation
-- Connexion : sqlplus cyglpi/amsterdam@ORCLPDB1  (ou XEPDB1)
-- Prérequis : @/opt/GLPI_BDD/install.sql exécuté
--
-- Timers :
--   SET TIMING ON  → "Elapsed: ..." après chaque requête
--   cytech_demo    → bannières début/fin de section (compilé par install.sql)
--
-- Soutenance (ENTREE entre sections) : demo_interactive.sql
-- =====================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 200
SET PAGESIZE 60
SET TIMING ON
SET ECHO OFF

PROMPT
PROMPT Demo automatique (6 sections). Presentateur : demo_interactive.sql
PROMPT

@/opt/GLPI_BDD/plsql/demo_timer_pkg.sql

-- =====================================================================
-- 1. ARCHITECTURE
-- =====================================================================
EXEC cytech_demo.section_start('1. ARCHITECTURE — volumetrie et sites', 0);

SELECT 'Site' entite, COUNT(*) nb FROM Site
UNION ALL SELECT 'Materiel', COUNT(*) FROM Materiel
UNION ALL SELECT 'Utilisateur', COUNT(*) FROM Utilisateur
UNION ALL SELECT 'Ticket', COUNT(*) FROM Ticket
UNION ALL SELECT 'Reseau', COUNT(*) FROM Reseau;

PROMPT
PROMPT Matériels par site et type :
SELECT s.nom site, m.type, COUNT(*) nb
FROM Materiel m JOIN Site s ON s.id = m.id_site
GROUP BY s.nom, m.type ORDER BY s.nom, m.type;

EXEC cytech_demo.section_end;

-- =====================================================================
-- 2. STRUCTURE PHYSIQUE
-- =====================================================================
EXEC cytech_demo.section_start('2. STRUCTURE PHYSIQUE — tablespaces, cluster, partitions', 0);

SELECT tablespace_name, status FROM user_tablespaces
WHERE tablespace_name IN ('TS_DATA','TS_INDEX','USERS')
ORDER BY tablespace_name;

SELECT table_name, partitioning_type, partition_count
FROM user_part_tables WHERE table_name = 'MATERIEL';

SELECT cluster_name, tablespace_name FROM user_clusters;

EXEC cytech_demo.section_end;

-- =====================================================================
-- 3. VUES MÉTIER
-- =====================================================================
EXEC cytech_demo.section_start('3. VUES MÉTIER — inventaire et etat du parc', 0);

SELECT site, type_materiel, statut, nombre
FROM V_ETAT_MATERIEL
ORDER BY site, type_materiel, statut;

SELECT * FROM V_INVENTAIRE_SITE WHERE ROWNUM <= 5;

EXEC cytech_demo.section_end;

-- =====================================================================
-- 4. PL/SQL
-- =====================================================================
EXEC cytech_demo.section_start('4. PL/SQL — package metier et triggers', 0);

DECLARE
    v_dispo NUMBER;
BEGIN
    SELECT id INTO v_dispo FROM Materiel WHERE statut = 'disponible' AND ROWNUM = 1;
    DBMS_OUTPUT.PUT_LINE('fn_est_disponible = ' || PKG_GLPI_METIER.fn_est_disponible(v_dispo));
    PKG_GLPI_METIER.audit_materiel_site(1);
END;
/

EXEC cytech_demo.section_end;

-- =====================================================================
-- 5. OPTIMISATION
-- =====================================================================
EXEC cytech_demo.section_start('5. OPTIMISATION — plan execution (inventaire Cergy)', 0);

EXPLAIN PLAN FOR
SELECT m.id, m.nom, m.statut, s.nom site
FROM Materiel m
JOIN Site s ON s.id = m.id_site
WHERE s.ville = 'Cergy' AND m.type = 'PC';

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY(FORMAT => 'BASIC +COST +ROWS'));

EXEC cytech_demo.section_end;

-- =====================================================================
-- 6. SÉCURITÉ
-- =====================================================================
EXEC cytech_demo.section_start('6. SECURITE — roles et vues', 0);

SELECT role FROM dba_roles WHERE role LIKE 'ROLE_%' ORDER BY role;
SELECT view_name FROM user_views WHERE view_name LIKE 'V_%' ORDER BY view_name;

EXEC cytech_demo.section_end;

-- =====================================================================
-- 7. SUITE
-- =====================================================================
PROMPT
PROMPT ============================================================
PROMPT 7. SUITE (optionnel)
PROMPT ============================================================
PROMPT Benchmark : @/opt/GLPI_BDD/tests/benchmark.sql
PROMPT BDDR      : @/opt/GLPI_BDD/bddr/Verifications_Setup.sql
PROMPT
PROMPT === FIN DEMO ===
