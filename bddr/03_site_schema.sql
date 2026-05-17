-- =====================================================================
-- Schéma fragmenté par site — aligné sur sql/tables.sql (noms de colonnes)
-- Exécuter la section CERGY en tant que CERGY_SITE, section PAU en PAU_SITE
-- =====================================================================

-- ----- SECTION CERGY_SITE (DEFAULT id_site = 1) -----
CREATE TABLE Batiment (
    id NUMBER PRIMARY KEY,
    nom VARCHAR2(255),
    id_site NUMBER DEFAULT 1 NOT NULL
);

CREATE TABLE Salle (
    id NUMBER PRIMARY KEY,
    nom VARCHAR2(255),
    id_batiment NUMBER NOT NULL
);

CREATE TABLE Reseau (
    id NUMBER PRIMARY KEY,
    ip_range VARCHAR2(50) NOT NULL,
    wan VARCHAR2(100) NOT NULL,
    vlan VARCHAR2(50),
    id_site NUMBER DEFAULT 1 NOT NULL
);

CREATE TABLE EquipementReseau (
    id NUMBER PRIMARY KEY,
    nom VARCHAR2(255) NOT NULL,
    type VARCHAR2(50) NOT NULL,
    id_reseau NUMBER NOT NULL
);

CREATE TABLE Utilisateur (
    id NUMBER PRIMARY KEY,
    nom VARCHAR2(255) NOT NULL,
    prenom VARCHAR2(255),
    login VARCHAR2(100),
    email VARCHAR2(255) NOT NULL,
    mot_passe_hash VARCHAR2(255) NOT NULL,
    est_actif NUMBER(1) DEFAULT 1,
    id_site NUMBER DEFAULT 1 NOT NULL,
    id_role NUMBER NOT NULL
);

CREATE TABLE Materiel (
    id NUMBER PRIMARY KEY,
    nom VARCHAR2(255) NOT NULL,
    type VARCHAR2(50) NOT NULL,
    numero_serie VARCHAR2(255) NOT NULL,
    id_site NUMBER DEFAULT 1 NOT NULL,
    statut VARCHAR2(50) NOT NULL
);

CREATE TABLE Affectation (
    id NUMBER PRIMARY KEY,
    id_utilisateur NUMBER NOT NULL,
    id_materiel NUMBER NOT NULL,
    date_debut TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    date_fin TIMESTAMP
);

CREATE TABLE Ticket (
    id NUMBER PRIMARY KEY,
    id_technicien NUMBER,
    id_utilisateur NUMBER NOT NULL,
    id_materiel NUMBER NOT NULL,
    description CLOB NOT NULL,
    statut VARCHAR2(50) NOT NULL,
    priorite VARCHAR2(20) DEFAULT 'normale',
    date_creation TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    date_resolution TIMESTAMP
);

-- ----- SECTION PAU_SITE : recréer avec DEFAULT id_site = 2 -----
-- (fichier miroir exécuté manuellement sur PAU_SITE — voir install_bddr.sql)
