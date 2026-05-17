-- Exécuter connecté en CYGLPI_HUB (après DB links et peuplement des sites)
CREATE OR REPLACE VIEW V_ALL_BATIMENTS AS
SELECT * FROM Batiment@cergy_link
UNION ALL
SELECT * FROM Batiment@pau_link;

CREATE OR REPLACE VIEW V_ALL_SALLES AS
SELECT * FROM Salle@cergy_link UNION ALL SELECT * FROM Salle@pau_link;

CREATE OR REPLACE VIEW V_ALL_RESEAUX AS
SELECT * FROM Reseau@cergy_link UNION ALL SELECT * FROM Reseau@pau_link;

CREATE OR REPLACE VIEW V_ALL_EQUIP_RES AS
SELECT * FROM EquipementReseau@cergy_link UNION ALL SELECT * FROM EquipementReseau@pau_link;

CREATE OR REPLACE VIEW V_ALL_UTILISATEURS AS
SELECT * FROM Utilisateur@cergy_link UNION ALL SELECT * FROM Utilisateur@pau_link;

CREATE OR REPLACE VIEW V_ALL_MATERIELS AS
SELECT * FROM Materiel@cergy_link UNION ALL SELECT * FROM Materiel@pau_link;

CREATE OR REPLACE VIEW V_ALL_AFFECTATIONS AS
SELECT * FROM Affectation@cergy_link UNION ALL SELECT * FROM Affectation@pau_link;

CREATE OR REPLACE VIEW V_ALL_TICKETS AS
SELECT * FROM Ticket@cergy_link UNION ALL SELECT * FROM Ticket@pau_link;
