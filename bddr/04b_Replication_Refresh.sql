-- =============================================================================
-- SCRIPT 04_bis: Rafraichissement des vues matérialisées pour initialiser les données
-- A exécuter sur CERGY_SITE et PAU_SITE après la génération des données
-- =============================================================================

EXEC DBMS_MVIEW.REFRESH('Site', 'C');
EXEC DBMS_MVIEW.REFRESH('Role', 'C');
EXEC DBMS_MVIEW.REFRESH('Permission', 'C');
EXEC DBMS_MVIEW.REFRESH('RolePermission', 'C');