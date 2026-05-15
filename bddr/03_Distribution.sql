
-- connexion sur CERGY_SITE

-- Infrastructure physique
CREATE TABLE Batiment (
    id_batiment INT PRIMARY KEY,
    nom VARCHAR2(100),
    id_site INT DEFAULT 1
);

CREATE TABLE Salle (
    id_salle INT PRIMARY KEY,
    nom VARCHAR2(100),
    id_batiment INT
);

-- Réseau
CREATE TABLE Reseau (
    id_reseau INT PRIMARY KEY,
    nom VARCHAR2(100),
    ip_range VARCHAR2(50),
    id_site INT DEFAULT 1
);

CREATE TABLE EquipementReseau (
    id_equip_res INT PRIMARY KEY,
    nom VARCHAR2(100),
    type VARCHAR2(50),
    id_reseau INT
);

-- Utilisateurs
CREATE TABLE Utilisateur (
    id_utilisateur INT PRIMARY KEY,
    nom VARCHAR2(100),
    prenom VARCHAR2(100),
    email VARCHAR2(100),
    id_site INT DEFAULT 1,
    id_role INT
);

-- Opérationnel
CREATE TABLE Materiel (
    id_materiel INT PRIMARY KEY,
    nom VARCHAR2(100),
    type VARCHAR2(50),
    id_site INT DEFAULT 1
);

CREATE TABLE Affectation (
    id_affectation INT PRIMARY KEY,
    id_utilisateur INT,
    id_materiel INT,
    date_debut DATE DEFAULT SYSDATE
);

CREATE TABLE Ticket (
    id_ticket INT PRIMARY KEY,
    titre VARCHAR2(255),
    description VARCHAR2(1000),
    statut VARCHAR2(50) DEFAULT 'Nouveau',
    date_creation DATE DEFAULT SYSDATE,
    id_utilisateur INT,
    id_materiel INT,
    id_site INT DEFAULT 1
);



-- connexion sur Pau

-- Infrastructure physique
CREATE TABLE Batiment (
    id_batiment INT PRIMARY KEY,
    nom VARCHAR2(100),
    id_site INT DEFAULT 2
);

CREATE TABLE Salle (
    id_salle INT PRIMARY KEY,
    nom VARCHAR2(100),
    id_batiment INT
);

-- Réseau
CREATE TABLE Reseau (
    id_reseau INT PRIMARY KEY,
    nom VARCHAR2(100),
    ip_range VARCHAR2(50),
    id_site INT DEFAULT 2
);

CREATE TABLE EquipementReseau (
    id_equip_res INT PRIMARY KEY,
    nom VARCHAR2(100),
    type VARCHAR2(50),
    id_reseau INT
);

-- Utilisateurs
CREATE TABLE Utilisateur (
    id_utilisateur INT PRIMARY KEY,
    nom VARCHAR2(100),
    prenom VARCHAR2(100),
    email VARCHAR2(100),
    id_site INT DEFAULT 2,
    id_role INT
);

-- Opérationnel (Matériel et Affectations)
CREATE TABLE Materiel (
    id_materiel INT PRIMARY KEY,
    nom VARCHAR2(100),
    type VARCHAR2(50),
    id_site INT DEFAULT 2
);

CREATE TABLE Affectation (
    id_affectation INT PRIMARY KEY,
    id_utilisateur INT,
    id_materiel INT,
    date_debut DATE DEFAULT SYSDATE
);

CREATE TABLE Ticket (
    id_ticket INT PRIMARY KEY,
    titre VARCHAR2(255),
    description VARCHAR2(1000),
    statut VARCHAR2(50) DEFAULT 'Nouveau',
    date_creation DATE DEFAULT SYSDATE,
    id_utilisateur INT,
    id_materiel INT,
    id_site INT DEFAULT 2
);

-- connexion sur CYGLPI_HUB
-- Vues pour l'infrastructure
CREATE OR REPLACE VIEW V_ALL_BATIMENTS AS
    SELECT * FROM Batiment@cergy_link UNION ALL SELECT * FROM Batiment@pau_link;

CREATE OR REPLACE VIEW V_ALL_SALLES AS
    SELECT * FROM Salle@cergy_link UNION ALL SELECT * FROM Salle@pau_link;

-- Vues pour le réseau
CREATE OR REPLACE VIEW V_ALL_RESEAUX AS
    SELECT * FROM Reseau@cergy_link UNION ALL SELECT * FROM Reseau@pau_link;

CREATE OR REPLACE VIEW V_ALL_EQUIP_RES AS
    SELECT * FROM EquipementReseau@cergy_link UNION ALL SELECT * FROM EquipementReseau@pau_link;

-- Vues pour l'humain et le parc
CREATE OR REPLACE VIEW V_ALL_UTILISATEURS AS
    SELECT * FROM Utilisateur@cergy_link UNION ALL SELECT * FROM Utilisateur@pau_link;

CREATE OR REPLACE VIEW V_ALL_MATERIELS AS
    SELECT * FROM Materiel@cergy_link UNION ALL SELECT * FROM Materiel@pau_link;

CREATE OR REPLACE VIEW V_ALL_AFFECTATIONS AS
    SELECT * FROM Affectation@cergy_link UNION ALL SELECT * FROM Affectation@pau_link;

CREATE OR REPLACE VIEW V_ALL_TICKETS AS
    SELECT * FROM Ticket@cergy_link UNION ALL SELECT * FROM Ticket@pau_link;
    