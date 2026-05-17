-- =============================================================================
-- SCRIPT 03 : DISTRIBUTION - DDL DES TABLES LOCALES (CERGY_SITE et PAU_SITE)
-- Objectif   : Créer les tables fragmentées horizontalement sur chaque site
-- Alignement : Conforme au data_generator.sql (colonnes exactes insérées)
-- Exécuter   : D'abord sur CERGY_SITE, puis sur PAU_SITE
-- =============================================================================
 
 
-- =============================================================================
-- PARTIE 1 : SUPPRESSION DES TABLES EXISTANTES
-- Ordre inverse des dépendances FK pour éviter les erreurs de contraintes
-- =============================================================================

 
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE Ticket CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE Affectation CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE Materiel CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE Utilisateur CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE EquipementReseau CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE Reseau CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE Bureau CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE Salle CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE Batiment CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE seq_bureau';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/


 
-- =============================================================================
-- PARTIE 2 : INFRASTRUCTURE PHYSIQUE
-- =============================================================================

CREATE TABLE Batiment (
    id_batiment INT PRIMARY KEY,
    nom VARCHAR2(100),
    id_site INT
);

CREATE TABLE Salle (
    id_salle INT PRIMARY KEY,
    nom VARCHAR2(100),
    id_batiment INT
);

-- Bureau : id via séquence (seq_bureau.NEXTVAL utilisé dans le generator)
CREATE SEQUENCE seq_bureau START WITH 1 INCREMENT BY 1 NOCACHE;
 
CREATE TABLE Bureau (
    id INT PRIMARY KEY
);

-- =============================================================================
-- PARTIE 3 : RÉSEAU
-- =============================================================================

CREATE TABLE Reseau (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    ip_range VARCHAR2(50) NOT NULL,
    vlan VARCHAR2(20),
    id_site INT NOT NULL
);

CREATE TABLE EquipementReseau (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nom VARCHAR2(100) NOT NULL,
    type VARCHAR2(50) NOT NULL,
    id_reseau INT NOT NULL,
    CONSTRAINT fk_equip_reseau FOREIGN KEY (id_reseau) REFERENCES Reseau(id)
);

-- =============================================================================
-- PARTIE 4 : UTILISATEURS
-- Tables de référence (Role, Permission, RolePermission) disponibles via
-- les vues matérialisées répliquées depuis le HUB.
-- =============================================================================

CREATE TABLE Utilisateur (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nom VARCHAR2(255),
    email VARCHAR2(100),
    mot_passe_hash VARCHAR2(64),
    id_site INT,
    id_role INT,
    CONSTRAINT fk_user_role FOREIGN KEY (id_role) REFERENCES Role(id)
);
 
-- =============================================================================
-- PARTIE 5 : PARC MATÉRIEL
-- =============================================================================

CREATE TABLE Materiel (
    id           INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nom          VARCHAR2(100) NOT NULL,
    type         VARCHAR2(50)  NOT NULL,
    numero_serie VARCHAR2(20)  NOT NULL,
    id_site      INT           NOT NULL,
    statut       VARCHAR2(30)  DEFAULT 'disponible' NOT NULL,
    CONSTRAINT uq_materiel_serie UNIQUE (numero_serie),
    CONSTRAINT ck_materiel_type   CHECK (type   IN ('PC', 'Imprimante', 'Ecran')),
    CONSTRAINT ck_materiel_statut CHECK (statut IN ('disponible', 'affecte', 'maintenance', 'hors_service'))
);

CREATE TABLE Affectation (
    id             INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_utilisateur INT  NOT NULL,
    id_materiel    INT  NOT NULL,
    date_debut     DATE DEFAULT SYSDATE NOT NULL,
    date_fin       DATE,
    CONSTRAINT fk_affect_utilisateur FOREIGN KEY (id_utilisateur) REFERENCES Utilisateur(id),
    CONSTRAINT fk_affect_materiel    FOREIGN KEY (id_materiel)    REFERENCES Materiel(id),
    CONSTRAINT ck_affect_dates       CHECK (date_fin IS NULL OR date_fin >= date_debut)
);

CREATE TABLE Ticket (
    id             INT           GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_technicien  INT,
    id_utilisateur INT           NOT NULL,
    id_materiel    INT           NOT NULL,
    description    VARCHAR2(500) NOT NULL,
    statut         VARCHAR2(30)  DEFAULT 'ouvert' NOT NULL,
    date_creation  DATE          DEFAULT SYSDATE NOT NULL,
    CONSTRAINT fk_ticket_technicien  FOREIGN KEY (id_technicien)  REFERENCES Utilisateur(id),
    CONSTRAINT fk_ticket_utilisateur FOREIGN KEY (id_utilisateur) REFERENCES Utilisateur(id),
    CONSTRAINT fk_ticket_materiel    FOREIGN KEY (id_materiel)    REFERENCES Materiel(id),
    CONSTRAINT ck_ticket_statut      CHECK (statut IN ('ouvert', 'en_cours', 'en_attente', 'resolu', 'ferme', 'clos'))
);

-- =============================================================================
-- PARTIE 6 : VUES DE CONSOLIDATION SUR LE HUB (CYGLPI_HUB)
-- Se connecter sur CYGLPI_HUB avant d'exécuter cette section
-- =============================================================================

-- infrastructure physique
CREATE OR REPLACE VIEW V_ALL_BATIMENTS AS
    SELECT * FROM Batiment@cergy_link UNION ALL SELECT * FROM Batiment@pau_link;

CREATE OR REPLACE VIEW V_ALL_SALLES AS
    SELECT * FROM Salle@cergy_link UNION ALL SELECT * FROM Salle@pau_link;

CREATE OR REPLACE VIEW V_ALL_BUREAUX AS
    SELECT * FROM Bureau@cergy_link UNION ALL SELECT * FROM Bureau@pau_link;

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
    