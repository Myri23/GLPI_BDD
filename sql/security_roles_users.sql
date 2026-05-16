-- =====================================================================
-- FICHIER  : security_roles_users.sql
-- OBJET    : Création des rôles BDD et gouvernance des accès
-- =====================================================================

-- 1. Nettoyage sécurisé des anciens rôles
BEGIN
   FOR r IN (SELECT role FROM dba_roles WHERE role IN ('ROLE_ADMIN', 'ROLE_TECHNICIEN', 'ROLE_UTILISATEUR')) LOOP
      EXECUTE IMMEDIATE 'DROP ROLE ' || r.role;
   END LOOP;
END;
/

-- 2. Création des rôles
CREATE ROLE ROLE_ADMIN;
CREATE ROLE ROLE_TECHNICIEN;
CREATE ROLE ROLE_UTILISATEUR;

-- 3. Privilèges de connexion
GRANT CREATE SESSION TO ROLE_ADMIN, ROLE_TECHNICIEN, ROLE_UTILISATEUR;

-- 4. Attribution des droits selon chaque rôle

-- Rôle UTILISATEUR : Peut juste consulter les catalogues et gérer ses propres tickets
GRANT SELECT ON Materiel TO ROLE_UTILISATEUR;
GRANT SELECT ON Affectation TO ROLE_UTILISATEUR;
GRANT SELECT, INSERT ON Ticket TO ROLE_UTILISATEUR;

-- Rôle TECHNICIEN : Gère le matériel, les affectations et résout les tickets
GRANT SELECT, INSERT, UPDATE ON Materiel TO ROLE_TECHNICIEN;
GRANT SELECT, INSERT, UPDATE ON Affectation TO ROLE_TECHNICIEN;
GRANT SELECT, INSERT, UPDATE ON Ticket TO ROLE_TECHNICIEN;
GRANT SELECT ON Utilisateur TO ROLE_TECHNICIEN;
GRANT SELECT ON Site TO ROLE_TECHNICIEN;
GRANT SELECT ON Reseau TO ROLE_TECHNICIEN;
GRANT SELECT ON EquipementReseau TO ROLE_TECHNICIEN;

-- Rôle ADMIN : Accès total sur tout le périmètre applicatif
GRANT ALL PRIVILEGES ON Site TO ROLE_ADMIN;
GRANT ALL PRIVILEGES ON Batiment TO ROLE_ADMIN;
GRANT ALL PRIVILEGES ON Salle TO ROLE_ADMIN;
GRANT ALL PRIVILEGES ON Bureau TO ROLE_ADMIN;
GRANT ALL PRIVILEGES ON Reseau TO ROLE_ADMIN;
GRANT ALL PRIVILEGES ON EquipementReseau TO ROLE_ADMIN;
GRANT ALL PRIVILEGES ON Materiel TO ROLE_ADMIN;
GRANT ALL PRIVILEGES ON Utilisateur TO ROLE_ADMIN;
GRANT ALL PRIVILEGES ON Affectation TO ROLE_ADMIN;
GRANT ALL PRIVILEGES ON Ticket TO ROLE_ADMIN;
GRANT ALL PRIVILEGES ON Role TO ROLE_ADMIN;
GRANT ALL PRIVILEGES ON Permission TO ROLE_ADMIN;
GRANT ALL PRIVILEGES ON RolePermission TO ROLE_ADMIN;