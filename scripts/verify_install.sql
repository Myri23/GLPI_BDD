-- Contrôle santé après install.sql (ou avant une démo)
-- Usage : @/opt/GLPI_BDD/scripts/verify_install.sql

SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 120

PROMPT
PROMPT ============================================================
PROMPT  VERIFICATION INSTALL — GLPI_BDD / utilisateur courant
PROMPT ============================================================

DECLARE
    v_sites    NUMBER;
    v_mat      NUMBER;
    v_tickets  NUMBER;
    v_ok       BOOLEAN := TRUE;
BEGIN
    SELECT COUNT(*) INTO v_sites   FROM Site;
    SELECT COUNT(*) INTO v_mat     FROM Materiel;
    SELECT COUNT(*) INTO v_tickets FROM Ticket;

    DBMS_OUTPUT.PUT_LINE('--- Volumetrie ---');
    DBMS_OUTPUT.PUT_LINE('  Site        : ' || v_sites   || '  (attendu: 2)');
    DBMS_OUTPUT.PUT_LINE('  Materiel    : ' || v_mat     || '  (attendu: ~1350)');
    DBMS_OUTPUT.PUT_LINE('  Ticket      : ' || v_tickets || '  (attendu: ~5000)');

    IF v_sites <> 2 OR v_mat < 500 THEN
        DBMS_OUTPUT.PUT_LINE('  >>> ECHEC : relancer @/opt/GLPI_BDD/install.sql');
        v_ok := FALSE;
    ELSE
        DBMS_OUTPUT.PUT_LINE('  OK volumetrie');
    END IF;

    DBMS_OUTPUT.PUT_LINE('--- Vue V_ETAT_MATERIEL ---');
    DECLARE
        v_col NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_col
        FROM   user_tab_columns
        WHERE  table_name = 'V_ETAT_MATERIEL'
        AND    column_name = 'TYPE_MATERIEL';
        IF v_col = 0 THEN
            DBMS_OUTPUT.PUT_LINE('  >>> ECHEC : colonne TYPE_MATERIEL absente');
            DBMS_OUTPUT.PUT_LINE('      Fix: @/opt/GLPI_BDD/sql/views_metier.sql');
            v_ok := FALSE;
        ELSE
            DBMS_OUTPUT.PUT_LINE('  OK colonne TYPE_MATERIEL');
        END IF;
    END;

    DBMS_OUTPUT.PUT_LINE('--- Objets PL/SQL invalides ---');
    DECLARE
        v_inv NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_inv
        FROM   user_objects
        WHERE  status = 'INVALID'
        AND    object_type IN ('PACKAGE', 'PACKAGE BODY', 'VIEW', 'TRIGGER', 'PROCEDURE', 'FUNCTION');
        IF v_inv > 0 THEN
            DBMS_OUTPUT.PUT_LINE('  >>> ECHEC : ' || v_inv || ' objet(s) INVALID (detail ci-dessous)');
            v_ok := FALSE;
        ELSE
            DBMS_OUTPUT.PUT_LINE('  OK aucun objet metier invalide');
        END IF;
    END;

    DBMS_OUTPUT.PUT_LINE('--- Package demo (demo.sql uniquement) ---');
    DECLARE
        v_demo NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_demo
        FROM   user_objects
        WHERE  object_name = 'CYTECH_DEMO'
        AND    object_type = 'PACKAGE BODY'
        AND    status = 'VALID';
        IF v_demo = 0 THEN
            DBMS_OUTPUT.PUT_LINE('  INFO : CYTECH_DEMO absent ou invalide');
            DBMS_OUTPUT.PUT_LINE('         @/opt/GLPI_BDD/plsql/demo_timer_pkg.sql');
            DBMS_OUTPUT.PUT_LINE('         OU utilisez demo_interactive.sql (sans ce package)');
        ELSE
            DBMS_OUTPUT.PUT_LINE('  OK CYTECH_DEMO');
        END IF;
    END;

    DBMS_OUTPUT.PUT_LINE('--- Package metier ---');
    DECLARE
        v_pkg NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_pkg
        FROM   user_objects
        WHERE  object_name = 'PKG_GLPI_METIER'
        AND    object_type = 'PACKAGE BODY'
        AND    status = 'VALID';
        IF v_pkg = 0 THEN
            DBMS_OUTPUT.PUT_LINE('  >>> ECHEC : PKG_GLPI_METIER invalide');
            v_ok := FALSE;
        ELSE
            DBMS_OUTPUT.PUT_LINE('  OK PKG_GLPI_METIER');
        END IF;
    END;

    DBMS_OUTPUT.PUT_LINE('============================================================');
    IF v_ok THEN
        DBMS_OUTPUT.PUT_LINE(' RESULTAT : PRET POUR LA DEMO');
        DBMS_OUTPUT.PUT_LINE('   Soutenance : @/opt/GLPI_BDD/scripts/demo_interactive.sql');
        DBMS_OUTPUT.PUT_LINE('   Auto       : @/opt/GLPI_BDD/scripts/demo.sql');
    ELSE
        DBMS_OUTPUT.PUT_LINE(' RESULTAT : CORRIGER AVANT DEMO');
        DBMS_OUTPUT.PUT_LINE('   1) docker cp . gallant_turing:/opt/GLPI_BDD');
        DBMS_OUTPUT.PUT_LINE('   2) @/opt/GLPI_BDD/sql/reset_all.sql');
        DBMS_OUTPUT.PUT_LINE('   3) @/opt/GLPI_BDD/install.sql');
    END IF;
    DBMS_OUTPUT.PUT_LINE('============================================================');
END;
/

SELECT object_name, object_type, status
FROM   user_objects
WHERE  status = 'INVALID'
AND    object_type IN ('PACKAGE', 'PACKAGE BODY', 'VIEW', 'TRIGGER')
ORDER  BY object_name, object_type;
