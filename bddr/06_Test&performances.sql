-- =============================================================================
-- PARTIE 6 : TESTS DE PERFORMANCES
-- Objectif : Vérifier que les requêtes sur le HUB sont performantes malgré la fragmentation
-- =============================================================================

-- Rafraîchir les statistiques pour optimiser les plans d'exécution

EXEC DBMS_STATS.GATHER_SCHEMA_STATS('CYGLPI_HUB');
EXEC DBMS_STATS.GATHER_SCHEMA_STATS('CERGY_SITE');
EXEC DBMS_STATS.GATHER_SCHEMA_STATS('PAU_SITE');

-- Test de performance : Requête globale sur les tickets avec jointure sur les utilisateurs et les sites

EXPLAIN PLAN FOR 
SELECT t.id, t.titre, u.nom, s.nom AS Site_Nom
FROM V_ALL_TICKETS t
JOIN V_ALL_UTILISATEURS u ON t.id_utilisateur = u.id AND t.id_site = u.id_site
JOIN Site s ON t.id_site = s.id_site;

-- Afficher le plan d'exécution pour analyser les performances

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);