
-- =============================================================================
-- SCRIPT 04: REPLICATION DES DONNEES DE REFERENCE
-- Objectif : Créer les tables maîtres sur le HUB et les répliquer sur les sites
-- Tables concernées : Site, Role, Permission, RolePermission
-- =============================================================================

--------------------------------------------------------------------------------
-- CONFIGURATION SUR LE HUB (CYGLPI_HUB)
--------------------------------------------------------------------------------

-- Création des tables "Maîtres"
CREATE TABLE Site (
    id_site INT PRIMARY KEY,
    nom VARCHAR2(100)
);

CREATE TABLE Role (
    id_role INT PRIMARY KEY,
    nom VARCHAR2(100)
);

CREATE TABLE Permission (
    id_permission INT PRIMARY KEY,
    nom VARCHAR2(100)
);

CREATE TABLE RolePermission (
    id_role INT,
    id_permission INT,
    CONSTRAINT pk_role_perm PRIMARY KEY (id_role, id_permission)
);

-- CONFIGURATION SUR LE SITE DE CERGY (CERGY_SITE)
-- Puis sur le site de PAU (PAU_SITE)

-- Création du lien vers le HUB pour permettre la réplication
CREATE DATABASE LINK hub_link 
CONNECT TO CYGLPI_HUB IDENTIFIED BY amsterdam 
USING 'localhost:1521/XEPDB1';

-- Création des Vues Matérialisées (Réplication locale)
CREATE MATERIALIZED VIEW Site
REFRESH COMPLETE ON DEMAND
AS SELECT * FROM Site@hub_link;

CREATE MATERIALIZED VIEW Role
REFRESH COMPLETE ON DEMAND
AS SELECT * FROM Role@hub_link;

CREATE MATERIALIZED VIEW Permission
REFRESH COMPLETE ON DEMAND
AS SELECT * FROM Permission@hub_link;

CREATE MATERIALIZED VIEW RolePermission
REFRESH COMPLETE ON DEMAND
AS SELECT * FROM RolePermission@hub_link;

