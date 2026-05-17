-- Jeu minimal pour démo BDDR (exécuter sur CERGY_SITE puis adapter id sur PAU_SITE)
INSERT INTO Materiel (id, nom, type, numero_serie, id_site, statut)
VALUES (1001, 'PC-DEMO-CERGY', 'PC', 'SN-CERGY-1001', 1, 'disponible');

INSERT INTO Utilisateur (id, nom, email, mot_passe_hash, id_site, id_role)
VALUES (2001, 'Demo Cergy', 'demo.cergy@cytech.fr', 'hash', 1, 3);

COMMIT;
