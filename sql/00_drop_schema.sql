-- Nettoyage complet du schéma CYGLPI (réinstall propre)
SET SERVEROUTPUT ON

-- 1. Vues
BEGIN
   FOR v IN (SELECT view_name FROM user_views) LOOP
      EXECUTE IMMEDIATE 'DROP VIEW ' || v.view_name;
   END LOOP;
END;
/

-- 2. Cluster nommé (souvent orphelin après drop des tables)
BEGIN
   EXECUTE IMMEDIATE 'DROP CLUSTER cluster_batiment_site INCLUDING TABLES CASCADE';
   DBMS_OUTPUT.PUT_LINE('Dropped cluster cluster_batiment_site');
EXCEPTION
   WHEN OTHERS THEN
      IF SQLCODE NOT IN (-2280, -958, -32006) THEN
         DBMS_OUTPUT.PUT_LINE('INFO cluster: ' || SQLERRM);
      END IF;
END;
/

-- 3. Tous les clusters restants
BEGIN
   FOR c IN (SELECT cluster_name FROM user_clusters) LOOP
      EXECUTE IMMEDIATE 'DROP CLUSTER ' || c.cluster_name || ' INCLUDING TABLES CASCADE';
      DBMS_OUTPUT.PUT_LINE('Dropped cluster ' || c.cluster_name);
   END LOOP;
EXCEPTION
   WHEN OTHERS THEN NULL;
END;
/

-- 4. Toutes les tables
BEGIN
   FOR t IN (SELECT table_name FROM user_tables ORDER BY table_name) LOOP
      BEGIN
         EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS PURGE';
         DBMS_OUTPUT.PUT_LINE('Dropped table ' || t.table_name);
      EXCEPTION
         WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('WARN drop ' || t.table_name || ': ' || SQLERRM);
      END;
   END LOOP;
END;
/

-- 5. Clusters orphelins (2e passe + index de cluster)
BEGIN
   FOR c IN (SELECT cluster_name FROM user_clusters) LOOP
      BEGIN
         EXECUTE IMMEDIATE 'DROP CLUSTER ' || c.cluster_name || ' INCLUDING TABLES CASCADE';
         DBMS_OUTPUT.PUT_LINE('Dropped cluster ' || c.cluster_name);
      EXCEPTION
         WHEN OTHERS THEN
            BEGIN
               EXECUTE IMMEDIATE 'DROP INDEX idx_cluster_batiment_site';
            EXCEPTION
               WHEN OTHERS THEN NULL;
            END;
            BEGIN
               EXECUTE IMMEDIATE 'DROP CLUSTER ' || c.cluster_name;
               DBMS_OUTPUT.PUT_LINE('Dropped cluster ' || c.cluster_name || ' (sans tables)');
            EXCEPTION
               WHEN OTHERS THEN
                  DBMS_OUTPUT.PUT_LINE('WARN cluster ' || c.cluster_name || ': ' || SQLERRM);
            END;
      END;
   END LOOP;
END;
/

-- 6. Séquences
BEGIN
   FOR s IN (SELECT sequence_name FROM user_sequences) LOOP
      EXECUTE IMMEDIATE 'DROP SEQUENCE ' || s.sequence_name;
   END LOOP;
EXCEPTION
   WHEN OTHERS THEN NULL;
END;
/

BEGIN
   EXECUTE IMMEDIATE 'PURGE RECYCLEBIN';
EXCEPTION
   WHEN OTHERS THEN NULL;
END;
/

PROMPT Schéma applicatif supprimé (tables, vues, clusters, séquences).
