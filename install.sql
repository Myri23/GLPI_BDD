-- Installation applicative (schéma central cyglpi / utilisateur du projet)
-- Usage : sqlplus cyglpi/amsterdam@ORCLPDB1  puis  @/opt/GLPI_BDD/install.sql
--
-- IMPORTANT : toujours exécuter 00_drop_schema.sql avant une réinstall.

PROMPT === Nettoyage complet ===
@/opt/GLPI_BDD/sql/00_drop_schema.sql

PROMPT === Tablespaces ===
@/opt/GLPI_BDD/sql/tablespaces.sql
@/opt/GLPI_BDD/sql/tables.sql
@/opt/GLPI_BDD/sql/views_metier.sql
@/opt/GLPI_BDD/plsql/triggers_metier.sql
@/opt/GLPI_BDD/plsql/packages_metier.sql
@/opt/GLPI_BDD/plsql/data_generator.sql
@/opt/GLPI_BDD/sql/security_roles_users.sql

PROMPT === Package affichage demo (demo.sql) ===
@/opt/GLPI_BDD/plsql/demo_timer_pkg.sql

PROMPT === Controle sante ===
@/opt/GLPI_BDD/scripts/verify_install.sql

PROMPT Installation applicative terminée.
PROMPT Demo soutenance : @/opt/GLPI_BDD/scripts/demo_interactive.sql
PROMPT Demo auto       : @/opt/GLPI_BDD/scripts/demo.sql
PROMPT BDDR (optionnel) : install_bddr.sql (SYSDBA + schémas HUB/sites).
