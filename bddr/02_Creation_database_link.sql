-- =============================================================================
-- PARTIE 2 : CREATION DES DATABASE LINKS
-- Objectif : Permettre la communication entre le HUB et les sites via des DB Links
-- création via cyglpi_hub pour accéder à cergy_site et pau_site
-- =============================================================================

-- Lien vers Cergy
CREATE DATABASE LINK cergy_link 
CONNECT TO CERGY_SITE IDENTIFIED BY amsterdam 
USING 'localhost:1521/XEPDB1';

-- Lien vers Pau
CREATE DATABASE LINK pau_link 
CONNECT TO PAU_SITE IDENTIFIED BY amsterdam 
USING 'localhost:1521/XEPDB1';

-- Accès aux données via DB Links

-- Depuis cyglpi_hub vers cergy_site
SELECT *
FROM Utilisateur@cergy_link
WHERE id_site = 1;

-- Depuis cyglpi_hub vers pau_site
SELECT *
FROM Utilisateur@pau_link
WHERE id_site = 2;