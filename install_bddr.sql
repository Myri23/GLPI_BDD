-- Installation BDDR — à exécuter APRÈS install.sql
-- Étape A (SYSDBA, PDB) : @/opt/GLPI_BDD/bddr/01_Creation_utilisateurs_et_privileges.sql
-- Étape B : adapter le service dans bddr/00_service_name.sql (XEPDB1 ou ORCLPDB1)
-- Étape C (CERGY_SITE) : @/opt/GLPI_BDD/bddr/03_site_schema.sql
-- Étape D (PAU_SITE)   : @/opt/GLPI_BDD/bddr/03_pau_site_schema.sql
-- Étape E (CYGLPI_HUB) :
@/opt/GLPI_BDD/bddr/00_service_name.sql
@/opt/GLPI_BDD/bddr/04_hub_master.sql
@/opt/GLPI_BDD/bddr/02_Creation_database_link.sql
-- Sur CERGY_SITE et PAU_SITE : @/opt/GLPI_BDD/bddr/04_site_mviews.sql
@/opt/GLPI_BDD/bddr/03_hub_views.sql
-- Étape F : peuplement manuel ou @bddr/05_seed_sites_demo.sql sur chaque site
-- Étape G (CERGY_SITE + PAU_SITE) : @/opt/GLPI_BDD/bddr/04b_Replication_Refresh.sql

PROMPT BDDR : exécuter les étapes A–G selon les connexions indiquées dans install_bddr.sql.
