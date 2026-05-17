-- Vérifications BDDR (après peuplement des sites + refresh MV)
-- Connexion CERGY_SITE / PAU_SITE / CYGLPI_HUB selon les sections

-- === CERGY_SITE : réplication ===
SELECT 'CERGY - MV_Site' AS test_name, COUNT(*) FROM MV_Site;
SELECT 'CERGY - MV_Role' AS test_name, COUNT(*) FROM MV_Role;

-- === CERGY_SITE : fragmentation (id_site = 1) ===
SELECT 'CERGY - Utilisateurs' AS test_name, id_site, COUNT(*) FROM Utilisateur GROUP BY id_site;
SELECT 'CERGY - Materiels' AS test_name, id_site, COUNT(*) FROM Materiel GROUP BY id_site;

-- === PAU_SITE : fragmentation (id_site = 2) ===
-- SELECT 'PAU - Utilisateurs' ... (exécuter sur PAU_SITE)

-- === CYGLPI_HUB : vues consolidées ===
SELECT 'HUB - V_ALL_UTILISATEURS' AS vue_name, id_site, COUNT(*) FROM V_ALL_UTILISATEURS GROUP BY id_site ORDER BY id_site;
SELECT 'HUB - V_ALL_MATERIELS' AS vue_name, id_site, COUNT(*) FROM V_ALL_MATERIELS GROUP BY id_site ORDER BY id_site;
SELECT 'HUB - V_ALL_TICKETS' AS vue_name, m.id_site, COUNT(*)
FROM V_ALL_TICKETS t
JOIN V_ALL_MATERIELS m ON m.id = t.id_materiel AND m.id_site = t.id_site
GROUP BY m.id_site
ORDER BY m.id_site;
