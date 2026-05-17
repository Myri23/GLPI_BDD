-- =====================================================================
-- RESET COMPLET — supprime tout le schéma applicatif CYGLPI
-- Usage : sqlplus cyglpi/amsterdam@ORCLPDB1
--         @/opt/GLPI_BDD/sql/reset_all.sql
-- Puis  : @/opt/GLPI_BDD/install.sql
-- =====================================================================
SET SERVEROUTPUT ON

PROMPT === 1/3 Tables, vues, clusters, sequences ===
@/opt/GLPI_BDD/sql/00_drop_schema.sql

PROMPT === 2/3 Packages PL/SQL ===
BEGIN
   FOR o IN (
      SELECT object_name,
             CASE object_type
                WHEN 'PACKAGE BODY' THEN 'PACKAGE BODY'
                ELSE object_type
             END AS ddl_type
      FROM   user_objects
      WHERE  object_type IN ('PACKAGE', 'PACKAGE BODY')
      AND    object_name IN ('PKG_DATA_GEN', 'PKG_GLPI_METIER', 'CYTECH_DEMO')
   ) LOOP
      BEGIN
         EXECUTE IMMEDIATE 'DROP ' || o.ddl_type || ' ' || o.object_name;
         DBMS_OUTPUT.PUT_LINE('Dropped ' || o.ddl_type || ' ' || o.object_name);
      EXCEPTION
         WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('WARN: ' || SQLERRM);
      END;
   END LOOP;
END;
/

PROMPT === 3/3 Clusters orphelins (force) ===
BEGIN
   FOR c IN (SELECT cluster_name FROM user_clusters) LOOP
      BEGIN
         EXECUTE IMMEDIATE 'DROP CLUSTER ' || c.cluster_name || ' INCLUDING TABLES CASCADE';
      EXCEPTION
         WHEN OTHERS THEN
            BEGIN EXECUTE IMMEDIATE 'DROP INDEX idx_cluster_batiment_site'; EXCEPTION WHEN OTHERS THEN NULL; END;
            EXECUTE IMMEDIATE 'DROP CLUSTER ' || c.cluster_name;
      END;
      DBMS_OUTPUT.PUT_LINE('Cluster supprime : ' || c.cluster_name);
   END LOOP;
END;
/

PROMPT === Verification ===
SELECT COUNT(*) AS tables_restantes FROM user_tables;
SELECT cluster_name FROM user_clusters;
SELECT COUNT(*) AS clusters_restants FROM user_clusters;

PROMPT
PROMPT Reset termine. Relancez : @/opt/GLPI_BDD/install.sql
