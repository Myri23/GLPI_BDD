-- =============================================================================
-- FICHIER  : data_generator.sql
-- OBJET    : Generateur PL/SQL complet d'un jeu de donnees realiste et
--            consequent pour valider la nouvelle architecture GLPI multi-sites
--            (Cergy / Pau) - STRICTEMENT ALIGNE SUR LE DIAGRAMME UML v3.
-- =============================================================================
-- TABLES GENEREES (conformes au diagramme UML) :
--   Site, Batiment, Salle, Bureau
--   Role, Permission, RolePermission
--   Utilisateur
--   Reseau, EquipementReseau
--   Materiel
--   Affectation
--   Ticket
-- =============================================================================


-- =============================================================================
-- 1. PARAMETRES DE VOLUMETRIE
-- =============================================================================

SET DEFINE OFF

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE GENERATEUR_CONFIG PURGE';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

CREATE TABLE GENERATEUR_CONFIG (
    CLE        VARCHAR2(60) PRIMARY KEY,
    VALEUR     NUMBER       NOT NULL,
    COMMENTAIRE VARCHAR2(200)
);

INSERT INTO GENERATEUR_CONFIG VALUES ('NB_UTILISATEURS_CERGY', 800,
    'Utilisateurs du site de Cergy');
INSERT INTO GENERATEUR_CONFIG VALUES ('NB_UTILISATEURS_PAU', 400,
    'Utilisateurs du site de Pau');
INSERT INTO GENERATEUR_CONFIG VALUES ('NB_MATERIELS_CERGY', 900,
    'Materiels (PC, Imprimante, Ecran) affectes a Cergy');
INSERT INTO GENERATEUR_CONFIG VALUES ('NB_MATERIELS_PAU', 450,
    'Materiels (PC, Imprimante, Ecran) affectes a Pau');
INSERT INTO GENERATEUR_CONFIG VALUES ('NB_EQUIPEMENTS_RESEAU', 80,
    'Equipements reseau (Serveur, Switch, Routeur)');
INSERT INTO GENERATEUR_CONFIG VALUES ('NB_RESEAUX', 50,
    'Reseaux informatiques par site');
INSERT INTO GENERATEUR_CONFIG VALUES ('NB_TICKETS', 5000,
    'Tickets historiques sur 3 ans');
INSERT INTO GENERATEUR_CONFIG VALUES ('SEED_ALEATOIRE', 42,
    'Graine pour reproductibilite');
COMMIT;


-- =============================================================================
-- 2. PACKAGE PKG_GENERATOR  (utilitaires internes)
-- =============================================================================

CREATE OR REPLACE PACKAGE PKG_GENERATOR AS
    FUNCTION rand_int(p_min IN NUMBER, p_max IN NUMBER) RETURN NUMBER;
    FUNCTION rand_date(p_debut IN DATE, p_fin IN DATE) RETURN DATE;
    FUNCTION pick(p_liste IN SYS.ODCIVARCHAR2LIST) RETURN VARCHAR2;
    FUNCTION gen_ip(p_base IN VARCHAR2) RETURN VARCHAR2;
    FUNCTION gen_mac RETURN VARCHAR2;
    FUNCTION gen_serial RETURN VARCHAR2;
    FUNCTION cfg(p_cle IN VARCHAR2) RETURN NUMBER;
    PROCEDURE log(p_msg IN VARCHAR2);
END PKG_GENERATOR;
/

CREATE OR REPLACE PACKAGE BODY PKG_GENERATOR AS

    FUNCTION rand_int(p_min IN NUMBER, p_max IN NUMBER) RETURN NUMBER IS
    BEGIN
        RETURN FLOOR(DBMS_RANDOM.VALUE(p_min, p_max + 1));
    END;

    FUNCTION rand_date(p_debut IN DATE, p_fin IN DATE) RETURN DATE IS
        v_ecart NUMBER;
    BEGIN
        v_ecart := p_fin - p_debut;
        RETURN p_debut + FLOOR(DBMS_RANDOM.VALUE(0, v_ecart + 1));
    END;

    FUNCTION pick(p_liste IN SYS.ODCIVARCHAR2LIST) RETURN VARCHAR2 IS
        v_idx PLS_INTEGER;
    BEGIN
        v_idx := rand_int(1, p_liste.COUNT);
        RETURN p_liste(v_idx);
    END;

    FUNCTION gen_ip(p_base IN VARCHAR2) RETURN VARCHAR2 IS
    BEGIN
        RETURN p_base || '.' || TO_CHAR(rand_int(2, 254));
    END;

    FUNCTION gen_mac RETURN VARCHAR2 IS
        v_mac VARCHAR2(17);
        FUNCTION octet RETURN VARCHAR2 IS
        BEGIN
            RETURN LPAD(TO_CHAR(rand_int(0, 255), 'XX'), 2, '0');
        END;
    BEGIN
        v_mac := octet||':'||octet||':'||octet||':'||octet||':'||octet||':'||octet;
        RETURN UPPER(v_mac);
    END;

    FUNCTION gen_serial RETURN VARCHAR2 IS
        v_chars  CONSTANT VARCHAR2(36) := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
        v_result VARCHAR2(12) := '';
        v_pos    PLS_INTEGER;
    BEGIN
        FOR i IN 1..12 LOOP
            v_pos    := rand_int(1, LENGTH(v_chars));
            v_result := v_result || SUBSTR(v_chars, v_pos, 1);
        END LOOP;
        RETURN v_result;
    END;

    FUNCTION cfg(p_cle IN VARCHAR2) RETURN NUMBER IS
        v_val NUMBER;
    BEGIN
        SELECT VALEUR INTO v_val FROM GENERATEUR_CONFIG WHERE CLE = p_cle;
        RETURN v_val;
    EXCEPTION WHEN NO_DATA_FOUND THEN RETURN 0;
    END;

    PROCEDURE log(p_msg IN VARCHAR2) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('[' || TO_CHAR(SYSTIMESTAMP,'HH24:MI:SS.FF3') || '] ' || p_msg);
    END;

END PKG_GENERATOR;
/


-- =============================================================================
-- 3. PACKAGE PKG_DATA_GEN  (generation metier - conforme au diagramme UML)
-- =============================================================================

CREATE OR REPLACE PACKAGE PKG_DATA_GEN AS
    -- Ordre d'execution respectant les dependances FK
    PROCEDURE gen_roles_permissions;   -- Role, Permission, RolePermission
    PROCEDURE gen_entites_base;        -- Site, Batiment, Salle, Bureau
    PROCEDURE gen_utilisateurs;        -- Utilisateur (FK -> Role, Site)
    PROCEDURE gen_reseaux;             -- Reseau (FK -> Site)
    PROCEDURE gen_equipements_reseau;  -- EquipementReseau (FK -> Reseau)
    PROCEDURE gen_materiels;           -- Materiel (FK -> Site)
    PROCEDURE gen_affectations;        -- Affectation (FK -> Utilisateur, Materiel)
    PROCEDURE gen_tickets;             -- Ticket (FK -> Utilisateur, Materiel)
    PROCEDURE run_all;
END PKG_DATA_GEN;
/

CREATE OR REPLACE PACKAGE BODY PKG_DATA_GEN AS

    -- =========================================================================
    -- 3.0  ROLES, PERMISSIONS, ROLEPERMISSION
    --      Attributs UML :
    --        Role          : id {id}, nom
    --        Permission    : id {id}, nom  (READ / WRITE / DELETE)
    --        RolePermission: id_rolePermission {id}, id_role, id_permission
    -- =========================================================================
    PROCEDURE gen_roles_permissions IS
    BEGIN
        PKG_GENERATOR.log('=== Roles, Permissions, RolePermission ===');

        -- Roles (exemples cites dans l'UML : admin, technicien, utilisateur)
        MERGE INTO Role r USING DUAL ON (r.id = 1)
        WHEN NOT MATCHED THEN INSERT (id, nom) VALUES (1, 'admin');

        MERGE INTO Role r USING DUAL ON (r.id = 2)
        WHEN NOT MATCHED THEN INSERT (id, nom) VALUES (2, 'technicien');

        MERGE INTO Role r USING DUAL ON (r.id = 3)
        WHEN NOT MATCHED THEN INSERT (id, nom) VALUES (3, 'utilisateur');

        MERGE INTO Role r USING DUAL ON (r.id = 4)
        WHEN NOT MATCHED THEN INSERT (id, nom) VALUES (4, 'enseignant');

        MERGE INTO Role r USING DUAL ON (r.id = 5)
        WHEN NOT MATCHED THEN INSERT (id, nom) VALUES (5, 'etudiant');

        -- Permissions et RolePermission deja inserees par le DDL
        -- On ajoute uniquement les associations pour enseignant et etudiant -> READ
        DECLARE
            v_id_enseignant NUMBER;
            v_id_etudiant   NUMBER;
            v_id_read       NUMBER;
        BEGIN
            SELECT id INTO v_id_enseignant FROM Role WHERE nom = 'enseignant';
            SELECT id INTO v_id_etudiant   FROM Role WHERE nom = 'etudiant';
            SELECT id INTO v_id_read       FROM Permission WHERE nom = 'READ';
            INSERT INTO RolePermission (id_role, id_permission) VALUES (v_id_enseignant, v_id_read);
            INSERT INTO RolePermission (id_role, id_permission) VALUES (v_id_etudiant,   v_id_read);
        END;

        COMMIT;
        PKG_GENERATOR.log('  Roles / Permissions OK.');
    END gen_roles_permissions;


    -- =========================================================================
    -- 3.1  ENTITES DE BASE : Site, Batiment, Salle, Bureau
    --      Attributs UML :
    --        Site     : id {id}, nom, ville
    --                   methode : ajouterReseau(id_reseau)
    --        Batiment : id {id}, id_site
    --                   methode : ajouterSalle(id_salle)
    --        Salle    : id {id}, id_batiment
    --                   methode : ajouterBureau(id_bureau)
    --        Bureau   : id {id}
    -- =========================================================================
    PROCEDURE gen_entites_base IS

        TYPE t_bat_desc IS RECORD (
            bat_id    NUMBER,
            site_id   NUMBER,
            nb_etages NUMBER
        );
        TYPE t_bat_tab IS TABLE OF t_bat_desc INDEX BY PLS_INTEGER;
        v_bats  t_bat_tab;
        v_nb_salles NUMBER;
        v_nb_bureaux NUMBER;
    BEGIN
        PKG_GENERATOR.log('=== Entites de base (Site, Batiment, Salle, Bureau) ===');

        -- ---- Sites (2 sites : Cergy et Pau, mentionnes dans l'UML) ----
        MERGE INTO Site s USING DUAL ON (s.ville = 'Cergy')
        WHEN NOT MATCHED THEN INSERT (nom, ville) VALUES ('CY Tech Cergy', 'Cergy');

        MERGE INTO Site s USING DUAL ON (s.ville = 'Pau')
        WHEN NOT MATCHED THEN INSERT (nom, ville) VALUES ('CY Tech Pau', 'Pau');

        COMMIT;
        PKG_GENERATOR.log('  Sites OK : Cergy (id=1), Pau (id=2).');

        -- ---- Batiments (id, id_site) ----
        -- Cergy : 4 batiments (Condorcet, Cauchy, Turing, Fermat)
        -- Pau   : 1 batiment
        v_bats(1).bat_id:=1; v_bats(1).site_id:=1; v_bats(1).nb_etages:=4;
        v_bats(2).bat_id:=2; v_bats(2).site_id:=1; v_bats(2).nb_etages:=4;
        v_bats(3).bat_id:=3; v_bats(3).site_id:=1; v_bats(3).nb_etages:=4;
        v_bats(4).bat_id:=4; v_bats(4).site_id:=1; v_bats(4).nb_etages:=3;
        v_bats(5).bat_id:=5; v_bats(5).site_id:=2; v_bats(5).nb_etages:=3;

        FOR j IN v_bats.FIRST..v_bats.LAST LOOP
            INSERT INTO Batiment (id_site) VALUES (v_bats(j).site_id);
        END LOOP;

        COMMIT;
        PKG_GENERATOR.log('  Batiments OK : 5 batiments (4 Cergy + 1 Pau).');

        -- ---- Salles (id, id_batiment) ----
        -- Generation : 5 a 10 salles par batiment selon le nombre d'etages
        FOR j IN v_bats.FIRST..v_bats.LAST LOOP
            v_nb_salles := v_bats(j).nb_etages * PKG_GENERATOR.rand_int(5, 8);
            FOR s IN 1..v_nb_salles LOOP
                INSERT INTO Salle (id_batiment) VALUES (v_bats(j).bat_id);
            END LOOP;
        END LOOP;

        COMMIT;
        PKG_GENERATOR.log('  Salles OK.');

        -- ---- Bureaux (id uniquement selon l'UML) ----
        -- Generation : 1 a 3 bureaux par salle (bureaux individuels / open-space)
        DECLARE
            CURSOR cur_salles IS SELECT id FROM Salle;
        BEGIN
            FOR s IN cur_salles LOOP
                v_nb_bureaux := PKG_GENERATOR.rand_int(1, 3);
                FOR b IN 1..v_nb_bureaux LOOP
                    INSERT INTO Bureau (id) VALUES (seq_bureau.NEXTVAL);
                END LOOP;
            END LOOP;
        END;

        COMMIT;
        PKG_GENERATOR.log('  Bureaux OK.');
    END gen_entites_base;


    -- =========================================================================
    -- 3.2  UTILISATEURS
    --      Attributs UML :
    --        Utilisateur : id {id}, nom, email, mot_passe_hash, id_site, id_role
    --        Methodes    : assignerMateriel(id_materiel), creerTicket(description)
    -- =========================================================================
    PROCEDURE gen_utilisateurs IS
        t_prenoms SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
            'Pooja','Mihai','Theo','Arjun','Nguyen','Gabriel','Hye-Jin','Sana','Ines','Carlos',
            'Fatoumata','Camille','Mehdi','Linh','Rohan','Amira','Hugo','Aissatou','Vasile','Jules',
            'Elena','Zineb','Wei','Nadia','Mamadou','Andrei','Sarah','Kofi','Ji-Won','Tarek',
            'Min-Jun','Oceane','Katarzyna','Tidiane','Thi','David','Agnieszka','Nicolas','Yann','Bintou',
            'Rachid','Emma','Sofia','Priya','Romain','Adama','Samira','Louis','Mirela','Sebastien',
            'Amine','Alice','Dounia','Ibrahima','Lucie','Karim','Diego','Aminata','Nathan','Mourad',
            'Baptiste','Rokhaya','Kavya','Miguel','Oumar','Hajar','Maxime','Aisha','Francois','Leila',
            'Bogdan','Lea','Ananya','Isabella','Jihane','Tariq','Adrien','Phuong','Alexis','Aya',
            'Seung','Gaelle','Pierre','Hamid','Hui','Mathis','Nafissatou','Youssef','Ioana','Valentin'
        );
        t_noms SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
            'Popescu','Ndiaye','Garcia','Diallo','Morel','Zhang','Schmidt','Popa','Benkhaled','Kumar',
            'Lefebvre','Nguyen','Boudiaf','Martinez','Russo','Traore','Kim','Dumont','Gupta','Sow',
            'Ziani','Rousseau','Moreau','Park','Belkacem','Leroy','Costa','Sanchez','Fournier','Lee',
            'Merzouki','Ionescu','Singh','Faure','Khelifi','Dridi','Garnier','Perrin','Hadj','Lahlou',
            'Jovanovic','Gueye','Wang','Lopez','Martin','Cisse','Fischer','Radu','Rachidi','Huang',
            'Esposito','Legrand','Patel','Dupont','Richard','Yoon','Bertrand','Sanogo','Mehta','Ferreira',
            'Bernard','Gonzalez','Toure','Meziani','Kowalski','Gauthier','Dubois','Ramirez','Khalil','Mueller',
            'Sylla','Pham','Dinu','Nikolic','Laurent','Hamdi','Verma','Rao','Bensalah','Bonnet',
            'Wojciechowski','Jabrane','Vincent','Flores','Slimani','Chen','Lefevre','Nowak','Rodriguez','Michel'
        );
        t_domaines SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
            'cytech.fr','cyu.fr','etu.cytech.fr'
        );
        -- Distribution : majorite etudiants (5), puis enseignants (4), etc.
        t_role_ids SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
            '5','5','5','5','4','4','2','1','3'
        );

        v_prenom   VARCHAR2(50);
        v_nom_val  VARCHAR2(50);
        v_email    VARCHAR2(150);
        v_role_id  NUMBER;
        v_site_id  NUMBER;
        v_nb_cergy NUMBER := PKG_GENERATOR.cfg('NB_UTILISATEURS_CERGY');
        v_nb_pau   NUMBER := PKG_GENERATOR.cfg('NB_UTILISATEURS_PAU');
        v_total    NUMBER;

        -- Curseur de verification de doublon email
        CURSOR cur_check_email(p_email VARCHAR2) IS
            SELECT COUNT(*) FROM Utilisateur WHERE email = p_email;
        v_count  NUMBER;
        v_suffix NUMBER;
        v_base_email VARCHAR2(150);
    BEGIN
        PKG_GENERATOR.log('=== Utilisateurs ===');
        v_total := v_nb_cergy + v_nb_pau;

        FOR i IN 1..v_total LOOP
            v_prenom  := PKG_GENERATOR.pick(t_prenoms);
            v_nom_val := PKG_GENERATOR.pick(t_noms);
            v_role_id := TO_NUMBER(PKG_GENERATOR.pick(t_role_ids));

            -- Repartition sites
            IF i <= v_nb_cergy THEN
                v_site_id := 1;
            ELSE
                v_site_id := 2;
            END IF;

            -- Generation email unique
            v_base_email := LOWER(SUBSTR(v_prenom, 1, 1) || v_nom_val)
                            || '@' || PKG_GENERATOR.pick(t_domaines);

            OPEN cur_check_email(v_base_email);
            FETCH cur_check_email INTO v_count;
            CLOSE cur_check_email;
            IF v_count > 0 THEN
                v_suffix     := PKG_GENERATOR.rand_int(1, 9999);
                v_email      := LOWER(SUBSTR(v_prenom, 1, 1) || v_nom_val)
                                || TO_CHAR(v_suffix)
                                || '@' || PKG_GENERATOR.pick(t_domaines);
            ELSE
                v_email := v_base_email;
            END IF;

            -- Insertion avec les colonnes EXACTES du diagramme UML :
            --   id, nom, email, mot_passe_hash, id_site, id_role
            INSERT INTO Utilisateur (
                nom, email, mot_passe_hash, id_site, id_role
            ) VALUES (
                UPPER(v_nom_val) || ' ' || v_prenom,
                v_email,
                -- Hash simule SHA-256 (valeur fixe generee aleatoirement)
                LOWER(TO_CHAR(PKG_GENERATOR.rand_int(0, 2147483647), 'FMXXXXXXXX')
                      || TO_CHAR(PKG_GENERATOR.rand_int(0, 2147483647), 'FMXXXXXXXX')
                      || TO_CHAR(PKG_GENERATOR.rand_int(0, 2147483647), 'FMXXXXXXXX')
                      || TO_CHAR(PKG_GENERATOR.rand_int(0, 2147483647), 'FMXXXXXXXX')),
                v_site_id,
                v_role_id
            );

            IF MOD(i, 200) = 0 THEN
                COMMIT;
                PKG_GENERATOR.log('  ' || i || '/' || v_total || ' utilisateurs inseres...');
            END IF;
        END LOOP;

        COMMIT;
        PKG_GENERATOR.log('  Utilisateurs OK : ' || v_total || ' inseres.');
    END gen_utilisateurs;


    -- =========================================================================
    -- 3.3  RESEAUX
    --      Attributs UML :
    --        Reseau : id {id}, ip_range, vlan, id_site
    --        Methodes : ajouterEquipement(id_equipement), getEquipements()
    -- =========================================================================
    PROCEDURE gen_reseaux IS
        v_nb_reseaux NUMBER := PKG_GENERATOR.cfg('NB_RESEAUX');
        v_octet3     NUMBER;
        v_site_id    NUMBER;
        v_ip_range   VARCHAR2(20);
        v_vlan_num   NUMBER;
    BEGIN
        PKG_GENERATOR.log('=== Reseaux ===');

        -- Reseaux Cergy (67%) puis Pau (33%)
        -- Plan d'adressage : Cergy 10.10.x.0/24, Pau 10.20.x.0/24
        FOR i IN 1..v_nb_reseaux LOOP
            IF i <= ROUND(v_nb_reseaux * 0.67) THEN
                v_site_id := 1;
                v_octet3  := MOD(i - 1, 20) + 1;
                v_ip_range := '10.10.' || v_octet3 || '.0/24';
                v_vlan_num := 100 + i;
            ELSE
                v_site_id := 2;
                v_octet3  := MOD(i - ROUND(v_nb_reseaux * 0.67) - 1, 10) + 1;
                v_ip_range := '10.20.' || v_octet3 || '.0/24';
                v_vlan_num := 200 + i;
            END IF;

            -- Insertion avec les colonnes EXACTES du diagramme UML :
            --   id, ip_range, vlan, id_site
            INSERT INTO Reseau (ip_range, wan, id_site)
            VALUES (
                v_ip_range,
                TO_CHAR(v_vlan_num),
                v_site_id
            );
        END LOOP;

        COMMIT;
        PKG_GENERATOR.log('  Reseaux OK : ' || v_nb_reseaux || ' reseaux.');
    END gen_reseaux;


    -- =========================================================================
    -- 3.4  EQUIPEMENTS RESEAU
    --      Attributs UML :
    --        EquipementReseau : id {id}, nom, type: TypeEquipementReseau, id_reseau
    --        TypeEquipementReseau (enum) : Serveur, Switch, Routeur
    --        Methodes : estActif() boolean
    -- =========================================================================
    PROCEDURE gen_equipements_reseau IS
        v_nb_equip NUMBER := PKG_GENERATOR.cfg('NB_EQUIPEMENTS_RESEAU');

        TYPE t_reseau_ids IS TABLE OF NUMBER;
        v_reseaux_cergy t_reseau_ids;
        v_reseaux_pau   t_reseau_ids;
        v_reseau_id     NUMBER;
        v_site_id       NUMBER;
        -- TypeEquipementReseau enum : Serveur, Switch, Routeur
        t_types SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
            'Serveur','Serveur','Switch','Switch','Routeur'
        );
    BEGIN
        PKG_GENERATOR.log('=== EquipementsReseau ===');

        -- Chargement des IDs reseau en memoire par site
        SELECT id BULK COLLECT INTO v_reseaux_cergy
        FROM Reseau WHERE id_site = 1;

        SELECT id BULK COLLECT INTO v_reseaux_pau
        FROM Reseau WHERE id_site = 2;

        -- Repartition : 70% Cergy, 30% Pau
        FOR i IN 1..v_nb_equip LOOP
            IF i <= ROUND(v_nb_equip * 0.7) THEN
                v_reseau_id := v_reseaux_cergy(
                    PKG_GENERATOR.rand_int(1, v_reseaux_cergy.COUNT));
            ELSE
                v_reseau_id := v_reseaux_pau(
                    PKG_GENERATOR.rand_int(1, v_reseaux_pau.COUNT));
            END IF;

            -- Insertion avec les colonnes EXACTES du diagramme UML :
            --   id, nom, type (TypeEquipementReseau), id_reseau
            INSERT INTO EquipementReseau (nom, type, id_reseau)
            VALUES (
                PKG_GENERATOR.pick(SYS.ODCIVARCHAR2LIST(
                    'SRV','SW','RTR','FW','AP')) || '-' || PKG_GENERATOR.gen_serial(),
                PKG_GENERATOR.pick(t_types),
                v_reseau_id
            );

            IF MOD(i, 50) = 0 THEN COMMIT; END IF;
        END LOOP;

        COMMIT;
        PKG_GENERATOR.log('  EquipementsReseau OK : ' || v_nb_equip || ' inseres.');
    END gen_equipements_reseau;


    -- =========================================================================
    -- 3.5  MATERIELS
    --      Attributs UML :
    --        Materiel : id {id}, nom, type: TypeMateriel, numero_serie, id_site, statut
    --        TypeMateriel (enum) : PC, Imprimante, Ecran
    --        Methodes : estDisponible() boolean, changerStatut(nouveauStatut),
    --                   getAffectations()
    -- =========================================================================
    PROCEDURE gen_materiels IS
        v_nb_cergy NUMBER := PKG_GENERATOR.cfg('NB_MATERIELS_CERGY');
        v_nb_pau   NUMBER := PKG_GENERATOR.cfg('NB_MATERIELS_PAU');
        v_total    NUMBER;
        v_site_id  NUMBER;
        -- TypeMateriel enum : PC, Imprimante, Ecran
        t_types SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
            'PC','PC','PC','Imprimante','Ecran'
        );
        -- Statuts realistes (non contraints par l'UML mais coherents avec statut: String)
        t_statuts SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
            'disponible','disponible','disponible','affecte','maintenance','hors_service'
        );
        v_prefixes SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
            'PC','IMPR','ECRAN'
        );
        v_type_val  VARCHAR2(20);
        v_nom_val   VARCHAR2(80);
    BEGIN
        PKG_GENERATOR.log('=== Materiels ===');
        v_total := v_nb_cergy + v_nb_pau;

        FOR i IN 1..v_total LOOP
            IF i <= v_nb_cergy THEN
                v_site_id := 1;
            ELSE
                v_site_id := 2;
            END IF;

            v_type_val := PKG_GENERATOR.pick(t_types);
            v_nom_val  := CASE v_type_val
                            WHEN 'PC'          THEN 'PC-'
                            WHEN 'Imprimante'  THEN 'IMPR-'
                            WHEN 'Ecran'       THEN 'ECRAN-'
                          END || PKG_GENERATOR.gen_serial();

            -- Insertion avec les colonnes EXACTES du diagramme UML :
            --   id, nom, type (TypeMateriel), numero_serie, id_site, statut
            INSERT INTO Materiel (nom, type, numero_serie, id_site, statut)
            VALUES (
                v_nom_val,
                v_type_val,
                PKG_GENERATOR.gen_serial(),
                v_site_id,
                PKG_GENERATOR.pick(t_statuts)
            );

            IF MOD(i, 300) = 0 THEN
                COMMIT;
                PKG_GENERATOR.log('  ' || i || '/' || v_total || ' materiels inseres...');
            END IF;
        END LOOP;

        COMMIT;
        PKG_GENERATOR.log('  Materiels OK : ' || v_total || ' inseres.');
    END gen_materiels;


    -- =========================================================================
    -- 3.6  AFFECTATIONS
    --      Attributs UML :
    --        Affectation : id {id}, id_utilisateur, id_materiel, date_debut, date_fin
    --        Methodes : creerAffectation(id_utilisateur, id_materiel),
    --                   terminerAffectation(), estActive() boolean
    --      Cardinalites UML :
    --        Utilisateur 1 <-> 1..* Affectation
    --        Materiel    1 <-> 1..* Affectation
    -- =========================================================================
    PROCEDURE gen_affectations IS
        -- Curseur : materiels de type PC disponibles ou affectes
        CURSOR cur_materiels IS
            SELECT id, id_site
            FROM   Materiel
            WHERE  type = 'PC'
            AND    statut IN ('disponible','affecte')
            ORDER BY DBMS_RANDOM.VALUE;

        TYPE t_user_ids IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
        v_users_cergy t_user_ids;
        v_users_pau   t_user_ids;
        v_idx         PLS_INTEGER;
        v_user_id     NUMBER;
        v_nb_aff      NUMBER := 0;
    BEGIN
        PKG_GENERATOR.log('=== Affectations ===');

        -- Chargement des user IDs par site en memoire
        v_idx := 1;
        FOR u IN (SELECT id FROM Utilisateur WHERE id_site = 1) LOOP
            v_users_cergy(v_idx) := u.id;
            v_idx := v_idx + 1;
        END LOOP;
        v_idx := 1;
        FOR u IN (SELECT id FROM Utilisateur WHERE id_site = 2) LOOP
            v_users_pau(v_idx) := u.id;
            v_idx := v_idx + 1;
        END LOOP;

        -- 80% des PC recoivent une affectation utilisateur
        FOR mat IN cur_materiels LOOP
            IF PKG_GENERATOR.rand_int(1, 100) <= 80 THEN
                IF mat.id_site = 1 AND v_users_cergy.COUNT > 0 THEN
                    v_user_id := v_users_cergy(
                        PKG_GENERATOR.rand_int(1, v_users_cergy.COUNT));
                ELSIF mat.id_site = 2 AND v_users_pau.COUNT > 0 THEN
                    v_user_id := v_users_pau(
                        PKG_GENERATOR.rand_int(1, v_users_pau.COUNT));
                ELSE
                    CONTINUE;
                END IF;

                BEGIN
                    -- Insertion avec les colonnes EXACTES du diagramme UML :
                    --   id, id_utilisateur, id_materiel, date_debut, date_fin
                    INSERT INTO Affectation (
                        id_utilisateur, id_materiel, date_debut, date_fin
                    ) VALUES (
                        v_user_id,
                        mat.id,
                        PKG_GENERATOR.rand_date(DATE '2020-01-01', SYSDATE - 30),
                        -- 20% des affectations sont terminees (date_fin renseignee)
                        CASE WHEN PKG_GENERATOR.rand_int(1, 10) <= 2
                             THEN PKG_GENERATOR.rand_date(SYSDATE - 90, SYSDATE)
                             ELSE NULL END
                    );
                    v_nb_aff := v_nb_aff + 1;
                EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL;
                END;

                IF MOD(v_nb_aff, 500) = 0 THEN COMMIT; END IF;
            END IF;
        END LOOP;

        COMMIT;
        PKG_GENERATOR.log('  Affectations OK : ' || v_nb_aff || ' creees.');
    END gen_affectations;


    -- =========================================================================
    -- 3.7  TICKETS
    --      Attributs UML :
    --        Ticket : id {id}, id_technicien, id_utilisateur, id_materiel,
    --                 description, statut, date_creation
    --        Methodes : ouvrirTicket(), fermerTicket(), assignerTechnicien(id_technicien)
    --      Note UML : "Le technicien est un Utilisateur" (id_technicien FK -> Utilisateur)
    -- =========================================================================
    PROCEDURE gen_tickets IS
        v_nb_tickets NUMBER := PKG_GENERATOR.cfg('NB_TICKETS');

        t_descriptions SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
            'Panne ecran - plus de signal',
            'PC ne demarre pas',
            'Imprimante bloquee - bourrage papier',
            'Ecran avec bandes verticales',
            'PC tres lent, disque plein',
            'Imprimante ne repond plus au reseau',
            'Remplacement ecran defectueux',
            'Demande de nouveau materiel',
            'Probleme connexion reseau',
            'Mise a jour logiciels requise',
            'Ecran tactile non fonctionnel',
            'PC redemarrage intempestif',
            'Imprimante : qualite impression degradee',
            'Perte de donnees - demande restauration',
            'Installation logiciel metier'
        );
        -- Statuts coherents avec statut: String de l'UML
        t_statuts_fermes  SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
            'resolu','ferme','clos');
        t_statuts_ouverts SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
            'ouvert','en_cours','en_attente');

        TYPE t_ids IS TABLE OF NUMBER;
        v_all_users  t_ids;
        v_techs      t_ids;  -- techniciens = admin (1) ou technicien (2)
        v_all_mats   t_ids;

        v_user_id    NUMBER;
        v_tech_id    NUMBER;
        v_mat_id     NUMBER;
        v_statut     VARCHAR2(30);
        v_date_crea  DATE;
        v_nb_inseres NUMBER := 0;
    BEGIN
        PKG_GENERATOR.log('=== Tickets ===');

        -- Chargement des IDs en memoire
        SELECT id BULK COLLECT INTO v_all_users FROM Utilisateur;

        SELECT id BULK COLLECT INTO v_techs
        FROM   Utilisateur
        WHERE  id_role IN (1, 2);  -- admin et technicien

        SELECT id BULK COLLECT INTO v_all_mats FROM Materiel;

        PKG_GENERATOR.log('  ' || v_all_users.COUNT || ' users, '
            || v_techs.COUNT || ' techniciens, '
            || v_all_mats.COUNT || ' materiels charges.');

        -- Generation par lots de 500 (FORALL)
        DECLARE
            TYPE t_ticket_rec IS RECORD (
                t_tech       NUMBER,
                t_user       NUMBER,
                t_mat        NUMBER,
                t_desc       VARCHAR2(500),
                t_statut     VARCHAR2(30),
                t_date_crea  DATE
            );
            TYPE t_batch IS TABLE OF t_ticket_rec INDEX BY PLS_INTEGER;
            v_batch     t_batch;
            BATCH_SIZE  CONSTANT PLS_INTEGER := 500;
            v_idx       PLS_INTEGER := 1;
        BEGIN
            FOR i IN 1..v_nb_tickets LOOP
                v_user_id   := v_all_users(PKG_GENERATOR.rand_int(1, v_all_users.COUNT));
                v_tech_id   := CASE WHEN v_techs.COUNT > 0
                               THEN v_techs(PKG_GENERATOR.rand_int(1, v_techs.COUNT))
                               ELSE NULL END;
                -- id_materiel NOT NULL dans le DDL -> tous les tickets ont un materiel
                v_mat_id    := v_all_mats(PKG_GENERATOR.rand_int(1, v_all_mats.COUNT));
                -- 80% des tickets historiques sont fermes
                v_statut    := CASE WHEN PKG_GENERATOR.rand_int(1,100) <= 80
                               THEN PKG_GENERATOR.pick(t_statuts_fermes)
                               ELSE PKG_GENERATOR.pick(t_statuts_ouverts) END;
                v_date_crea := PKG_GENERATOR.rand_date(DATE '2022-01-01', SYSDATE - 1);

                v_batch(v_idx).t_tech      := v_tech_id;
                v_batch(v_idx).t_user      := v_user_id;
                v_batch(v_idx).t_mat       := v_mat_id;
                v_batch(v_idx).t_desc      := PKG_GENERATOR.pick(t_descriptions)
                                              || ' [' || PKG_GENERATOR.gen_serial() || ']';
                v_batch(v_idx).t_statut    := v_statut;
                v_batch(v_idx).t_date_crea := v_date_crea;
                v_idx := v_idx + 1;

                IF v_idx > BATCH_SIZE OR i = v_nb_tickets THEN
                    -- Insertion avec les colonnes EXACTES du diagramme UML :
                    --   id, id_technicien, id_utilisateur, id_materiel,
                    --   description, statut, date_creation
                    FORALL j IN 1..v_idx - 1
                        INSERT INTO Ticket (
                            id_technicien, id_utilisateur, id_materiel,
                            description, statut, date_creation
                        ) VALUES (
                            v_batch(j).t_tech,
                            v_batch(j).t_user,
                            v_batch(j).t_mat,
                            v_batch(j).t_desc,
                            v_batch(j).t_statut,
                            v_batch(j).t_date_crea
                        );
                    COMMIT;
                    PKG_GENERATOR.log('  Tickets : ' || i || '/' || v_nb_tickets);
                    v_batch.DELETE;
                    v_idx := 1;
                END IF;
            END LOOP;
        END;

        PKG_GENERATOR.log('  Tickets OK : ' || v_nb_tickets || ' inseres.');
    END gen_tickets;


    -- =========================================================================
    -- 3.8  RUN_ALL (point d'entree unique)
    -- =========================================================================
    PROCEDURE run_all IS
        v_debut TIMESTAMP := SYSTIMESTAMP;
        v_fin   TIMESTAMP;
        v_duree INTERVAL DAY TO SECOND;
    BEGIN
        DBMS_OUTPUT.ENABLE(1000000);
        PKG_GENERATOR.log('========================================');
        PKG_GENERATOR.log('DEMARRAGE GENERATION - GLPI CY Tech');
        PKG_GENERATOR.log('Modele : conforme au diagramme UML v3');
        PKG_GENERATOR.log('========================================');

        DBMS_RANDOM.SEED(PKG_GENERATOR.cfg('SEED_ALEATOIRE'));

        gen_roles_permissions;   -- Role, Permission, RolePermission
        gen_entites_base;        -- Site, Batiment, Salle, Bureau
        gen_utilisateurs;        -- Utilisateur
        gen_reseaux;             -- Reseau
        gen_equipements_reseau;  -- EquipementReseau
        gen_materiels;           -- Materiel
        gen_affectations;        -- Affectation
        gen_tickets;             -- Ticket

        v_fin   := SYSTIMESTAMP;
        v_duree := v_fin - v_debut;

        PKG_GENERATOR.log('========================================');
        PKG_GENERATOR.log('GENERATION TERMINEE');
        PKG_GENERATOR.log('Duree totale : '
            || EXTRACT(MINUTE FROM v_duree) || 'm '
            || ROUND(EXTRACT(SECOND FROM v_duree)) || 's');
        PKG_GENERATOR.log('========================================');
    END run_all;

END PKG_DATA_GEN;
/


-- =============================================================================
-- 4. SCRIPT D'EXECUTION PRINCIPAL
-- =============================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED

BEGIN
    PKG_DATA_GEN.run_all;
END;
/


-- =============================================================================
-- 5. VERIFICATIONS POST-GENERATION
--    Toutes les tables correspondent aux entites du diagramme UML v3.
-- =============================================================================

BEGIN
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE('VERIFICATION POST-GENERATION - COMPTAGES FINAUX');
    DBMS_OUTPUT.PUT_LINE('Entites conformes au diagramme UML v3');
    DBMS_OUTPUT.PUT_LINE('============================================================');
END;
/

SELECT table_name AS ENTITE_UML, nb_lignes FROM (
    SELECT 'Site'              AS table_name, COUNT(*) AS nb_lignes FROM Site
    UNION ALL
    SELECT 'Batiment',          COUNT(*) FROM Batiment
    UNION ALL
    SELECT 'Salle',             COUNT(*) FROM Salle
    UNION ALL
    SELECT 'Bureau',            COUNT(*) FROM Bureau
    UNION ALL
    SELECT 'Role',              COUNT(*) FROM Role
    UNION ALL
    SELECT 'Permission',        COUNT(*) FROM Permission
    UNION ALL
    SELECT 'RolePermission',    COUNT(*) FROM RolePermission
    UNION ALL
    SELECT 'Utilisateur',       COUNT(*) FROM Utilisateur
    UNION ALL
    SELECT 'Reseau',            COUNT(*) FROM Reseau
    UNION ALL
    SELECT 'EquipementReseau',  COUNT(*) FROM EquipementReseau
    UNION ALL
    SELECT 'Materiel',          COUNT(*) FROM Materiel
    UNION ALL
    SELECT 'Affectation',       COUNT(*) FROM Affectation
    UNION ALL
    SELECT 'Ticket',            COUNT(*) FROM Ticket
)
ORDER BY table_name;

-- Repartition des materiels par TypeMateriel (enum UML : PC, Imprimante, Ecran)
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('--- Materiels par TypeMateriel (enum UML) ---');
END;
/
SELECT
    type                                           AS TYPE_MATERIEL,
    SUM(CASE WHEN id_site = 1 THEN 1 ELSE 0 END)  AS CERGY,
    SUM(CASE WHEN id_site = 2 THEN 1 ELSE 0 END)  AS PAU,
    COUNT(*)                                       AS TOTAL
FROM Materiel
GROUP BY type
ORDER BY TOTAL DESC;

-- Repartition des equipements reseau par TypeEquipementReseau (enum UML : Serveur, Switch, Routeur)
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('--- EquipementsReseau par TypeEquipementReseau (enum UML) ---');
END;
/
SELECT
    er.type                                                     AS TYPE_EQUIP,
    SUM(CASE WHEN r.id_site = 1 THEN 1 ELSE 0 END)            AS CERGY,
    SUM(CASE WHEN r.id_site = 2 THEN 1 ELSE 0 END)            AS PAU,
    COUNT(*)                                                    AS TOTAL
FROM EquipementReseau er
JOIN Reseau r ON r.id = er.id_reseau
GROUP BY er.type
ORDER BY TOTAL DESC;

-- Repartition des utilisateurs par role et site
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('--- Utilisateurs par role et site ---');
END;
/
SELECT
    r.nom                                                          AS ROLE,
    SUM(CASE WHEN u.id_site = 1 THEN 1 ELSE 0 END)               AS CERGY,
    SUM(CASE WHEN u.id_site = 2 THEN 1 ELSE 0 END)               AS PAU,
    COUNT(*)                                                       AS TOTAL
FROM Utilisateur u
JOIN Role r ON r.id = u.id_role
GROUP BY r.nom
ORDER BY TOTAL DESC;

-- Tickets par statut
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('--- Tickets par statut ---');
END;
/
SELECT
    statut,
    COUNT(*) AS NB_TICKETS
FROM Ticket
GROUP BY statut
ORDER BY NB_TICKETS DESC;

-- Taux d'affectation (Affectation.date_fin IS NULL = active)
BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('--- Taux affectation materiels actives ---');
END;
/
SELECT
    ROUND(COUNT(DISTINCT a.id_materiel) * 100.0 / NULLIF(MAX(m.nb_pc), 0), 2) AS PCT_PC_AFFECTES,
    COUNT(DISTINCT a.id_materiel) AS NB_AFFECTES,
    MAX(m.nb_pc) AS NB_PC_TOTAL
FROM Affectation a
CROSS JOIN (SELECT COUNT(*) AS nb_pc FROM Materiel WHERE type = 'PC') m
WHERE a.date_fin IS NULL;

BEGIN
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE('FIN DES VERIFICATIONS');
    DBMS_OUTPUT.PUT_LINE('============================================================');
END;
/