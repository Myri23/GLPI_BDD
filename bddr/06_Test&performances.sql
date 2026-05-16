EXPLAIN PLAN FOR 
SELECT t.id, t.titre, u.nom, s.nom AS Site_Nom
FROM V_ALL_TICKETS t
JOIN V_ALL_UTILISATEURS u ON t.id_utilisateur = u.id AND t.id_site = u.id_site
JOIN Site s ON t.id_site = s.id_site;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY);