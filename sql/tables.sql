-- =====================================================================
-- DDL principal — schéma applicatif CY Tech (Oracle)
-- Prérequis : @sql/00_drop_schema.sql puis @sql/tablespaces.sql
-- =====================================================================

-- CRÉATION DES SÉQUENCES
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

-- Cluster sur Batiment : regroupement physique par site (notion cours)
BEGIN
   EXECUTE IMMEDIATE 'CREATE CLUSTER cluster_batiment_site (id_site NUMBER) SIZE 512';
EXCEPTION
   WHEN OTHERS THEN
      IF SQLCODE != -955 THEN RAISE; END IF;
END;
/
BEGIN
   EXECUTE IMMEDIATE 'CREATE INDEX idx_cluster_batiment_site ON CLUSTER cluster_batiment_site';
EXCEPTION
   WHEN OTHERS THEN
      IF SQLCODE NOT IN (-955, -2033) THEN RAISE; END IF;
END;
/

-- TABLES PRINCIPALES
CREATE TABLE Site (
    id NUMBER PRIMARY KEY,
    nom VARCHAR2(255) NOT NULL,
    ville VARCHAR2(255) NOT NULL
);

CREATE TABLE Batiment (
    id NUMBER PRIMARY KEY,
    nom VARCHAR2(255),
    id_site NUMBER NOT NULL,
    CONSTRAINT fk_batiment_site FOREIGN KEY (id_site) REFERENCES Site(id)
) CLUSTER cluster_batiment_site (id_site);

CREATE TABLE Salle (
    id NUMBER PRIMARY KEY,
    nom VARCHAR2(255),
    id_batiment NUMBER NOT NULL,
    CONSTRAINT fk_salle_batiment FOREIGN KEY (id_batiment) REFERENCES Batiment(id)
);

CREATE TABLE Bureau (
    id NUMBER PRIMARY KEY,
    id_salle NUMBER,
    CONSTRAINT fk_bureau_salle FOREIGN KEY (id_salle) REFERENCES Salle(id)
);

CREATE TABLE Reseau (
    id NUMBER PRIMARY KEY,
    ip_range VARCHAR2(50) NOT NULL,
    wan VARCHAR2(100) NOT NULL,
    vlan VARCHAR2(50),
    id_site NUMBER NOT NULL,
    CONSTRAINT fk_reseau_site FOREIGN KEY (id_site) REFERENCES Site(id)
);

CREATE TABLE EquipementReseau (
    id NUMBER PRIMARY KEY,
    nom VARCHAR2(255) NOT NULL,
    type VARCHAR2(50) NOT NULL,
    id_reseau NUMBER NOT NULL,
    CONSTRAINT fk_equipement_reseau FOREIGN KEY (id_reseau) REFERENCES Reseau(id),
    CONSTRAINT chk_type_equipement CHECK (type IN ('Serveur', 'Switch', 'Routeur'))
);

CREATE TABLE Role (
    id NUMBER PRIMARY KEY,
    nom VARCHAR2(100) NOT NULL UNIQUE
);

CREATE TABLE Materiel (
    id NUMBER NOT NULL,
    nom VARCHAR2(255) NOT NULL,
    type VARCHAR2(50) NOT NULL,
    numero_serie VARCHAR2(255) NOT NULL,
    id_site NUMBER NOT NULL,
    statut VARCHAR2(50) NOT NULL,
    CONSTRAINT pk_materiel PRIMARY KEY (id),
    CONSTRAINT uk_materiel_serial UNIQUE (numero_serie),
    CONSTRAINT fk_materiel_site FOREIGN KEY (id_site) REFERENCES Site(id),
    CONSTRAINT chk_type_materiel CHECK (type IN ('PC', 'Imprimante', 'Ecran')),
    CONSTRAINT chk_materiel_statut CHECK (statut IN (
        'disponible', 'affecte', 'maintenance', 'hors_service'
    ))
)
PARTITION BY LIST (id_site) (
    PARTITION p_cergy VALUES (1),
    PARTITION p_pau VALUES (2));

CREATE TABLE Utilisateur (
    id NUMBER PRIMARY KEY,
    nom VARCHAR2(255) NOT NULL,
    prenom VARCHAR2(255),
    login VARCHAR2(100),
    email VARCHAR2(255) NOT NULL,
    mot_passe_hash VARCHAR2(255) NOT NULL,
    est_actif NUMBER(1) DEFAULT 1 NOT NULL,
    id_site NUMBER NOT NULL,
    id_role NUMBER NOT NULL,
    CONSTRAINT fk_utilisateur_site FOREIGN KEY (id_site) REFERENCES Site(id),
    CONSTRAINT fk_utilisateur_role FOREIGN KEY (id_role) REFERENCES Role(id),
    CONSTRAINT chk_utilisateur_actif CHECK (est_actif IN (0, 1))
);

CREATE TABLE Affectation (
    id NUMBER PRIMARY KEY,
    id_utilisateur NUMBER NOT NULL,
    id_materiel NUMBER NOT NULL,
    date_debut TIMESTAMP NOT NULL,
    date_fin TIMESTAMP,
    CONSTRAINT fk_affectation_utilisateur FOREIGN KEY (id_utilisateur) REFERENCES Utilisateur(id),
    CONSTRAINT fk_affectation_materiel FOREIGN KEY (id_materiel) REFERENCES Materiel(id)
);

CREATE TABLE Ticket (
    id NUMBER PRIMARY KEY,
    id_technicien NUMBER,
    id_utilisateur NUMBER NOT NULL,
    id_materiel NUMBER NOT NULL,
    description CLOB NOT NULL,
    statut VARCHAR2(50) NOT NULL,
    priorite VARCHAR2(20) DEFAULT 'normale',
    date_creation TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    date_resolution TIMESTAMP,
    CONSTRAINT fk_ticket_technicien FOREIGN KEY (id_technicien) REFERENCES Utilisateur(id),
    CONSTRAINT fk_ticket_utilisateur FOREIGN KEY (id_utilisateur) REFERENCES Utilisateur(id),
    CONSTRAINT fk_ticket_materiel FOREIGN KEY (id_materiel) REFERENCES Materiel(id)
);

CREATE TABLE Permission (
    id NUMBER PRIMARY KEY,
    nom VARCHAR2(100) NOT NULL UNIQUE,
    description VARCHAR2(255)
);

CREATE TABLE RolePermission (
    id_rolePermission NUMBER PRIMARY KEY,
    id_role NUMBER NOT NULL,
    id_permission NUMBER NOT NULL,
    CONSTRAINT fk_roleperm_role FOREIGN KEY (id_role) REFERENCES Role(id) ON DELETE CASCADE,
    CONSTRAINT fk_roleperm_permission FOREIGN KEY (id_permission) REFERENCES Permission(id) ON DELETE CASCADE,
    CONSTRAINT uk_role_permission UNIQUE (id_role, id_permission)
);

-- TRIGGERS AUTO-INCREMENT
CREATE OR REPLACE TRIGGER trg_site_id
BEFORE INSERT ON Site FOR EACH ROW
BEGIN
    IF :NEW.id IS NULL THEN SELECT seq_site.NEXTVAL INTO :NEW.id FROM dual; END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_batiment_id
BEFORE INSERT ON Batiment FOR EACH ROW
BEGIN
    IF :NEW.id IS NULL THEN SELECT seq_batiment.NEXTVAL INTO :NEW.id FROM dual; END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_salle_id
BEFORE INSERT ON Salle FOR EACH ROW
BEGIN
    IF :NEW.id IS NULL THEN SELECT seq_salle.NEXTVAL INTO :NEW.id FROM dual; END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_bureau_id
BEFORE INSERT ON Bureau FOR EACH ROW
BEGIN
    IF :NEW.id IS NULL THEN SELECT seq_bureau.NEXTVAL INTO :NEW.id FROM dual; END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_reseau_id
BEFORE INSERT ON Reseau FOR EACH ROW
BEGIN
    IF :NEW.id IS NULL THEN SELECT seq_reseau.NEXTVAL INTO :NEW.id FROM dual; END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_equipement_reseau_id
BEFORE INSERT ON EquipementReseau FOR EACH ROW
BEGIN
    IF :NEW.id IS NULL THEN SELECT seq_equipement_reseau.NEXTVAL INTO :NEW.id FROM dual; END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_materiel_id
BEFORE INSERT ON Materiel FOR EACH ROW
BEGIN
    IF :NEW.id IS NULL THEN SELECT seq_materiel.NEXTVAL INTO :NEW.id FROM dual; END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_utilisateur_id
BEFORE INSERT ON Utilisateur FOR EACH ROW
BEGIN
    IF :NEW.id IS NULL THEN SELECT seq_utilisateur.NEXTVAL INTO :NEW.id FROM dual; END IF;
    IF :NEW.login IS NULL THEN :NEW.login := LOWER(:NEW.email); END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_affectation_id
BEFORE INSERT ON Affectation FOR EACH ROW
BEGIN
    IF :NEW.id IS NULL THEN SELECT seq_affectation.NEXTVAL INTO :NEW.id FROM dual; END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_ticket_id
BEFORE INSERT ON Ticket FOR EACH ROW
BEGIN
    IF :NEW.id IS NULL THEN SELECT seq_ticket.NEXTVAL INTO :NEW.id FROM dual; END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_role_id
BEFORE INSERT ON Role FOR EACH ROW
BEGIN
    IF :NEW.id IS NULL THEN SELECT seq_role.NEXTVAL INTO :NEW.id FROM dual; END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_permission_id
BEFORE INSERT ON Permission FOR EACH ROW
BEGIN
    IF :NEW.id IS NULL THEN SELECT seq_permission.NEXTVAL INTO :NEW.id FROM dual; END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_role_permission_id
BEFORE INSERT ON RolePermission FOR EACH ROW
BEGIN
    IF :NEW.id_rolePermission IS NULL THEN
        SELECT seq_role_permission.NEXTVAL INTO :NEW.id_rolePermission FROM dual;
    END IF;
END;
/

-- INDEX (tablespace ts_index)
CREATE INDEX idx_batiment_site ON Batiment(id_site);
CREATE INDEX idx_salle_batiment ON Salle(id_batiment);
CREATE INDEX idx_bureau_salle ON Bureau(id_salle);
CREATE INDEX idx_reseau_site ON Reseau(id_site);
CREATE INDEX idx_equipement_reseau ON EquipementReseau(id_reseau);
CREATE INDEX idx_materiel_statut ON Materiel(statut) LOCAL;
CREATE INDEX idx_materiel_type ON Materiel(type) LOCAL;
-- numero_serie : index unique via uk_materiel_serial
CREATE INDEX idx_utilisateur_site ON Utilisateur(id_site);
CREATE INDEX idx_utilisateur_role ON Utilisateur(id_role);
CREATE INDEX idx_utilisateur_login ON Utilisateur(login);
CREATE INDEX idx_affectation_utilisateur ON Affectation(id_utilisateur);
CREATE INDEX idx_affectation_materiel ON Affectation(id_materiel);
CREATE INDEX idx_ticket_technicien ON Ticket(id_technicien);
CREATE INDEX idx_ticket_utilisateur ON Ticket(id_utilisateur);
CREATE INDEX idx_ticket_statut ON Ticket(statut);
CREATE INDEX idx_ticket_site_materiel ON Ticket(id_materiel, statut);

-- DONNÉES DE RÉFÉRENCE MINIMALES
INSERT INTO Site (nom, ville) VALUES ('Site Cergy', 'Cergy');
INSERT INTO Site (nom, ville) VALUES ('Site Pau', 'Pau');

INSERT INTO Role (nom) VALUES ('Admin');
INSERT INTO Role (nom) VALUES ('Technicien');
INSERT INTO Role (nom) VALUES ('Utilisateur');

INSERT INTO Permission (nom, description) VALUES ('READ', 'Lecture');
INSERT INTO Permission (nom, description) VALUES ('WRITE', 'Ecriture');
INSERT INTO Permission (nom, description) VALUES ('DELETE', 'Suppression');

INSERT INTO RolePermission (id_role, id_permission) VALUES (1, 1);
INSERT INTO RolePermission (id_role, id_permission) VALUES (1, 2);
INSERT INTO RolePermission (id_role, id_permission) VALUES (1, 3);
INSERT INTO RolePermission (id_role, id_permission) VALUES (2, 1);
INSERT INTO RolePermission (id_role, id_permission) VALUES (2, 2);
INSERT INTO RolePermission (id_role, id_permission) VALUES (3, 1);

COMMIT;
