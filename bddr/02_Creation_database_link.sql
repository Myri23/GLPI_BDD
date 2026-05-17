-- Exécuter connecté en CYGLPI_HUB
-- Adapter le service : @bddr/00_service_name.sql (XEPDB1 ou ORCLPDB1)

CREATE DATABASE LINK cergy_link
CONNECT TO CERGY_SITE IDENTIFIED BY amsterdam
USING 'localhost:1521/&pdb_service';

CREATE DATABASE LINK pau_link
CONNECT TO PAU_SITE IDENTIFIED BY amsterdam
USING 'localhost:1521/&pdb_service';
