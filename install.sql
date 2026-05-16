-- ============================================
-- SCRIPT D'INSTALLATION | GLPI CY Tech
-- FICHIER  : install.sql
-- (Fait dans l'ordre d'éxecution)
-- ============================================

-- 1. Structure physique 
@/opt/GLPI_BDD/sql/tables.sql


-- 2. Sécurité & droits 
@/opt/GLPI_BDD/plsql/triggers_metier.sql
@/opt/GLPI_BDD/plsql/packages_metier.sql

-- 3. Répartition BDDR 
@/opt/GLPI_BDD/bddr/01_Creation_utilisateurs_et_privileges.sql
@/opt/GLPI_BDD/bddr/02_Creation_database_link.sql
@/opt/GLPI_BDD/bddr/03_Distribution.sql
@/opt/GLPI_BDD/bddr/04_Replication.sql


-- 4. Données de test 
@/opt/GLPI_BDD/plsql/data_generator.sql

-- 5. Appliquer la sécurité
@/opt/GLPI_BDD/sql/security_roles_users.sql

-- 6. Rafraîchissement des vues matérialisées
@/opt/GLPI_BDD/bddr/04b_Replication_Refresh.sql

-- 7. Benchmarks (tests)
@/opt/GLPI_BDD/tests/benchmark.sql

-- Exécution facultative
@/opt/GLPI_BDD/bddr/Verifications_Setup.sql