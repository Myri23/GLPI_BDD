-- =============================================================================
-- SCRIPT : Verifications_Setup.sql
-- Objectif : Vérifier que la BDDR (Fragmentation + Réplication) fonctionne 
-- correctement après l'exécution du data_generator.sql
-- =============================================================================

-- =============================================================================
-- PARTIE 1 : VÉRIFICATION DE LA RÉPLICATION (VUES MATÉRIALISÉES)
-- Objectif : S'assurer que les sites locaux ont bien récupéré les données du HUB
-- =============================================================================

-- 1A. Vérification sur CERGY_SITE
-- Se connecter à CERGY_SITE avant d'exécuter ces requêtes
SELECT 'CERGY_SITE - Table Site (Répliquée)' AS Test_Name, COUNT(*) AS Total_Lignes FROM Site;
SELECT * FROM Role; -- Doit afficher Administrateur, Technicien, Utilisateur...

-- 1B. Vérification sur PAU_SITE
-- Se connecter à PAU_SITE avant d'exécuter ces requêtes
SELECT 'PAU_SITE - Table Site (Répliquée)' AS Test_Name, COUNT(*) AS Total_Lignes FROM Site;
SELECT * FROM Role; -- Doit afficher les mêmes rôles que Cergy


-- =============================================================================
-- PARTIE 2 : VÉRIFICATION DE LA FRAGMENTATION HORIZONTALE
-- Objectif : S'assurer que chaque site ne possède QUE ses propres données
-- =============================================================================

-- 2A. Vérification sur CERGY_SITE (id_site = 1)
-- Se connecter à CERGY_SITE
SELECT 'CERGY_SITE - Utilisateurs' AS Table_Name, id_site, COUNT(*) AS Nb_Utilisateurs 
FROM Utilisateur 
GROUP BY id_site; 
-- Résultat attendu : Uniquement id_site = 1

SELECT 'CERGY_SITE - Tickets' AS Table_Name, id_site, COUNT(*) AS Nb_Tickets 
FROM Ticket 
GROUP BY id_site;
-- Résultat attendu : Uniquement id_site = 1


-- 2B. Vérification sur PAU_SITE (id_site = 2)
-- Se connecter à PAU_SITE
SELECT 'PAU_SITE - Utilisateurs' AS Table_Name, id_site, COUNT(*) AS Nb_Utilisateurs 
FROM Utilisateur 
GROUP BY id_site;
-- Résultat attendu : Uniquement id_site = 2

SELECT 'PAU_SITE - Tickets' AS Table_Name, id_site, COUNT(*) AS Nb_Tickets 
FROM Ticket 
GROUP BY id_site;
-- Résultat attendu : Uniquement id_site = 2


-- =============================================================================
-- PARTIE 3 : VÉRIFICATION DE LA CONSOLIDATION SUR LE HUB (VUES GLOBALES)
-- Objectif : S'assurer que le HUB voit l'ensemble du parc via les DB Links
-- =============================================================================

-- Se connecter à CYGLPI_HUB avant d'exécuter ces requêtes

-- 3A. Vue globale des Utilisateurs
SELECT 'HUB - V_ALL_UTILISATEURS' AS Vue_Name, id_site, COUNT(*) AS Total_Par_Site 
FROM V_ALL_UTILISATEURS 
GROUP BY id_site 
ORDER BY id_site;
-- Résultat attendu : Deux lignes (id_site 1 et id_site 2) avec la somme des utilisateurs

-- 3B. Vue globale des Tickets
SELECT 'HUB - V_ALL_TICKETS' AS Vue_Name, id_site, COUNT(*) AS Total_Par_Site 
FROM V_ALL_TICKETS 
GROUP BY id_site 
ORDER BY id_site;
-- Résultat attendu : Deux lignes (id_site 1 et id_site 2)

-- 3C. Vue globale des Matériels (pour confirmer le parc)
SELECT 'HUB - V_ALL_MATERIELS' AS Vue_Name, id_site, COUNT(*) AS Total_Par_Site 
FROM V_ALL_MATERIELS 
GROUP BY id_site 
ORDER BY id_site;

-- 3D. Petit test de jointure depuis le HUB (croisement Réplication / Fragmentation)
-- On vérifie les 5 derniers tickets créés sur l'ensemble du réseau avec le nom du rôle de l'utilisateur
SELECT 
    t.id_ticket, 
    t.titre, 
    t.statut,
    u.nom || ' ' || u.prenom AS Demandeur,
    s.nom AS Site_Origine
FROM V_ALL_TICKETS t
JOIN V_ALL_UTILISATEURS u ON t.id_utilisateur = u.id_utilisateur AND t.id_site = u.id_site
JOIN Site s ON t.id_site = s.id_site
FETCH FIRST 5 ROWS ONLY;