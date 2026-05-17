
-- =============================================================================
-- SCRIPT 04: REPLICATION DES DONNEES DE REFERENCE
-- Objectif : Créer les tables maîtres sur le HUB et les répliquer sur les sites
-- Tables concernées : Site, Role, Permission, RolePermission
-- =============================================================================

-- =============================================================================
-- PARTIE 1 : SUPPRESSION DES OBJETS EXISTANTS SUR LE HUB (CYGLPI_HUB)
-- Exécuter connecté en CYGLPI_HUB
-- =============================================================================

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE RolePermission CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE Permission CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE Role CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN   
    EXECUTE IMMEDIATE 'DROP TABLE Site CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

-- =============================================================================
-- PARTIE 2 : CRÉATION DES TABLES MAÎTRES SUR LE HUB (CYGLPI_HUB)
-- =============================================================================

CREATE TABLE Site (
    id INT PRIMARY KEY,
    nom VARCHAR2(100),
    ville VARCHAR2(100)
);

CREATE TABLE Role (
    id INT PRIMARY KEY,
    nom VARCHAR2(100) NOT NULL,
        CONSTRAINT uq_role_nom UNIQUE (nom)
);

CREATE TABLE Permission (
    id_permission INT PRIMARY KEY,
    nom VARCHAR2(100) NOT NULL,
    CONSTRAINT uq_permission_nom UNIQUE (nom)
);

CREATE TABLE RolePermission (
    id_role INT NOT NULL,
    id_permission INT NOT NULL,
    CONSTRAINT pk_role_perm PRIMARY KEY (id_role, id_permission),
    CONSTRAINT fk_role FOREIGN KEY (id_role) REFERENCES Role(id),
    CONSTRAINT fk_permission FOREIGN KEY (id_permission) REFERENCES Permission(id)
);

-- =============================================================================
-- PARTIE 3 : SUPPRESSION DES VUES MATÉRIALISÉES SUR LES SITES
-- Exécuter connecté en CERGY_SITE, puis en PAU_SITE
-- =============================================================================

BEGIN
    EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW RolePermission';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW Permission';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW Role';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/
BEGIN
    EXECUTE IMMEDIATE 'DROP MATERIALIZED VIEW Site';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/


-- =============================================================================
-- PARTIE 4 : CRÉATION DU DB LINK VERS LE HUB (CERGY_SITE et PAU_SITE) pour la réplication
-- Exécuter connecté en CERGY_SITE, puis refaire en PAU_SITE
-- =============================================================================

CREATE DATABASE LINK hub_link 
CONNECT TO CYGLPI_HUB IDENTIFIED BY amsterdam 
USING 'localhost:1521/XEPDB1';

-- =============================================================================
-- PARTIE 6 : VUES MATÉRIALISÉES DE RÉPLICATION (CERGY_SITE et PAU_SITE)
-- Réplication complète à la demande (REFRESH COMPLETE ON DEMAND)
-- =============================================================================

CREATE MATERIALIZED VIEW Site
REFRESH COMPLETE ON DEMAND
AS SELECT * FROM Site@hub_link;
-- AS SELECT id, nom, ville FROM Site@hub_link;

CREATE MATERIALIZED VIEW Role
REFRESH COMPLETE ON DEMAND
AS SELECT * FROM Role@hub_link;

CREATE MATERIALIZED VIEW Permission
REFRESH COMPLETE ON DEMAND
AS SELECT * FROM Permission@hub_link;

CREATE MATERIALIZED VIEW RolePermission
REFRESH COMPLETE ON DEMAND
AS SELECT * FROM RolePermission@hub_link;

-- =============================================================================
-- PARTIE 7 : RAFRAÎCHISSEMENT INITIAL DES VUES MATÉRIALISÉES
-- Exécuter après l'insertion des données de référence sur le HUB
-- A exécuter sur CERGY_SITE, puis sur PAU_SITE
-- =============================================================================

EXEC DBMS_MVIEW.REFRESH('Site', 'C');
EXEC DBMS_MVIEW.REFRESH('Role', 'C');
EXEC DBMS_MVIEW.REFRESH('Permission', 'C');
EXEC DBMS_MVIEW.REFRESH('RolePermission', 'C');


