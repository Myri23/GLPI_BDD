-- CYGLPI_HUB : tables de référence répliquées vers les sites
CREATE TABLE Site (
    id NUMBER PRIMARY KEY,
    nom VARCHAR2(255) NOT NULL,
    ville VARCHAR2(255) NOT NULL
);

CREATE TABLE Role (
    id NUMBER PRIMARY KEY,
    nom VARCHAR2(100) NOT NULL UNIQUE
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
    CONSTRAINT uk_hub_role_perm UNIQUE (id_role, id_permission)
);

INSERT INTO Site VALUES (1, 'Site Cergy', 'Cergy');
INSERT INTO Site VALUES (2, 'Site Pau', 'Pau');
INSERT INTO Role VALUES (1, 'Admin');
INSERT INTO Role VALUES (2, 'Technicien');
INSERT INTO Role VALUES (3, 'Utilisateur');
INSERT INTO Permission VALUES (1, 'READ', 'Lecture');
INSERT INTO Permission VALUES (2, 'WRITE', 'Ecriture');
INSERT INTO Permission VALUES (3, 'DELETE', 'Suppression');
COMMIT;
