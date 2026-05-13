-- SUPPRESSION DES TABLES (si elles existent déjà)

DROP TABLE IF EXISTS RolePermission CASCADE CONSTRAINTS;
DROP TABLE IF EXISTS Permission CASCADE CONSTRAINTS;
DROP TABLE IF EXISTS Role CASCADE CONSTRAINTS;
DROP TABLE IF EXISTS Ticket CASCADE CONSTRAINTS;
DROP TABLE IF EXISTS Affectation CASCADE CONSTRAINTS;
DROP TABLE IF EXISTS Materiel CASCADE CONSTRAINTS;
DROP TABLE IF EXISTS EquipementReseau CASCADE CONSTRAINTS;
DROP TABLE IF EXISTS Reseau CASCADE CONSTRAINTS;
DROP TABLE IF EXISTS Bureau CASCADE CONSTRAINTS;
DROP TABLE IF EXISTS Salle CASCADE CONSTRAINTS;
DROP TABLE IF EXISTS Batiment CASCADE CONSTRAINTS;
DROP TABLE IF EXISTS Site CASCADE CONSTRAINTS;

-- Suppression des séquences
DROP SEQUENCE IF EXISTS seq_site;
DROP SEQUENCE IF EXISTS seq_batiment;
DROP SEQUENCE IF EXISTS seq_salle;
DROP SEQUENCE IF EXISTS seq_bureau;
DROP SEQUENCE IF EXISTS seq_reseau;
DROP SEQUENCE IF EXISTS seq_equipement_reseau;
DROP SEQUENCE IF EXISTS seq_materiel;
DROP SEQUENCE IF EXISTS seq_utilisateur;
DROP SEQUENCE IF EXISTS seq_affectation;
DROP SEQUENCE IF EXISTS seq_ticket;
DROP SEQUENCE IF EXISTS seq_role;
DROP SEQUENCE IF EXISTS seq_permission;
DROP SEQUENCE IF EXISTS seq_role_permission;

-- CRÉATION DES SÉQUENCES (pour l'auto-incrémentation)

CREATE SEQUENCE seq_site START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_batiment START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_salle START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_bureau START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_reseau START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_equipement_reseau START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_materiel START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_utilisateur START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_affectation START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_ticket START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_role START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_permission START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_role_permission START WITH 1 INCREMENT BY 1;

-- TABLES PRINCIPALES

-- Table Site
CREATE TABLE Site (
    id NUMBER PRIMARY KEY,
    nom VARCHAR2(255) NOT NULL,
    ville VARCHAR2(255) NOT NULL
);

-- Table Bâtiment
CREATE TABLE Batiment (
    id NUMBER PRIMARY KEY,
    id_site NUMBER NOT NULL,
    CONSTRAINT fk_batiment_site FOREIGN KEY (id_site) REFERENCES Site(id)
);

-- Table Salle
CREATE TABLE Salle (
    id NUMBER PRIMARY KEY,
    id_batiment NUMBER NOT NULL,
    CONSTRAINT fk_salle_batiment FOREIGN KEY (id_batiment) REFERENCES Batiment(id)
);

-- Table Bureau
CREATE TABLE Bureau (
    id NUMBER PRIMARY KEY
);

-- Table Réseau
CREATE TABLE Reseau (
    id NUMBER PRIMARY KEY,
    ip_range VARCHAR2(50) NOT NULL,
    wan VARCHAR2(100) NOT NULL,
    id_site NUMBER NOT NULL,
    CONSTRAINT fk_reseau_site FOREIGN KEY (id_site) REFERENCES Site(id)
);

-- Table EquipementReseau
CREATE TABLE EquipementReseau (
    id NUMBER PRIMARY KEY,
    nom VARCHAR2(255) NOT NULL,
    type VARCHAR2(50) NOT NULL, -- Serveur, Switch, Routeur
    id_reseau NUMBER NOT NULL,
    CONSTRAINT fk_equipement_reseau FOREIGN KEY (id_reseau) REFERENCES Reseau(id),
    CONSTRAINT chk_type_equipement CHECK (type IN ('Serveur', 'Switch', 'Routeur'))
);

-- Table Role (à créer AVANT Utilisateur)
CREATE TABLE Role (
    id NUMBER PRIMARY KEY,
    nom VARCHAR2(100) NOT NULL UNIQUE
);

-- Table Materiel
CREATE TABLE Materiel (
    id NUMBER PRIMARY KEY,
    nom VARCHAR2(255) NOT NULL,
    type VARCHAR2(50) NOT NULL, -- PC, Imprimante, Ecran
    numero_serie VARCHAR2(255) UNIQUE NOT NULL,
    id_site NUMBER NOT NULL,
    statut VARCHAR2(50) NOT NULL,
    CONSTRAINT fk_materiel_site FOREIGN KEY (id_site) REFERENCES Site(id),
    CONSTRAINT chk_type_materiel CHECK (type IN ('PC', 'Imprimante', 'Ecran'))
);

-- Table Utilisateur
CREATE TABLE Utilisateur (
    id NUMBER PRIMARY KEY,
    nom VARCHAR2(255) NOT NULL,
    email VARCHAR2(255) NOT NULL UNIQUE,
    mot_passe_hash VARCHAR2(255) NOT NULL,
    id_site NUMBER NOT NULL,
    id_role NUMBER NOT NULL,
    CONSTRAINT fk_utilisateur_site FOREIGN KEY (id_site) REFERENCES Site(id),
    CONSTRAINT fk_utilisateur_role FOREIGN KEY (id_role) REFERENCES Role(id)
);

-- Table Affectation
CREATE TABLE Affectation (
    id NUMBER PRIMARY KEY,
    id_utilisateur NUMBER NOT NULL,
    id_materiel NUMBER NOT NULL,
    date_debut TIMESTAMP NOT NULL,
    date_fin TIMESTAMP,
    CONSTRAINT fk_affectation_utilisateur FOREIGN KEY (id_utilisateur) REFERENCES Utilisateur(id),
    CONSTRAINT fk_affectation_materiel FOREIGN KEY (id_materiel) REFERENCES Materiel(id)
);

-- Table Ticket
CREATE TABLE Ticket (
    id NUMBER PRIMARY KEY,
    id_technicien NUMBER,
    id_utilisateur NUMBER NOT NULL,
    id_materiel NUMBER NOT NULL,
    description CLOB NOT NULL,
    statut VARCHAR2(50) NOT NULL,
    date_creation TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT fk_ticket_technicien FOREIGN KEY (id_technicien) REFERENCES Utilisateur(id),
    CONSTRAINT fk_ticket_utilisateur FOREIGN KEY (id_utilisateur) REFERENCES Utilisateur(id),
    CONSTRAINT fk_ticket_materiel FOREIGN KEY (id_materiel) REFERENCES Materiel(id)
);

-- TABLES DE GESTION DES PERMISSIONS (RBAC)

-- Table Permission
CREATE TABLE Permission (
    id NUMBER PRIMARY KEY,
    nom VARCHAR2(100) NOT NULL UNIQUE
);

-- Table de liaison RolePermission (Many-to-Many)
CREATE TABLE RolePermission (
    id_rolePermission NUMBER PRIMARY KEY,
    id_role NUMBER NOT NULL,
    id_permission NUMBER NOT NULL,
    CONSTRAINT fk_roleperm_role FOREIGN KEY (id_role) REFERENCES Role(id) ON DELETE CASCADE,
    CONSTRAINT fk_roleperm_permission FOREIGN KEY (id_permission) REFERENCES Permission(id) ON DELETE CASCADE,
    CONSTRAINT uk_role_permission UNIQUE (id_role, id_permission)
);

-- TRIGGERS POUR AUTO-INCREMENT

CREATE OR REPLACE TRIGGER trg_site_id
BEFORE INSERT ON Site
FOR EACH ROW
BEGIN
    IF :NEW.id IS NULL THEN
        SELECT seq_site.NEXTVAL INTO :NEW.id FROM dual;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_batiment_id
BEFORE INSERT ON Batiment
FOR EACH ROW
BEGIN
    IF :NEW.id IS NULL THEN
        SELECT seq_batiment.NEXTVAL INTO :NEW.id FROM dual;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_salle_id
BEFORE INSERT ON Salle
FOR EACH ROW
BEGIN
    IF :NEW.id IS NULL THEN
        SELECT seq_salle.NEXTVAL INTO :NEW.id FROM dual;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_bureau_id
BEFORE INSERT ON Bureau
FOR EACH ROW
BEGIN
    IF :NEW.id IS NULL THEN
        SELECT seq_bureau.NEXTVAL INTO :NEW.id FROM dual;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_reseau_id
BEFORE INSERT ON Reseau
FOR EACH ROW
BEGIN
    IF :NEW.id IS NULL THEN
        SELECT seq_reseau.NEXTVAL INTO :NEW.id FROM dual;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_equipement_reseau_id
BEFORE INSERT ON EquipementReseau
FOR EACH ROW
BEGIN
    IF :NEW.id IS NULL THEN
        SELECT seq_equipement_reseau.NEXTVAL INTO :NEW.id FROM dual;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_materiel_id
BEFORE INSERT ON Materiel
FOR EACH ROW
BEGIN
    IF :NEW.id IS NULL THEN
        SELECT seq_materiel.NEXTVAL INTO :NEW.id FROM dual;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_utilisateur_id
BEFORE INSERT ON Utilisateur
FOR EACH ROW
BEGIN
    IF :NEW.id IS NULL THEN
        SELECT seq_utilisateur.NEXTVAL INTO :NEW.id FROM dual;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_affectation_id
BEFORE INSERT ON Affectation
FOR EACH ROW
BEGIN
    IF :NEW.id IS NULL THEN
        SELECT seq_affectation.NEXTVAL INTO :NEW.id FROM dual;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_ticket_id
BEFORE INSERT ON Ticket
FOR EACH ROW
BEGIN
    IF :NEW.id IS NULL THEN
        SELECT seq_ticket.NEXTVAL INTO :NEW.id FROM dual;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_role_id
BEFORE INSERT ON Role
FOR EACH ROW
BEGIN
    IF :NEW.id IS NULL THEN
        SELECT seq_role.NEXTVAL INTO :NEW.id FROM dual;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_permission_id
BEFORE INSERT ON Permission
FOR EACH ROW
BEGIN
    IF :NEW.id IS NULL THEN
        SELECT seq_permission.NEXTVAL INTO :NEW.id FROM dual;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_role_permission_id
BEFORE INSERT ON RolePermission
FOR EACH ROW
BEGIN
    IF :NEW.id_rolePermission IS NULL THEN
        SELECT seq_role_permission.NEXTVAL INTO :NEW.id_rolePermission FROM dual;
    END IF;
END;
/

-- INDEX POUR OPTIMISATION DES PERFORMANCES

CREATE INDEX idx_batiment_site ON Batiment(id_site);
CREATE INDEX idx_salle_batiment ON Salle(id_batiment);
CREATE INDEX idx_reseau_site ON Reseau(id_site);
CREATE INDEX idx_equipement_reseau ON EquipementReseau(id_reseau);
CREATE INDEX idx_materiel_site ON Materiel(id_site);
CREATE INDEX idx_materiel_statut ON Materiel(statut);
CREATE INDEX idx_utilisateur_site ON Utilisateur(id_site);
CREATE INDEX idx_utilisateur_role ON Utilisateur(id_role);
CREATE INDEX idx_affectation_utilisateur ON Affectation(id_utilisateur);
CREATE INDEX idx_affectation_materiel ON Affectation(id_materiel);
CREATE INDEX idx_ticket_technicien ON Ticket(id_technicien);
CREATE INDEX idx_ticket_utilisateur ON Ticket(id_utilisateur);
CREATE INDEX idx_ticket_statut ON Ticket(statut);

-- DONNÉES D'EXEMPLE

-- Insertion des sites
INSERT INTO Site (nom, ville) VALUES ('Site Cergy', 'Cergy');
INSERT INTO Site (nom, ville) VALUES ('Site Pau', 'Pau');

-- Insertion des rôles
INSERT INTO Role (nom) VALUES ('Admin');
INSERT INTO Role (nom) VALUES ('Technicien');
INSERT INTO Role (nom) VALUES ('Utilisateur');

-- Insertion des permissions
INSERT INTO Permission (nom) VALUES ('READ');
INSERT INTO Permission (nom) VALUES ('WRITE');
INSERT INTO Permission (nom) VALUES ('DELETE');

-- Association des permissions aux rôles
-- Admin a toutes les permissions
INSERT INTO RolePermission (id_role, id_permission) VALUES (1, 1);
INSERT INTO RolePermission (id_role, id_permission) VALUES (1, 2);
INSERT INTO RolePermission (id_role, id_permission) VALUES (1, 3);

-- Technicien a READ et WRITE
INSERT INTO RolePermission (id_role, id_permission) VALUES (2, 1);
INSERT INTO RolePermission (id_role, id_permission) VALUES (2, 2);

-- Utilisateur a seulement READ
INSERT INTO RolePermission (id_role, id_permission) VALUES (3, 1);

COMMIT;