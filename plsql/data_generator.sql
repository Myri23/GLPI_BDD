-- =============================================================================
-- FICHIER  : data_generator.sql
-- OBJET    : Générateur PL/SQL complet d'un jeu de données réaliste et
--            conséquent pour valider la nouvelle architecture GLPI multi-sites
--            (Cergy / Pau) et servir de base aux benchmarks comparatifs.
-- =============================================================================
-- CONTENU DU FICHIER
--   1.  Paramètres globaux (constantes de volumétrie)
--   2.  Package PKG_GENERATOR : utilitaires internes (aléatoire, nommage)
--   3.  Package PKG_DATA_GEN  : procédures principales de génération
--         - gen_entites_base      : sites, bâtiments, salles, départements
--         - gen_utilisateurs      : users CY Tech avec rôles réalistes
--         - gen_reseaux           : VLANs, sous-réseaux, adresses IP
--         - gen_materiels         : ordinateurs, serveurs, imprimantes, switches
--         - gen_affectations      : liens matériels <=> utilisateurs / salles
--         - gen_tickets_historique: tickets GLPI simulés (charge historique)
--         - gen_maintenance       : contrats, interventions, logs
--   4.  Script d'exécution principal + métriques d'avancement
--   5.  Vérifications post-génération (comptages, cohérence)
-- =============================================================================


-- =============================================================================
-- 1. PARAMÈTRES DE VOLUMÉTRIE
-- =============================================================================

-- Les packages lisent ces valeurs via la table GENERATEUR_CONFIG ci-dessous

SET DEFINE OFF

BEGIN
    -- Suppression si réexécution
    EXECUTE IMMEDIATE 'DROP TABLE GENERATEUR_CONFIG PURGE';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

CREATE TABLE GENERATEUR_CONFIG (
    CLE    VARCHAR2(60) PRIMARY KEY,
    VALEUR NUMBER NOT NULL,
    COMMENTAIRE VARCHAR2(200)
);

INSERT INTO GENERATEUR_CONFIG VALUES ('NB_UTILISATEURS_CERGY', 800,
    'Utilisateurs du site de Cergy');
INSERT INTO GENERATEUR_CONFIG VALUES ('NB_UTILISATEURS_PAU', 400,
    'Utilisateurs du site de Pau');
INSERT INTO GENERATEUR_CONFIG VALUES ('NB_ORDINATEURS_CERGY', 900,
    'PC/laptops affectés à Cergy');
INSERT INTO GENERATEUR_CONFIG VALUES ('NB_ORDINATEURS_PAU', 450,
    'PC/laptops affectés à Pau');
INSERT INTO GENERATEUR_CONFIG VALUES ('NB_SERVEURS', 60,
    'Serveurs physiques et virtuels (répartis)');
INSERT INTO GENERATEUR_CONFIG VALUES ('NB_IMPRIMANTES', 120,
    'Imprimantes réseau multi-sites');
INSERT INTO GENERATEUR_CONFIG VALUES ('NB_SWITCHES', 80,
    'Switches et équipements réseau');
INSERT INTO GENERATEUR_CONFIG VALUES ('NB_VLANS', 30,
    'VLANs définis sur l ensemble du réseau');
INSERT INTO GENERATEUR_CONFIG VALUES ('NB_SOUS_RESEAUX', 50,
    'Sous-réseaux IP');
INSERT INTO GENERATEUR_CONFIG VALUES ('NB_TICKETS', 5000,
    'Tickets historiques sur 3 ans');
INSERT INTO GENERATEUR_CONFIG VALUES ('NB_CONTRATS', 80,
    'Contrats de maintenance');
INSERT INTO GENERATEUR_CONFIG VALUES ('NB_INTERVENTIONS', 2000,
    'Interventions techniques loguées');
INSERT INTO GENERATEUR_CONFIG VALUES ('SEED_ALEATOIRE', 42,
    'Graine pour reproductibilité');
COMMIT;


-- =============================================================================
-- 2. PACKAGE PKG_GENERATOR  (utilitaires internes)
-- =============================================================================

CREATE OR REPLACE PACKAGE PKG_GENERATOR AS
    -- Génération d'un entier aléatoire dans [p_min, p_max]
    FUNCTION rand_int(p_min IN NUMBER, p_max IN NUMBER) RETURN NUMBER;

    -- Génération d'une date aléatoire entre deux bornes
    FUNCTION rand_date(p_debut IN DATE, p_fin IN DATE) RETURN DATE;

    -- Choix aléatoire dans un tableau de VARCHAR2
    FUNCTION pick(p_liste IN SYS.ODCIVARCHAR2LIST) RETURN VARCHAR2;

    -- Génère une adresse IP fictive cohérente dans un sous-réseau /24
    FUNCTION gen_ip(p_base IN VARCHAR2) RETURN VARCHAR2;

    -- Génère une adresse MAC fictive (format XX:XX:XX:XX:XX:XX)
    FUNCTION gen_mac RETURN VARCHAR2;

    -- Génère un numéro de série plausible (alphanumérique, 12 chars)
    FUNCTION gen_serial RETURN VARCHAR2;

    -- Retourne la valeur d'une constante depuis GENERATEUR_CONFIG
    FUNCTION cfg(p_cle IN VARCHAR2) RETURN NUMBER;

    -- Log d'avancement à l'écran (DBMS_OUTPUT)
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
        -- Génère un octet hexadécimal sur 2 chiffres
        FUNCTION octet RETURN VARCHAR2 IS
        BEGIN
            RETURN LPAD(TO_CHAR(rand_int(0, 255), 'XX'), 2, '0');
        END;
    BEGIN
        v_mac := octet||':'||octet||':'||octet||':'||octet||':'||octet||':'||octet;
        RETURN UPPER(v_mac);
    END;

    FUNCTION gen_serial RETURN VARCHAR2 IS
        v_chars CONSTANT VARCHAR2(36) := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
        v_result VARCHAR2(12) := '';
        v_pos    PLS_INTEGER;
    BEGIN
        FOR i IN 1..12 LOOP
            v_pos := rand_int(1, LENGTH(v_chars));
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
-- 3. PACKAGE PKG_DATA_GEN  (génération métier)
-- =============================================================================

CREATE OR REPLACE PACKAGE PKG_DATA_GEN AS
    PROCEDURE gen_roles_permissions;   
    PROCEDURE gen_entites_base;
    PROCEDURE gen_utilisateurs;
    PROCEDURE gen_reseaux;
    PROCEDURE gen_materiels;
    PROCEDURE gen_affectations;
    PROCEDURE gen_tickets_historique;
    PROCEDURE gen_maintenance;
    PROCEDURE run_all;          -- Point d'entrée unique
END PKG_DATA_GEN;
/

CREATE OR REPLACE PACKAGE BODY PKG_DATA_GEN AS

    -- =========================================================================
    -- 3.0  RÔLES, PERMISSIONS ET ASSOCIATIONS 
    --      Role (id, nom)
    --      Permission (id, nom)
    --      RolePermission (id_role, id_permission)
    -- =========================================================================
    PROCEDURE gen_roles_permissions IS
    BEGIN
        PKG_GENERATOR.log('=== Rôles, Permissions, RolePermission ===');

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

        -- ---- Permissions : actions possibles (READ, WRITE, DELETE dans l'UML) ----
        MERGE INTO Permission p USING DUAL ON (p.id = 1)
        WHEN NOT MATCHED THEN INSERT (id, nom) VALUES (1, 'READ');

        MERGE INTO Permission p USING DUAL ON (p.id = 2)
        WHEN NOT MATCHED THEN INSERT (id, nom) VALUES (2, 'WRITE');

        MERGE INTO Permission p USING DUAL ON (p.id = 3)
        WHEN NOT MATCHED THEN INSERT (id, nom) VALUES (3, 'DELETE');

        -- ---- RolePermission : associations rôles <-> permissions ----
        -- admin    -> READ, WRITE, DELETE
        -- technicien -> READ, WRITE
        -- utilisateur / enseignant / etudiant -> READ uniquement
        INSERT INTO RolePermission (id_role, id_permission) VALUES (1, 1);
        INSERT INTO RolePermission (id_role, id_permission) VALUES (1, 2);
        INSERT INTO RolePermission (id_role, id_permission) VALUES (1, 3);
        INSERT INTO RolePermission (id_role, id_permission) VALUES (2, 1);
        INSERT INTO RolePermission (id_role, id_permission) VALUES (2, 2);
        INSERT INTO RolePermission (id_role, id_permission) VALUES (3, 1);
        INSERT INTO RolePermission (id_role, id_permission) VALUES (4, 1);
        INSERT INTO RolePermission (id_role, id_permission) VALUES (5, 1);

        COMMIT;
        PKG_GENERATOR.log('  Rôles / Permissions OK.');
    END gen_roles_permissions;


    -- =========================================================================
    -- 3.1  ENTITÉS DE BASE  (sites, bâtiments, salles, départements)
    -- =========================================================================
    PROCEDURE gen_entites_base IS
        -- Curseur sur les sites à créer : Cergy et Pau
        CURSOR cur_sites IS
            SELECT id, NOM_SITE, CODE_SITE FROM GLPI_SITES ORDER BY id;

        -- ---------------------------------------------------------------------------
        -- Type pour décrire un bâtiment avec sa convention de numérotation propre.
        --
        -- CY Tech Cergy – conventions observées sur le terrain :
        --   • Condorcet : étage 0 -> 1xx, étage 1 -> 2xx, étage 2 -> 3xx, étage 3 -> 4xx
        --                 (numérotation décalée par rapport à l'étage, bâtiment principal)
        --                 Amphi Condorcet au RDC
        --   • Cauchy    : idem Condorcet – étage 0 -> 1xx, étage 1 -> 2xx, étage 2 -> 3xx, étage 3 -> 4xx
        --                 Amphi Cauchy au RDC
        --   • Turing    : étage 0 -> 0xx, étage 1 -> 1xx (numérotation standard)
        --                 Amphi Turing au RDC
        --   • Fermat    : étage 0 -> 0xx, étage 1 -> 1xx, étage 2 -> 2xx
        --                 Pas d'amphi
        --   • Pau       : unique bâtiment, étage 0 -> 0xx, étage 1 -> 1xx, étage 2 -> 2xx
        --                 Amphi Pau au RDC
        -- ---------------------------------------------------------------------------
        TYPE t_bat_desc IS RECORD (
            bat_id         NUMBER,
            nom            VARCHAR2(80),
            site_id        NUMBER,
            nb_etages      NUMBER,   -- nombre d'étages (hors toit)
            a_amphi        BOOLEAN,  -- présence d'un amphithéâtre
            prefix_rdc     NUMBER,   -- centaine du RDC
            prefix_step    NUMBER,   -- incrément entre étages 
            a_labo         BOOLEAN   -- présence de labos de recherche
        );
        TYPE t_bat_tab IS TABLE OF t_bat_desc INDEX BY PLS_INTEGER;
        v_bats t_bat_tab;
        idx    PLS_INTEGER;

        -- Variables locales pour la génération des salles
        v_code_salle  VARCHAR2(20);
        v_libelle     VARCHAR2(60);
        v_type_salle  VARCHAR2(20);
        v_capacite    NUMBER;
        v_prefix_etage NUMBER;   -- centaine effective pour cet étage
        v_nb_salles   NUMBER;
        v_is_labo     BOOLEAN;
    BEGIN
        PKG_GENERATOR.log('=== Entités de base ===');

        -- ---- Vérification des sites ----
        FOR rec IN cur_sites LOOP
            PKG_GENERATOR.log('  Site trouvé : ' || rec.NOM_SITE
                              || ' (' || rec.CODE_SITE || ')');
        END LOOP;

        -- =========================================================
        -- DÉPARTEMENTS
        -- Cergy (site_id=1) : IDs 1-8
        -- Pau   (site_id=2) : IDs 9-15
        -- =========================================================
        PKG_GENERATOR.log('  Génération des départements...');
        DECLARE
            TYPE t_dept IS RECORD (
                dept_id NUMBER, nom VARCHAR2(80), site_id NUMBER
            );
            TYPE t_dept_tab IS TABLE OF t_dept INDEX BY PLS_INTEGER;
            v_depts t_dept_tab;
            d PLS_INTEGER := 1;
        BEGIN
            -- Cergy
            v_depts(d).dept_id:=1;  v_depts(d).nom:='Direction Générale';               v_depts(d).site_id:=1; d:=d+1;
            v_depts(d).dept_id:=2;  v_depts(d).nom:='Direction Cergy';                  v_depts(d).site_id:=1; d:=d+1;
            v_depts(d).dept_id:=3;  v_depts(d).nom:='Service Informatique Cergy (DSI)'; v_depts(d).site_id:=1; d:=d+1;
            v_depts(d).dept_id:=4;  v_depts(d).nom:='Scolarité & Gestion Pédagogique'; v_depts(d).site_id:=1; d:=d+1;
            v_depts(d).dept_id:=5;  v_depts(d).nom:='Relations Internationales';        v_depts(d).site_id:=1; d:=d+1;
            v_depts(d).dept_id:=6;  v_depts(d).nom:='Relations Entreprises';            v_depts(d).site_id:=1; d:=d+1;
            v_depts(d).dept_id:=7;  v_depts(d).nom:='RH & Administration Cergy';        v_depts(d).site_id:=1; d:=d+1;
            v_depts(d).dept_id:=8;  v_depts(d).nom:='Recherche & Laboratoires Cergy';   v_depts(d).site_id:=1; d:=d+1;
            -- Pau
            v_depts(d).dept_id:=9;  v_depts(d).nom:='Direction Pau';                    v_depts(d).site_id:=2; d:=d+1;
            v_depts(d).dept_id:=10; v_depts(d).nom:='Service Informatique Pau (DSI)';   v_depts(d).site_id:=2; d:=d+1;
            v_depts(d).dept_id:=11; v_depts(d).nom:='Scolarité Pau';                    v_depts(d).site_id:=2; d:=d+1;
            v_depts(d).dept_id:=12; v_depts(d).nom:='Relations Internationales Pau';    v_depts(d).site_id:=2; d:=d+1;
            v_depts(d).dept_id:=13; v_depts(d).nom:='Relations Entreprises Pau';        v_depts(d).site_id:=2; d:=d+1;
            v_depts(d).dept_id:=14; v_depts(d).nom:='RH & Administration Pau';          v_depts(d).site_id:=2; d:=d+1;
            v_depts(d).dept_id:=15; v_depts(d).nom:='Recherche & Laboratoires Pau';     v_depts(d).site_id:=2;

            FOR j IN v_depts.FIRST..v_depts.LAST LOOP
                MERGE INTO GLPI_DEPARTEMENTS dd
                USING DUAL ON (dd.DEPT_ID = v_depts(j).dept_id)
                WHEN NOT MATCHED THEN
                    INSERT (DEPT_ID, NOM_DEPT, id_site, DATE_CREATION)
                    VALUES (v_depts(j).dept_id, v_depts(j).nom,
                            v_depts(j).site_id, DATE '2001-09-01');
            END LOOP;
        END;

        -- =========================================================
        -- BÂTIMENTS
        -- =========================================================
        PKG_GENERATOR.log('  Génération des bâtiments...');

        idx := 1;
        -- BAT 1 – Condorcet (Cergy)
        v_bats(idx).bat_id:=1; v_bats(idx).nom:='Bâtiment Condorcet';
        v_bats(idx).site_id:=1; v_bats(idx).nb_etages:=3;
        v_bats(idx).a_amphi:=TRUE; v_bats(idx).prefix_rdc:=1;
        v_bats(idx).prefix_step:=1; v_bats(idx).a_labo:=TRUE; idx:=idx+1;

        -- BAT 2 – Cauchy (Cergy)
        v_bats(idx).bat_id:=2; v_bats(idx).nom:='Bâtiment Cauchy';
        v_bats(idx).site_id:=1; v_bats(idx).nb_etages:=3;
        v_bats(idx).a_amphi:=TRUE; v_bats(idx).prefix_rdc:=1;
        v_bats(idx).prefix_step:=1; v_bats(idx).a_labo:=FALSE; idx:=idx+1;

        -- BAT 3 – Turing (Cergy)
        v_bats(idx).bat_id:=3; v_bats(idx).nom:='Bâtiment Turing';
        v_bats(idx).site_id:=1; v_bats(idx).nb_etages:=3;
        v_bats(idx).a_amphi:=TRUE; v_bats(idx).prefix_rdc:=0;
        v_bats(idx).prefix_step:=1; v_bats(idx).a_labo:=TRUE; idx:=idx+1;

        -- BAT 4 – Fermat (Cergy)
        v_bats(idx).bat_id:=4; v_bats(idx).nom:='Bâtiment Fermat';
        v_bats(idx).site_id:=1; v_bats(idx).nb_etages:=2;
        v_bats(idx).a_amphi:=FALSE; v_bats(idx).prefix_rdc:=0;
        v_bats(idx).prefix_step:=1; v_bats(idx).a_labo:=FALSE; idx:=idx+1;

        -- BAT 5 – Pau
        v_bats(idx).bat_id:=5; v_bats(idx).nom:='Bâtiment Pau';
        v_bats(idx).site_id:=2; v_bats(idx).nb_etages:=2;
        v_bats(idx).a_amphi:=TRUE; v_bats(idx).prefix_rdc:=0;
        v_bats(idx).prefix_step:=1; v_bats(idx).a_labo:=TRUE;

        -- nb_etages stocké en BDD = nombre d'étages hors RDC (ex. 3 pour Condorcet)
        FOR j IN v_bats.FIRST..v_bats.LAST LOOP
            MERGE INTO GLPI_BATIMENTS b
            USING DUAL ON (b.BAT_ID = v_bats(j).bat_id)
            WHEN NOT MATCHED THEN
                INSERT (BAT_ID, NOM_BATIMENT, id_site, NB_ETAGES, DATE_CONSTRUCTION)
                VALUES (v_bats(j).bat_id, v_bats(j).nom,
                        v_bats(j).site_id, v_bats(j).nb_etages,
                        DATE '1983-09-01');
        END LOOP;

        -- =========================================================
        -- SALLES
        -- =========================================================
        PKG_GENERATOR.log('  Génération des salles...');

        FOR j IN v_bats.FIRST..v_bats.LAST LOOP
            FOR etage IN 0..v_bats(j).nb_etages LOOP

                -- Calcul du préfixe centaine pour ce niveau
                v_prefix_etage := v_bats(j).prefix_rdc + etage * v_bats(j).prefix_step;

                -- Nombre de salles sur cet étage
                v_nb_salles := PKG_GENERATOR.rand_int(4, 9);

                FOR s IN 1..v_nb_salles LOOP

                    -- ---- Détermination du libellé et type ----

                    -- Amphithéâtre : RDC uniquement, salle 1, si le bât en a un
                    IF v_bats(j).a_amphi AND etage = 0 AND s = 1 THEN
                        v_libelle    := 'Amphi ' || v_bats(j).nom;
                        v_type_salle := 'COURS';
                        v_capacite   := PKG_GENERATOR.rand_int(80, 200);

                    -- Labo de recherche : dernier étage, salles 1 et 2, si le bât en a
                    ELSIF v_bats(j).a_labo
                          AND etage = v_bats(j).nb_etages
                          AND s <= 2 THEN
                        v_libelle    := 'Labo ' || LPAD(v_prefix_etage * 100 + s, 3, '0');
                        v_type_salle := 'LABO';
                        v_capacite   := PKG_GENERATOR.rand_int(10, 25);

                    -- Cas général : numérotation Xss
                    ELSE
                        v_libelle    := LPAD(v_prefix_etage * 100 + s, 3, '0');
                        v_type_salle := CASE
                            WHEN etage = 0 AND s > 2 THEN 'REUNION'
                            WHEN MOD(s, 2) = 0       THEN 'TP'
                            ELSE                          'COURS'
                        END;
                        v_capacite   := CASE v_type_salle
                            WHEN 'TP'      THEN PKG_GENERATOR.rand_int(20, 40)
                            WHEN 'COURS'   THEN PKG_GENERATOR.rand_int(30, 60)
                            WHEN 'REUNION' THEN PKG_GENERATOR.rand_int(8, 20)
                            ELSE 30
                        END;
                    END IF;

                    v_code_salle := 'B' || v_bats(j).bat_id || '-'
                                    || LPAD(v_prefix_etage * 100 + s, 3, '0');

                    INSERT INTO GLPI_SALLES (
                        id, CODE_SALLE, LIBELLE, ETAGE,
                        CAPACITE_POSTES, id_batiment, TYPE_SALLE
                    ) VALUES (
                        SEQ_SALLE.NEXTVAL,
                        v_code_salle,
                        v_libelle,
                        etage,
                        v_capacite,
                        v_bats(j).bat_id,
                        v_type_salle
                    );
                END LOOP;  
            END LOOP;  -- etage
        END LOOP;  -- bâtiment

        COMMIT;
        PKG_GENERATOR.log('  Entités de base OK.');
    END gen_entites_base;


    -- =========================================================================
    -- 3.2  UTILISATEURS  (étudiants, enseignants, personnels, admins)
    -- =========================================================================
    PROCEDURE gen_utilisateurs IS
        t_prenoms SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
            'Pooja','Mihai','Théo','Arjun','Nguyen','Gabriel','Hye-Jin','Sana','Inès','Carlos',
            'Fatoumata','Camille','Mehdi','Linh','Rohan','Amira','Hugo','Aïssatou','Vasile','Jules',
            'Elena','Zineb','Wei','Nadia','Mamadou','Andrei','Sarah','Kofi','Ji-Won','Tarek',
            'Min-Jun','Océane','Katarzyna','Tidiane','Thi','David','Agnieszka','Nicolas','Yann','Bintou',
            'Rachid','Emma','Sofia','Priya','Romain','Adama','Samira','Louis','Mirela','Sébastien',
            'Amine','Alice','Dounia','Ibrahima','Lucie','Karim','Diego','Aminata','Nathan','Mourad',
            'Baptiste','Rokhaya','Kavya','Miguel','Oumar','Hajar','Maxime','Aïsha','François','Leila',
            'Bogdan','Léa','Ananya','Isabella','Jihane','Tariq','Adrien','Phuong','Alexis','Aya',
            'Seung','Gaëlle','Pierre','Hamid','Hui','Mathis','Nafissatou','Youssef','Ioana','Valentin',
            'Mateo','Ryan','Riya','Modou','Diane','Yasmine','Manon','Astou','Sebastián','Clément',
            'Jing','Khady','Minh','Soo-Yeon','Reda','Imane','Valentine','Gariela','Ophélie','Jun',
            'Ayoub','Paul','Xin','Camila','Ilyas','Marie','Tomašz','Monika','Devi','Adriana',
            'Liam','Julien','Lan','Cristian','Fatima','Houda','Antoine','Adam','Nour','Quentin',
            'Ming','Przemek','Samir','Rim','Lei','Elisa','Bilal','Seydou','Mariam','Rachel',
            'Pawel','Lucas','Zoé','Laura','Noah','Vikram','Duc','Iris','Omar','Karima'
        );
        t_noms SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
            'Popescu','Ndiaye','Garcia','Diallo','Morel','Zhang','Schmidt','Popa','Benkhaled','Kumar',
            'Lefebvre','Nguyen','Boudiaf','Martinez','Russo','Traoré','Kim','Dumont','Gupta','Sow',
            'Ziani','Rousseau','Moreau','Park','Belkacem','Leroy','Costa','Sánchez','Fournier','Lee',
            'Merzouki','Ionescu','Singh','Faure','Khelifi','Dridi','Garnier','Perrin','Hadj','Lahlou',
            'Jovanovic','Gueye','Wang','Lopez','Martin','Cissé','Fischer','Radu','Rachidi','Huang',
            'Esposito','Legrand','Patel','Dupont','Richard','Yoon','Bertrand','Sanogo','Mehta','Ferreira',
            'Bernard','Gonzalez','Touré','Meziani','Kowalski','Gauthier','Dubois','Ramirez','Khalil','Mueller',
            'Sylla','Pham','Dinu','Nikolic','Laurent','Hamdi','Verma','Rao','Bensalah','Bonnet',
            'Wojciechowski','Jabrane','Garnier','Vincent','Flores','Slimani','Chen','Lefèvre','Nowak','Rodriguez',
            'Michel','Ferreira','Bah','Kowalczyk','Moreau','Torres','Roux','Choi','Nair','Diouf',
            'Ouali','Weber','Girard','Liu','Fall','El Mansouri','Kaminski','Joshi','Amrani','Lambert',
            'Jung','Petrovic','Fernandez','Roussel','Tahir','Guérin','Sharma','Morel','Mbaye','Bouazza',
            'Umer','Kouyaté','Keita','Nasser','Ferrari','Fontaine','Perrin','Vu','Dinu','Moreau',
            'Do','Romano','Santos','Markovic','Le','Hoang','Ziani','Popa','Oliveira','Garnier',
            'Farouk','Morel','Robert','Idrissi','Mathieu','Khelifi','Durand','Saidi','Blanc','Tran'
        );
        t_domaines SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
            'cytech.fr','cyu.fr','etu.cytech.fr'
        );
        -- id_role est une FK numérique vers la table Role 
        -- 1=admin, 2=technicien, 3=utilisateur, 4=enseignant, 5=etudiant
        -- Distribution réaliste : majorité étudiants
        t_role_ids SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
            '5','5','5','5',  -- majorité étudiants
            '4','4',          -- enseignants
            '2','1','3'       -- technicien, admin, personnel
        );

        v_prenom    VARCHAR2(50);
        v_nom       VARCHAR2(50);
        v_login     VARCHAR2(100);
        v_email     VARCHAR2(150);
        v_role_id   NUMBER;  -- FK vers Role.id 
        v_dept_id   NUMBER;
        v_site_id   NUMBER;
        v_nb_cergy  NUMBER := PKG_GENERATOR.cfg('NB_UTILISATEURS_CERGY');
        v_nb_pau    NUMBER := PKG_GENERATOR.cfg('NB_UTILISATEURS_PAU');
        v_total     NUMBER;
        v_user_id   NUMBER;
        v_annee_promo NUMBER;

        -- Curseur de contrôle : vérifie les doublons de login
        CURSOR cur_check_login(p_login VARCHAR2) IS
            SELECT COUNT(*) FROM GLPI_UTILISATEURS WHERE LOGIN = p_login;
        v_count NUMBER;
        v_suffix NUMBER;
    BEGIN
        PKG_GENERATOR.log('=== Utilisateurs ===');
        v_total := v_nb_cergy + v_nb_pau;

        FOR i IN 1..v_total LOOP
            v_prenom  := PKG_GENERATOR.pick(t_prenoms);
            v_nom     := PKG_GENERATOR.pick(t_noms);
            -- id_role est un entier FK vers Role.id (et non un VARCHAR2 libre)
            v_role_id := TO_NUMBER(PKG_GENERATOR.pick(t_role_ids));

            -- Répartition Cergy / Pau
            IF i <= v_nb_cergy THEN
                v_site_id := 1;
                -- Depts Cergy : IDs 1 à 8
                v_dept_id := PKG_GENERATOR.rand_int(1, 8);
            ELSE
                v_site_id := 2;
                -- Depts Pau : IDs 9 à 15
                v_dept_id := PKG_GENERATOR.rand_int(9, 15);
            END IF;

            -- Construction du login : première lettre prénom + nom (minuscule)
            v_login := LOWER(SUBSTR(v_prenom, 1, 1) || v_nom);
            -- Unicité du login via curseur
            OPEN cur_check_login(v_login);
            FETCH cur_check_login INTO v_count;
            CLOSE cur_check_login;
            IF v_count > 0 THEN
                v_suffix := PKG_GENERATOR.rand_int(1, 999);
                v_login  := v_login || TO_CHAR(v_suffix);
            END IF;

            v_email := v_login || '@' ||
                       PKG_GENERATOR.pick(t_domaines);

            -- Promotion si étudiant (id_role = 5)
            IF v_role_id = 5 THEN
                v_annee_promo := PKG_GENERATOR.rand_int(2024, 2027);
            ELSE
                v_annee_promo := NULL;
            END IF;

            INSERT INTO GLPI_UTILISATEURS (
                id, NOM, PRENOM, LOGIN, EMAIL, id_role,
                DEPT_ID, id_site, ANNEE_PROMO,
                DATE_CREATION, ACTIF, LAST_LOGIN
            ) VALUES (
                SEQ_UTILISATEUR.NEXTVAL,
                UPPER(v_nom), v_prenom, v_login, v_email, v_role_id,
                v_dept_id, v_site_id, v_annee_promo,
                PKG_GENERATOR.rand_date(DATE '2018-09-01', SYSDATE - 30),
                PKG_GENERATOR.pick(SYS.ODCIVARCHAR2LIST('O','O','O','N')),
                PKG_GENERATOR.rand_date(SYSDATE - 180, SYSDATE)
            );

            -- Commit tous les 200 enregistrements pour éviter les rollback segments surdimensionnés
            IF MOD(i, 200) = 0 THEN
                COMMIT;
                PKG_GENERATOR.log('  ' || i || '/' || v_total || ' utilisateurs insérés...');
            END IF;
        END LOOP;

        COMMIT;
        PKG_GENERATOR.log('  Utilisateurs OK : ' || v_total || ' insérés.');
    END gen_utilisateurs;


    -- =========================================================================
    -- 3.3  RÉSEAUX  (VLANs, sous-réseaux, adresses IP)
    -- =========================================================================
    PROCEDURE gen_reseaux IS
        v_nb_vlan   NUMBER := PKG_GENERATOR.cfg('NB_VLANS');
        v_nb_subnet NUMBER := PKG_GENERATOR.cfg('NB_SOUS_RESEAUX');

        -- Plages réservées par site et usage
        TYPE t_plage IS RECORD (
            base      VARCHAR2(12),
            site_id   NUMBER,
            usage_net VARCHAR2(30)
        );
        TYPE t_plages_tab IS TABLE OF t_plage INDEX BY PLS_INTEGER;
        v_plages t_plages_tab;

        v_vlan_id    NUMBER;
        v_subnet_id  NUMBER;
        v_gateway    VARCHAR2(20);
        v_dns1       VARCHAR2(20);
        v_dns2       VARCHAR2(20);
    BEGIN
        PKG_GENERATOR.log('=== Réseaux ===');

        -- Plan d'adressage CY Tech
        -- Cergy : 10.10.x.0/24  (x = 1..20)
        -- Pau   : 10.20.x.0/24  (x = 1..10)
        FOR i IN 1..v_nb_vlan LOOP
            IF i <= ROUND(v_nb_vlan * 0.67) THEN
                -- VLAN Cergy
                v_vlan_id := i + 100;    -- VLAN IDs : 101-120 Cergy
                INSERT INTO GLPI_VLANS (
                    id, NUMERO_VLAN, NOM_VLAN, DESCRIPTION,
                    id_site, ACTIF
                ) VALUES (
                    SEQ_VLAN.NEXTVAL, v_vlan_id,
                    'VLAN-CY-' || PKG_GENERATOR.pick(SYS.ODCIVARCHAR2LIST(
                        'ETUDIANT','ENSEIGNANT','ADMIN','SERVEUR',
                        'WIFI','IMPRIMANTES','VOIP','DMZ','LABO')),
                    'VLAN automatique site Cergy', 1, 'O'
                );
            ELSE
                -- VLAN Pau
                v_vlan_id := i + 200;    -- VLAN IDs : 201-210 Pau
                INSERT INTO GLPI_VLANS (
                    id, NUMERO_VLAN, NOM_VLAN, DESCRIPTION,
                    id_site, ACTIF
                ) VALUES (
                    SEQ_VLAN.NEXTVAL, v_vlan_id,
                    'VLAN-PAU-' || PKG_GENERATOR.pick(SYS.ODCIVARCHAR2LIST(
                        'ETUDIANT','ENSEIGNANT','ADMIN','SERVEUR','WIFI')),
                    'VLAN automatique site Pau', 2, 'O'
                );
            END IF;
        END LOOP;

        -- Sous-réseaux associés aux VLANs
        DECLARE
            v_octet3    NUMBER;
            v_site_id   NUMBER;
            v_base      VARCHAR2(12);
            CURSOR cur_vlans IS
                SELECT id, id_site FROM GLPI_VLANS ORDER BY id;
            v_compteur  NUMBER := 0;
        BEGIN
            FOR vlan_rec IN cur_vlans LOOP
                EXIT WHEN v_compteur >= v_nb_subnet;
                v_octet3 := MOD(v_compteur, 20) + 1;

                IF vlan_rec.id_site = 1 THEN
                    v_base    := '10.10.' || v_octet3;
                    v_gateway := v_base   || '.1';
                    v_dns1    := '10.10.0.53';
                    v_dns2    := '10.10.0.54';
                ELSE
                    v_base    := '10.20.' || v_octet3;
                    v_gateway := v_base   || '.1';
                    v_dns1    := '10.20.0.53';
                    v_dns2    := '10.20.0.54';
                END IF;

                INSERT INTO GLPI_SOUS_RESEAUX (
                    id, ADRESSE_RESEAU, MASQUE, PREFIXE,
                    GATEWAY, DNS_PRIMAIRE, DNS_SECONDAIRE,
                    id_vlan, NOM_RESEAU, id_site
                ) VALUES (
                    SEQ_SUBNET.NEXTVAL,
                    v_base || '.0',
                    '255.255.255.0',
                    24,
                    v_gateway,
                    v_dns1, v_dns2,
                    vlan_rec.id,
                    'Réseau ' || v_base || '.0/24',
                    vlan_rec.id_site
                );
                v_compteur := v_compteur + 1;
            END LOOP;
        END;

        COMMIT;
        PKG_GENERATOR.log('  Réseaux OK : ' || v_nb_vlan || ' VLANs, ' ||
                          v_nb_subnet || ' sous-réseaux.');
    END gen_reseaux;


    -- =========================================================================
    -- 3.4  MATÉRIELS  (ordinateurs, serveurs, imprimantes, switches)
    -- =========================================================================
    PROCEDURE gen_materiels IS
        t_marques_pc   SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
            'Dell','HP','Lenovo','Apple','Asus','Acer','Microsoft');
        t_modeles_pc   SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
            'Latitude 5530','EliteBook 840 G9','ThinkPad X1 Carbon',
            'MacBook Pro 14','ZenBook 14','Aspire 5','Surface Pro 9',
            'Optiplex 7090','ProDesk 400 G9','ThinkCentre M70');
        t_os           SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
            'Windows 11 Pro','Windows 10 Pro','Ubuntu 22.04 LTS',
            'macOS Sonoma','Fedora 39','Debian 12');
        t_marques_srv  SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
            'Dell','HP','IBM','Cisco','SuperMicro');
        t_modeles_srv  SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
            'PowerEdge R750','ProLiant DL380 Gen10','System x3650',
            'UCS C220 M6','SuperServer 6019U');
        t_etats        SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
            'EN_SERVICE','EN_SERVICE','EN_SERVICE',
            'EN_MAINTENANCE','EN_STOCK','HORS_SERVICE');
        t_marques_impr SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
            'HP','Canon','Ricoh','Xerox','Brother','Epson');
        t_marques_sw   SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
            'Cisco','Juniper','HP Aruba','Netgear','D-Link');

        v_nb_pc_cergy  NUMBER := PKG_GENERATOR.cfg('NB_ORDINATEURS_CERGY');
        v_nb_pc_pau    NUMBER := PKG_GENERATOR.cfg('NB_ORDINATEURS_PAU');
        v_nb_srv       NUMBER := PKG_GENERATOR.cfg('NB_SERVEURS');
        v_nb_impr      NUMBER := PKG_GENERATOR.cfg('NB_IMPRIMANTES');
        v_nb_sw        NUMBER := PKG_GENERATOR.cfg('NB_SWITCHES');

        -- Curseur : récupère un sous-réseau aléatoire par site
        CURSOR cur_subnet_cergy IS
            SELECT ADRESSE_RESEAU, id
            FROM   GLPI_SOUS_RESEAUX
            WHERE  id_site = 1
            ORDER BY DBMS_RANDOM.VALUE;

        CURSOR cur_subnet_pau IS
            SELECT ADRESSE_RESEAU, id
            FROM   GLPI_SOUS_RESEAUX
            WHERE  id_site = 2
            ORDER BY DBMS_RANDOM.VALUE;

        v_subnet_base  VARCHAR2(15);
        v_subnet_id    NUMBER;
        v_site_id      NUMBER;
        v_ram_gb       NUMBER;
        v_cpu_cores    NUMBER;
        v_stockage_go  NUMBER;
        v_mat_id       NUMBER;

        -- Procédure interne : insère un ordinateur/laptop
        PROCEDURE ins_ordinateur(p_site_id IN NUMBER) IS
            v_marque   VARCHAR2(50);
            v_modele   VARCHAR2(80);
            v_base     VARCHAR2(12);
            v_sub_id   NUMBER;
        BEGIN
            -- Choisir un sous-réseau du bon site (curseur réutilisé)
            IF p_site_id = 1 THEN
                SELECT SUBSTR(ADRESSE_RESEAU, 1,
                              INSTR(ADRESSE_RESEAU,'.',1,3)-1),
                       id
                INTO   v_base, v_sub_id
                FROM   GLPI_SOUS_RESEAUX
                WHERE  id_site = 1
                AND    ROWNUM = 1
                ORDER BY DBMS_RANDOM.VALUE;
            ELSE
                SELECT SUBSTR(ADRESSE_RESEAU, 1,
                              INSTR(ADRESSE_RESEAU,'.',1,3)-1),
                       id
                INTO   v_base, v_sub_id
                FROM   GLPI_SOUS_RESEAUX
                WHERE  id_site = 2
                AND    ROWNUM = 1
                ORDER BY DBMS_RANDOM.VALUE;
            END IF;

            v_marque := PKG_GENERATOR.pick(t_marques_pc);
            v_modele := PKG_GENERATOR.pick(t_modeles_pc);
            v_ram_gb  := PKG_GENERATOR.pick(
                            SYS.ODCIVARCHAR2LIST('8','16','16','32','64'));
            v_cpu_cores := PKG_GENERATOR.pick(
                            SYS.ODCIVARCHAR2LIST('4','6','8','8','12'));

            INSERT INTO GLPI_MATERIELS (
                id, NOM_MACHINE, TYPE_MATERIEL, MARQUE, MODELE,
                NUM_SERIE, ADRESSE_MAC, ADRESSE_IP, id_sous_reseau,
                OS, RAM_GO, CPU_COEURS, STOCKAGE_GO,
                ETAT, id_site, DATE_ACHAT, DATE_GARANTIE_FIN,
                DERNIERE_SYNCHRO
            ) VALUES (
                SEQ_MATERIEL.NEXTVAL,
                UPPER(v_marque) || '-' || PKG_GENERATOR.gen_serial(),
                PKG_GENERATOR.pick(SYS.ODCIVARCHAR2LIST(
                    'ORDINATEUR_FIXE','ORDINATEUR_FIXE','LAPTOP','LAPTOP')),
                v_marque, v_modele,
                PKG_GENERATOR.gen_serial(),
                PKG_GENERATOR.gen_mac(),
                PKG_GENERATOR.gen_ip(v_base),
                v_sub_id,
                PKG_GENERATOR.pick(t_os),
                TO_NUMBER(v_ram_gb), TO_NUMBER(v_cpu_cores),
                PKG_GENERATOR.rand_int(256, 2048),
                PKG_GENERATOR.pick(t_etats),
                p_site_id,
                PKG_GENERATOR.rand_date(DATE '2018-01-01', SYSDATE - 30),
                PKG_GENERATOR.rand_date(SYSDATE, SYSDATE + 365*3),
                PKG_GENERATOR.rand_date(SYSDATE - 30, SYSDATE)
            );
        END ins_ordinateur;

    BEGIN
        PKG_GENERATOR.log('=== Matériels ===');

        -- Ordinateurs Cergy
        FOR i IN 1..v_nb_pc_cergy LOOP
            ins_ordinateur(1);
            IF MOD(i, 300) = 0 THEN
                COMMIT;
                PKG_GENERATOR.log('  PC Cergy : ' || i || '/' || v_nb_pc_cergy);
            END IF;
        END LOOP;
        COMMIT;

        -- Ordinateurs Pau
        FOR i IN 1..v_nb_pc_pau LOOP
            ins_ordinateur(2);
            IF MOD(i, 200) = 0 THEN
                COMMIT;
                PKG_GENERATOR.log('  PC Pau : ' || i || '/' || v_nb_pc_pau);
            END IF;
        END LOOP;
        COMMIT;

        -- Serveurs (répartis 70% Cergy, 30% Pau)
        PKG_GENERATOR.log('  Génération des serveurs...');
        FOR i IN 1..v_nb_srv LOOP
            v_site_id := CASE WHEN i <= ROUND(v_nb_srv * 0.7) THEN 1 ELSE 2 END;
            INSERT INTO GLPI_MATERIELS (
                id, NOM_MACHINE, TYPE_MATERIEL, MARQUE, MODELE,
                NUM_SERIE, ADRESSE_MAC, ADRESSE_IP, id_sous_reseau,
                OS, RAM_GO, CPU_COEURS, STOCKAGE_GO,
                ETAT, id_site, DATE_ACHAT, DATE_GARANTIE_FIN,
                DERNIERE_SYNCHRO, EST_VIRTUEL
            )
            SELECT
                SEQ_MATERIEL.NEXTVAL,
                'SRV-' || PKG_GENERATOR.gen_serial(),
                PKG_GENERATOR.pick(SYS.ODCIVARCHAR2LIST(
                    'SERVEUR_PHYSIQUE','SERVEUR_PHYSIQUE','SERVEUR_VIRTUEL')),
                PKG_GENERATOR.pick(t_marques_srv),
                PKG_GENERATOR.pick(t_modeles_srv),
                PKG_GENERATOR.gen_serial(),
                PKG_GENERATOR.gen_mac(),
                PKG_GENERATOR.gen_ip(
                    CASE WHEN v_site_id = 1 THEN '10.10.1' ELSE '10.20.1' END),
                (SELECT id FROM GLPI_SOUS_RESEAUX
                 WHERE id_site = v_site_id AND ROWNUM = 1
                 ORDER BY DBMS_RANDOM.VALUE),
                PKG_GENERATOR.pick(SYS.ODCIVARCHAR2LIST(
                    'Windows Server 2022','Ubuntu Server 22.04',
                    'RHEL 9','Debian 12','VMware ESXi 8')),
                PKG_GENERATOR.rand_int(64, 512),
                PKG_GENERATOR.rand_int(16, 128),
                PKG_GENERATOR.rand_int(1000, 20000),
                PKG_GENERATOR.pick(SYS.ODCIVARCHAR2LIST(
                    'EN_SERVICE','EN_SERVICE','EN_SERVICE','EN_MAINTENANCE')),
                v_site_id,
                PKG_GENERATOR.rand_date(DATE '2015-01-01', SYSDATE - 60),
                PKG_GENERATOR.rand_date(SYSDATE, SYSDATE + 365*5),
                SYSDATE - PKG_GENERATOR.rand_int(0, 7),
                CASE WHEN PKG_GENERATOR.rand_int(1,3) = 1 THEN 'O' ELSE 'N' END
            FROM DUAL;
        END LOOP;
        COMMIT;

        -- Imprimantes
        PKG_GENERATOR.log('  Génération des imprimantes...');
        FOR i IN 1..v_nb_impr LOOP
            v_site_id := CASE WHEN i <= ROUND(v_nb_impr * 0.67) THEN 1 ELSE 2 END;
            INSERT INTO GLPI_MATERIELS (
                id, NOM_MACHINE, TYPE_MATERIEL, MARQUE, MODELE,
                NUM_SERIE, ADRESSE_MAC, ADRESSE_IP, id_sous_reseau,
                ETAT, id_site, DATE_ACHAT, DATE_GARANTIE_FIN, DERNIERE_SYNCHRO
            )
            SELECT
                SEQ_MATERIEL.NEXTVAL,
                'IMPR-' || PKG_GENERATOR.gen_serial(),
                'IMPRIMANTE',
                PKG_GENERATOR.pick(t_marques_impr),
                PKG_GENERATOR.pick(SYS.ODCIVARCHAR2LIST(
                    'LaserJet Pro M404','imageCLASS MF445',
                    'Aficio MP C2004','VersaLink C405',
                    'HL-L3270CDW','EcoTank ET-5800')),
                PKG_GENERATOR.gen_serial(),
                PKG_GENERATOR.gen_mac(),
                PKG_GENERATOR.gen_ip(
                    CASE WHEN v_site_id = 1 THEN '10.10.5' ELSE '10.20.5' END),
                (SELECT id FROM GLPI_SOUS_RESEAUX
                 WHERE id_site = v_site_id AND ROWNUM = 1),
                PKG_GENERATOR.pick(t_etats),
                v_site_id,
                PKG_GENERATOR.rand_date(DATE '2019-01-01', SYSDATE - 30),
                PKG_GENERATOR.rand_date(SYSDATE, SYSDATE + 365*3),
                SYSDATE - PKG_GENERATOR.rand_int(0, 14)
            FROM DUAL;
        END LOOP;
        COMMIT;

        -- Switches et équipements réseau
        PKG_GENERATOR.log('  Génération des switches...');
        FOR i IN 1..v_nb_sw LOOP
            v_site_id := CASE WHEN i <= ROUND(v_nb_sw * 0.67) THEN 1 ELSE 2 END;
            INSERT INTO GLPI_MATERIELS (
                id, NOM_MACHINE, TYPE_MATERIEL, MARQUE, MODELE,
                NUM_SERIE, ADRESSE_MAC, ADRESSE_IP, id_sous_reseau,
                ETAT, id_site, DATE_ACHAT, DATE_GARANTIE_FIN, DERNIERE_SYNCHRO,
                NB_PORTS
            )
            SELECT
                SEQ_MATERIEL.NEXTVAL,
                PKG_GENERATOR.pick(SYS.ODCIVARCHAR2LIST(
                    'SW','RTR','AP','FW')) || '-' || PKG_GENERATOR.gen_serial(),
                PKG_GENERATOR.pick(SYS.ODCIVARCHAR2LIST(
                    'SWITCH','SWITCH','ROUTEUR','BORNE_WIFI','FIREWALL')),
                PKG_GENERATOR.pick(t_marques_sw),
                PKG_GENERATOR.pick(SYS.ODCIVARCHAR2LIST(
                    'Catalyst 9300','EX3400','Aruba 2930F',
                    'GS308E','DGS-1210','SRX345')),
                PKG_GENERATOR.gen_serial(),
                PKG_GENERATOR.gen_mac(),
                PKG_GENERATOR.gen_ip(
                    CASE WHEN v_site_id = 1 THEN '10.10.0' ELSE '10.20.0' END),
                (SELECT id FROM GLPI_SOUS_RESEAUX
                 WHERE id_site = v_site_id AND ROWNUM = 1),
                PKG_GENERATOR.pick(SYS.ODCIVARCHAR2LIST(
                    'EN_SERVICE','EN_SERVICE','EN_SERVICE','EN_MAINTENANCE')),
                v_site_id,
                PKG_GENERATOR.rand_date(DATE '2016-01-01', SYSDATE - 60),
                PKG_GENERATOR.rand_date(SYSDATE + 365, SYSDATE + 365*7),
                SYSDATE - PKG_GENERATOR.rand_int(0, 3),
                PKG_GENERATOR.pick(SYS.ODCIVARCHAR2LIST('24','48','8','16','12'))
            FROM DUAL;
        END LOOP;
        COMMIT;
        PKG_GENERATOR.log('  Matériels OK.');
    END gen_materiels;


    -- =========================================================================
    -- 3.5  AFFECTATIONS  (matériels <=> utilisateurs, matériels <=> salles)
    -- =========================================================================
    PROCEDURE gen_affectations IS
        -- Curseur : matériels de type PC/Laptop en service
        CURSOR cur_pcs IS
            SELECT id, id_site
            FROM   GLPI_MATERIELS
            WHERE  TYPE_MATERIEL IN ('ORDINATEUR_FIXE','LAPTOP')
            AND    ETAT = 'EN_SERVICE'
            ORDER BY DBMS_RANDOM.VALUE;

        -- Curseur : utilisateurs actifs par site
        CURSOR cur_users(p_site_id NUMBER) IS
            SELECT id
            FROM   GLPI_UTILISATEURS
            WHERE  id_site = p_site_id AND ACTIF = 'O'
            ORDER BY DBMS_RANDOM.VALUE;

        -- Curseur : salles par site
        CURSOR cur_salles(p_site_id NUMBER) IS
            SELECT SALLE_ID, CAPACITE_POSTES, TYPE_SALLE
            FROM   GLPI_SALLES s
            JOIN   GLPI_BATIMENTS b ON s.id_batiment = b.BAT_ID
            WHERE  b.id_site = p_site_id
            AND    s.TYPE_SALLE IN ('TP','COURS')
            ORDER BY DBMS_RANDOM.VALUE;

        TYPE t_user_ids IS TABLE OF NUMBER INDEX BY PLS_INTEGER;
        v_users_cergy t_user_ids;
        v_users_pau   t_user_ids;
        v_idx         PLS_INTEGER;
        v_user_id     NUMBER;
        v_salle_id    NUMBER;
        v_nb_aff      NUMBER := 0;

    BEGIN
        PKG_GENERATOR.log('=== Affectations matériels ===');

        -- Chargement des user IDs en mémoire (collections) pour perf
        v_idx := 1;
        FOR u IN cur_users(1) LOOP
            v_users_cergy(v_idx) := u.id;
            v_idx := v_idx + 1;
        END LOOP;
        v_idx := 1;
        FOR u IN cur_users(2) LOOP
            v_users_pau(v_idx) := u.id;
            v_idx := v_idx + 1;
        END LOOP;

        -- Affectation PC -> Utilisateur (1 PC peut avoir 1 utilisateur principal)
        FOR pc IN cur_pcs LOOP
            -- 85% des PC sont affectés à un utilisateur
            IF PKG_GENERATOR.rand_int(1, 100) <= 85 THEN
                IF pc.id_site = 1 AND v_users_cergy.COUNT > 0 THEN
                    v_user_id := v_users_cergy(
                        PKG_GENERATOR.rand_int(1, v_users_cergy.COUNT));
                ELSIF pc.id_site = 2 AND v_users_pau.COUNT > 0 THEN
                    v_user_id := v_users_pau(
                        PKG_GENERATOR.rand_int(1, v_users_pau.COUNT));
                ELSE
                    CONTINUE;
                END IF;

                BEGIN
                    INSERT INTO GLPI_AFFECTATIONS (
                        id, id_materiel, id_utilisateur, DATE_DEBUT,
                        DATE_FIN, TYPE_AFF, COMMENTAIRE
                    ) VALUES (
                        SEQ_AFFECTATION.NEXTVAL,
                        pc.id, v_user_id,
                        PKG_GENERATOR.rand_date(DATE '2020-01-01', SYSDATE - 30),
                        CASE WHEN PKG_GENERATOR.rand_int(1,10) <= 2
                             THEN PKG_GENERATOR.rand_date(SYSDATE - 90, SYSDATE)
                             ELSE NULL END,  -- NULL = affectation en cours
                        PKG_GENERATOR.pick(SYS.ODCIVARCHAR2LIST(
                            'PRINCIPAL','PRET_COURT','PRET_LONG')),
                        NULL
                    );
                    v_nb_aff := v_nb_aff + 1;
                EXCEPTION WHEN DUP_VAL_ON_INDEX THEN NULL;
                END;
            END IF;

            IF MOD(v_nb_aff, 500) = 0 AND v_nb_aff > 0 THEN
                COMMIT;
            END IF;
        END LOOP;

        -- Affectation Salle -> Matériels (salles TP/Cours ont des PC fixes)
        DECLARE
            v_cap NUMBER;
            v_mat_id NUMBER;
            CURSOR cur_mat_libres(p_site_id NUMBER) IS
                SELECT m.id
                FROM   GLPI_MATERIELS m
                WHERE  m.id_site = p_site_id
                AND    m.TYPE_MATERIEL = 'ORDINATEUR_FIXE'
                AND    m.ETAT = 'EN_SERVICE'
                AND    NOT EXISTS (
                    SELECT 1 FROM GLPI_MAT_SALLES ms WHERE ms.id_materiel = m.id)
                ORDER BY DBMS_RANDOM.VALUE;
        BEGIN
            FOR salle IN cur_salles(1) LOOP
                v_cap := LEAST(salle.CAPACITE_POSTES, 30);
                FOR mat IN cur_mat_libres(1) LOOP
                    EXIT WHEN v_cap <= 0;
                    INSERT INTO GLPI_MAT_SALLES (id_materiel, id_salle, DATE_INSTALLATION)
                    VALUES (mat.id, salle.SALLE_ID,
                            PKG_GENERATOR.rand_date(DATE '2019-01-01', SYSDATE - 60));
                    v_cap := v_cap - 1;
                END LOOP;
            END LOOP;
            FOR salle IN cur_salles(2) LOOP
                v_cap := LEAST(salle.CAPACITE_POSTES, 20);
                FOR mat IN cur_mat_libres(2) LOOP
                    EXIT WHEN v_cap <= 0;
                    INSERT INTO GLPI_MAT_SALLES (id_materiel, id_salle, DATE_INSTALLATION)
                    VALUES (mat.id, salle.SALLE_ID,
                            PKG_GENERATOR.rand_date(DATE '2019-01-01', SYSDATE - 60));
                    v_cap := v_cap - 1;
                END LOOP;
            END LOOP;
        END;

        COMMIT;
        PKG_GENERATOR.log('  Affectations OK : ' || v_nb_aff || ' user-mat.');
    END gen_affectations;


    -- =========================================================================
    -- 3.6  TICKETS HISTORIQUES  (charge réaliste sur 3 ans)
    -- =========================================================================
    PROCEDURE gen_tickets_historique IS
        v_nb_tickets NUMBER := PKG_GENERATOR.cfg('NB_TICKETS');

        t_categories SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
            'INCIDENT_MATERIEL','INCIDENT_LOGICIEL','DEMANDE_ACCES',
            'DEMANDE_INSTALLATION','PANNE_RESEAU','PANNE_IMPRIMANTE',
            'DEMANDE_CONSEIL','INCIDENT_SECURITE','CHANGEMENT_MATERIEL',
            'MISE_A_JOUR');
        t_priorites SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
            'CRITIQUE','HAUTE','HAUTE','NORMALE','NORMALE','NORMALE','BASSE');
        t_statuts_fermes SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
            'RESOLU','FERME','CLOS');
        t_statuts_ouverts SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
            'OUVERT','EN_COURS','EN_ATTENTE','EN_ATTENTE_TIERS');

        v_ticket_id  NUMBER;
        v_user_id    NUMBER;
        v_technicien NUMBER;
        v_mat_id     NUMBER;
        v_date_ouv   DATE;
        v_date_ferm  DATE;
        v_statut     VARCHAR2(30);
        v_duree_res  NUMBER;  -- en heures
        v_site_id    NUMBER;

        -- Curseur utilisateurs aléatoires (table complète chargée en mémoire)
        TYPE t_ids IS TABLE OF NUMBER;
        v_all_users  t_ids;
        v_techs      t_ids;
        v_all_mats   t_ids;

    BEGIN
        PKG_GENERATOR.log('=== Tickets historiques ===');

        -- Chargement des IDs en mémoire pour éviter des sous-requêtes répétées
        SELECT id BULK COLLECT INTO v_all_users
        FROM   GLPI_UTILISATEURS WHERE ACTIF = 'O';

        SELECT id BULK COLLECT INTO v_techs
        FROM   GLPI_UTILISATEURS
        WHERE  id_role IN (1, 2);  -- 1=admin, 2=technicien

        SELECT id BULK COLLECT INTO v_all_mats
        FROM   GLPI_MATERIELS WHERE ETAT = 'EN_SERVICE';

        PKG_GENERATOR.log('  ' || v_all_users.COUNT || ' users, ' ||
                          v_techs.COUNT || ' techniciens, ' ||
                          v_all_mats.COUNT || ' matériels chargés.');

        -- Génération des tickets via FORALL pour performances
        DECLARE
            TYPE t_ticket_rec IS RECORD (
                ticket_id NUMBER, titre VARCHAR2(200), categorie VARCHAR2(50),
                priorite VARCHAR2(20), statut VARCHAR2(30),
                user_id NUMBER, technicien_id NUMBER, mat_id NUMBER,
                site_id NUMBER, date_ouverture DATE, date_fermeture DATE,
                duree_resolution NUMBER
            );
            TYPE t_ticket_tab IS TABLE OF t_ticket_rec INDEX BY PLS_INTEGER;
            v_batch     t_ticket_tab;
            BATCH_SIZE  CONSTANT PLS_INTEGER := 500;
            v_batch_idx PLS_INTEGER := 1;
        BEGIN
            FOR i IN 1..v_nb_tickets LOOP
                -- Tirage aléatoire des FK via index dans les collections
                v_user_id    := v_all_users(PKG_GENERATOR.rand_int(
                                    1, v_all_users.COUNT));
                v_technicien := CASE WHEN v_techs.COUNT > 0
                                THEN v_techs(PKG_GENERATOR.rand_int(
                                    1, v_techs.COUNT))
                                ELSE NULL END;
                v_mat_id     := CASE WHEN PKG_GENERATOR.rand_int(1,100) <= 70
                                THEN v_all_mats(PKG_GENERATOR.rand_int(
                                    1, v_all_mats.COUNT))
                                ELSE NULL END;

                v_date_ouv  := PKG_GENERATOR.rand_date(
                                DATE '2022-01-01', SYSDATE - 1);

                -- 80% des tickets sont fermés (charge historique)
                IF PKG_GENERATOR.rand_int(1,100) <= 80 THEN
                    v_statut    := PKG_GENERATOR.pick(t_statuts_fermes);
                    v_duree_res := PKG_GENERATOR.rand_int(1, 72);  -- 1h à 3 jours
                    v_date_ferm := v_date_ouv +
                                   (v_duree_res / 24);
                ELSE
                    v_statut    := PKG_GENERATOR.pick(t_statuts_ouverts);
                    v_date_ferm := NULL;
                    v_duree_res := NULL;
                END IF;

                -- Site déduit de l'utilisateur
                SELECT id_site INTO v_site_id
                FROM   GLPI_UTILISATEURS WHERE id = v_user_id;

                -- Accumulation dans le batch
                v_batch(v_batch_idx).ticket_id       := SEQ_TICKET.NEXTVAL;
                v_batch(v_batch_idx).titre           :=
                    PKG_GENERATOR.pick(t_categories) || ' - ' ||
                    PKG_GENERATOR.gen_serial();
                v_batch(v_batch_idx).categorie       :=
                    PKG_GENERATOR.pick(t_categories);
                v_batch(v_batch_idx).priorite        :=
                    PKG_GENERATOR.pick(t_priorites);
                v_batch(v_batch_idx).statut          := v_statut;
                v_batch(v_batch_idx).user_id         := v_user_id;
                v_batch(v_batch_idx).technicien_id   := v_technicien;
                v_batch(v_batch_idx).mat_id          := v_mat_id;
                v_batch(v_batch_idx).site_id         := v_site_id;
                v_batch(v_batch_idx).date_ouverture  := v_date_ouv;
                v_batch(v_batch_idx).date_fermeture  := v_date_ferm;
                v_batch(v_batch_idx).duree_resolution:= v_duree_res;
                v_batch_idx := v_batch_idx + 1;

                -- Insertion par lot (FORALL) à chaque BATCH_SIZE tickets
                IF v_batch_idx > BATCH_SIZE OR i = v_nb_tickets THEN
                    FORALL j IN 1..v_batch_idx - 1
                        INSERT INTO GLPI_TICKETS (
                            id, TITRE, CATEGORIE, PRIORITE, STATUT,
                            id_utilisateur, TECHNICIEN_ID, id_materiel, id_site,
                            DATE_OUVERTURE, DATE_FERMETURE, DUREE_RESOLUTION_H
                        ) VALUES (
                            v_batch(j).ticket_id, v_batch(j).titre,
                            v_batch(j).categorie, v_batch(j).priorite,
                            v_batch(j).statut, v_batch(j).user_id,
                            v_batch(j).technicien_id, v_batch(j).mat_id,
                            v_batch(j).site_id,
                            v_batch(j).date_ouverture, v_batch(j).date_fermeture,
                            v_batch(j).duree_resolution
                        );
                    COMMIT;
                    PKG_GENERATOR.log('  Tickets : ' || i || '/' || v_nb_tickets);
                    v_batch.DELETE;
                    v_batch_idx := 1;
                END IF;
            END LOOP;
        END;

        PKG_GENERATOR.log('  Tickets OK : ' || v_nb_tickets || ' générés.');
    END gen_tickets_historique;


    -- =========================================================================
    -- 3.7  MAINTENANCE  (contrats et interventions)
    -- =========================================================================
    PROCEDURE gen_maintenance IS
        v_nb_contrats    NUMBER := PKG_GENERATOR.cfg('NB_CONTRATS');
        v_nb_interv      NUMBER := PKG_GENERATOR.cfg('NB_INTERVENTIONS');

        t_fournisseurs SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
            'Dell Technologies','HP Support','Lenovo Services',
            'Cisco SmartNet','IBM Support','Canon Care','Xerox Care',
            'MaintenancePro SARL','InfoSupport SAS','TechCare France');
        t_types_contrat SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
            'MAINTENANCE_PREVENTIVE','MAINTENANCE_CORRECTIVE',
            'GARANTIE_CONSTRUCTEUR','SUPPORT_LOGICIEL','LEASING');
        t_types_interv SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
            'REMPLACEMENT_PIECE','MISE_A_JOUR_FIRMWARE','NETTOYAGE',
            'DIAGNOSTIC','REMPLACEMENT_COMPLET','CONFIGURATION',
            'INVESTIGATION_PANNE','REINSTALLATION_OS');

        v_contrat_id NUMBER;
        v_mat_id     NUMBER;
        v_tech_id    NUMBER;
        v_date_deb   DATE;

        TYPE t_mat_ids IS TABLE OF NUMBER;
        TYPE t_tech_ids IS TABLE OF NUMBER;
        v_mats  t_mat_ids;
        v_techs t_tech_ids;
    BEGIN
        PKG_GENERATOR.log('=== Maintenance ===');

        -- Chargement des IDs
        SELECT id BULK COLLECT INTO v_mats FROM GLPI_MATERIELS;
        SELECT id BULK COLLECT INTO v_techs FROM GLPI_UTILISATEURS
        WHERE  id_role IN (1, 2);  -- 1=admin, 2=technicien

        -- Contrats
        FOR i IN 1..v_nb_contrats LOOP
            v_date_deb := PKG_GENERATOR.rand_date(DATE '2018-01-01', SYSDATE - 90);
            INSERT INTO GLPI_CONTRATS (
                id, REFERENCE, TYPE_CONTRAT, FOURNISSEUR,
                DATE_DEBUT, DATE_FIN, COUT_ANNUEL_HT,
                id_site, ACTIF, SLA_DELAI_H
            ) VALUES (
                SEQ_CONTRAT.NEXTVAL,
                    LPAD(i, 4, '0'),
                PKG_GENERATOR.pick(t_types_contrat),
                PKG_GENERATOR.pick(t_fournisseurs),
                v_date_deb,
                v_date_deb + PKG_GENERATOR.rand_int(365, 365*4),
                PKG_GENERATOR.rand_int(1000, 50000) * 10,
                PKG_GENERATOR.rand_int(1, 2),
                CASE WHEN PKG_GENERATOR.rand_int(1,10) <= 8 THEN 'O' ELSE 'N' END,
                PKG_GENERATOR.pick(SYS.ODCIVARCHAR2LIST('4','8','24','48','72'))
            );
        END LOOP;
        COMMIT;

        -- Interventions
        PKG_GENERATOR.log('  Génération des interventions...');
        DECLARE
            TYPE t_batch IS TABLE OF GLPI_INTERVENTIONS%ROWTYPE INDEX BY PLS_INTEGER;
            v_batch     t_batch;
            BATCH_SIZE  CONSTANT PLS_INTEGER := 200;
            v_idx       PLS_INTEGER := 1;
            v_row       GLPI_INTERVENTIONS%ROWTYPE;
            v_d         DATE;
        BEGIN
            FOR i IN 1..v_nb_interv LOOP
                v_d := PKG_GENERATOR.rand_date(DATE '2021-01-01', SYSDATE);

                v_row.INTERV_ID      := SEQ_INTERVENTION.NEXTVAL;
                v_row.id_materiel    := v_mats(PKG_GENERATOR.rand_int(
                                            1, v_mats.COUNT));
                v_row.TECHNICIEN_ID  := CASE WHEN v_techs.COUNT > 0
                                        THEN v_techs(PKG_GENERATOR.rand_int(
                                            1, v_techs.COUNT))
                                        ELSE NULL END;
                v_row.TYPE_INTERV    := PKG_GENERATOR.pick(t_types_interv);
                v_row.DATE_DEBUT     := v_d;
                v_row.DATE_FIN       := v_d + PKG_GENERATOR.rand_int(0,5) +
                                        PKG_GENERATOR.rand_int(1,8)/24;
                v_row.DUREE_HEURES   := ROUND(
                    (v_row.DATE_FIN - v_row.DATE_DEBUT) * 24, 2);
                v_row.RESULTAT       := PKG_GENERATOR.pick(SYS.ODCIVARCHAR2LIST(
                    'RESOLU','RESOLU','RESOLU','PARTIEL','EN_ATTENTE_PIECE'));
                v_row.CONTRAT_ID     :=
                    CASE WHEN PKG_GENERATOR.rand_int(1,100) <= 60
                    THEN (SELECT CONTRAT_ID FROM GLPI_CONTRATS
                          WHERE ROWNUM = 1 ORDER BY DBMS_RANDOM.VALUE)
                    ELSE NULL END;
                v_row.COUT_INTERVENTION :=
                    CASE WHEN PKG_GENERATOR.rand_int(1,10) <= 3
                    THEN PKG_GENERATOR.rand_int(50, 2000) * 5
                    ELSE 0 END;

                v_batch(v_idx) := v_row;
                v_idx := v_idx + 1;

                IF v_idx > BATCH_SIZE OR i = v_nb_interv THEN
                    FORALL j IN 1..v_idx - 1
                        INSERT INTO GLPI_INTERVENTIONS VALUES v_batch(j);
                    COMMIT;
                    v_batch.DELETE;
                    v_idx := 1;
                END IF;
            END LOOP;
        END;

        PKG_GENERATOR.log('  Maintenance OK.');
    END gen_maintenance;


    -- =========================================================================
    -- 3.8  RUN_ALL  (point d'entrée unique)
    -- =========================================================================
    PROCEDURE run_all IS
        v_debut TIMESTAMP := SYSTIMESTAMP;
        v_fin   TIMESTAMP;
        v_duree INTERVAL DAY TO SECOND;
    BEGIN
        DBMS_OUTPUT.ENABLE(1000000);
        PKG_GENERATOR.log('========================================');
        PKG_GENERATOR.log('DÉMARRAGE GÉNÉRATION – GLPI CY Tech');
        PKG_GENERATOR.log('========================================');

        DBMS_RANDOM.SEED(PKG_GENERATOR.cfg('SEED_ALEATOIRE'));

        gen_roles_permissions;    -- Role, Permission, RolePermission 
        gen_entites_base;
        gen_utilisateurs;
        gen_reseaux;
        gen_materiels;
        gen_affectations;
        gen_tickets_historique;
        gen_maintenance;

        v_fin   := SYSTIMESTAMP;
        v_duree := v_fin - v_debut;

        PKG_GENERATOR.log('========================================');
        PKG_GENERATOR.log('GÉNÉRATION TERMINÉE');
        PKG_GENERATOR.log('Durée totale : ' ||
            EXTRACT(MINUTE FROM v_duree) || 'm ' ||
            ROUND(EXTRACT(SECOND FROM v_duree)) || 's');
        PKG_GENERATOR.log('========================================');
    END run_all;

END PKG_DATA_GEN;
/


-- =============================================================================
-- 4. SCRIPT D'EXÉCUTION PRINCIPAL
-- =============================================================================

-- Activation de la sortie console
SET SERVEROUTPUT ON SIZE UNLIMITED

-- Lancement de la génération complète
BEGIN
    PKG_DATA_GEN.run_all;
END;
/


-- =============================================================================
-- 5. VÉRIFICATIONS POST-GÉNÉRATION
--   Résumé des comptages par table pour valider la cohérence du jeu de données
-- =============================================================================

BEGIN
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE('VÉRIFICATION POST-GÉNÉRATION – COMPTAGES FINAUX');
    DBMS_OUTPUT.PUT_LINE('============================================================');
END;
/

SELECT 'GLPI_SITES'          AS TABLE_NAME, COUNT(*) AS NB_LIGNES FROM GLPI_SITES
UNION ALL
SELECT 'GLPI_DEPARTEMENTS',   COUNT(*) FROM GLPI_DEPARTEMENTS
UNION ALL
SELECT 'GLPI_BATIMENTS',      COUNT(*) FROM GLPI_BATIMENTS
UNION ALL
SELECT 'GLPI_SALLES',         COUNT(*) FROM GLPI_SALLES
UNION ALL
SELECT 'GLPI_UTILISATEURS',   COUNT(*) FROM GLPI_UTILISATEURS
UNION ALL
SELECT 'Role',                 COUNT(*) FROM Role
UNION ALL
SELECT 'Permission',           COUNT(*) FROM Permission
UNION ALL
SELECT 'RolePermission',       COUNT(*) FROM RolePermission
UNION ALL
SELECT 'GLPI_VLANS',          COUNT(*) FROM GLPI_VLANS
UNION ALL
SELECT 'GLPI_SOUS_RESEAUX',   COUNT(*) FROM GLPI_SOUS_RESEAUX
UNION ALL
SELECT 'GLPI_MATERIELS',      COUNT(*) FROM GLPI_MATERIELS
UNION ALL
SELECT 'GLPI_AFFECTATIONS',   COUNT(*) FROM GLPI_AFFECTATIONS
UNION ALL
SELECT 'GLPI_MAT_SALLES',     COUNT(*) FROM GLPI_MAT_SALLES
UNION ALL
SELECT 'GLPI_TICKETS',        COUNT(*) FROM GLPI_TICKETS
UNION ALL
SELECT 'GLPI_CONTRATS',       COUNT(*) FROM GLPI_CONTRATS
UNION ALL
SELECT 'GLPI_INTERVENTIONS',  COUNT(*) FROM GLPI_INTERVENTIONS
ORDER BY 1;

BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('--- Répartition matériels par type et site ---');
END;
/
SELECT
    TYPE_MATERIEL,
    SUM(CASE WHEN SITE_ID = 1 THEN 1 ELSE 0 END) AS CERGY,
    SUM(CASE WHEN SITE_ID = 2 THEN 1 ELSE 0 END) AS PAU,
    COUNT(*) AS TOTAL
FROM GLPI_MATERIELS
GROUP BY TYPE_MATERIEL
ORDER BY TOTAL DESC;

BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('--- Répartition utilisateurs par rôle et site ---');
END;
/
SELECT
    r.nom AS ROLE,
    SUM(CASE WHEN u.id_site = 1 THEN 1 ELSE 0 END) AS CERGY,
    SUM(CASE WHEN u.id_site = 2 THEN 1 ELSE 0 END) AS PAU,
    COUNT(*) AS TOTAL
FROM GLPI_UTILISATEURS u
JOIN Role r ON r.id = u.id_role
GROUP BY r.nom
ORDER BY TOTAL DESC;

BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('--- Tickets par statut et priorité ---');
END;
/
SELECT STATUT, PRIORITE, COUNT(*) AS NB_TICKETS
FROM   GLPI_TICKETS
GROUP  BY STATUT, PRIORITE
ORDER  BY STATUT, NB_TICKETS DESC;

BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE("--- Taux d'affectation des matériels ---");
END;
/
SELECT
    ROUND(
        COUNT(DISTINCT a.id_materiel) * 100.0 /
        NULLIF((SELECT COUNT(*) FROM GLPI_MATERIELS WHERE ETAT='EN_SERVICE'),0),
    2) AS PCT_AFFECTES,
    COUNT(DISTINCT a.id_materiel) AS NB_AFFECTES,
    (SELECT COUNT(*) FROM GLPI_MATERIELS WHERE ETAT='EN_SERVICE') AS NB_TOTAL
FROM GLPI_AFFECTATIONS a
WHERE a.DATE_FIN IS NULL;

BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('--- Temps de résolution moyen par catégorie de ticket (benchmark) ---');
END;
/
SELECT
    CATEGORIE,
    COUNT(*)                              AS NB_TICKETS,
    ROUND(AVG(DUREE_RESOLUTION_H), 2)    AS MOY_HEURES,
    MIN(DUREE_RESOLUTION_H)              AS MIN_H,
    MAX(DUREE_RESOLUTION_H)              AS MAX_H
FROM GLPI_TICKETS
WHERE STATUT IN ('RESOLU','FERME','CLOS')
AND   DUREE_RESOLUTION_H IS NOT NULL
GROUP BY CATEGORIE
ORDER BY MOY_HEURES DESC;

BEGIN
    DBMS_OUTPUT.PUT_LINE('============================================================');
    DBMS_OUTPUT.PUT_LINE('FIN DES VÉRIFICATIONS');
    DBMS_OUTPUT.PUT_LINE('============================================================');
END;
/