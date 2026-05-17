-- =====================================================================
-- FICHIER  : packages_metier.sql
-- OBJET    : Packages, Procédures stockées et Curseurs
-- =====================================================================

-- -----------------------------------------------------------------
-- 1. SPECIFICATION DU PACKAGE
-- -----------------------------------------------------------------
CREATE OR REPLACE PACKAGE PKG_GLPI_METIER AS
    PROCEDURE declarer_incident(p_id_utilisateur IN NUMBER, p_id_materiel IN NUMBER, p_desc IN CLOB);
    PROCEDURE cloturer_ticket(p_id_ticket IN NUMBER, p_id_technicien IN NUMBER);
    PROCEDURE audit_materiel_site(p_id_site IN NUMBER);
    FUNCTION fn_est_disponible(p_id_materiel IN NUMBER) RETURN NUMBER;
END PKG_GLPI_METIER;
/

-- -----------------------------------------------------------------
-- 2. CORPS DU PACKAGE (BODY)
-- -----------------------------------------------------------------
CREATE OR REPLACE PACKAGE BODY PKG_GLPI_METIER AS

    -- Procédure pour qu'un utilisateur déclare une panne
    PROCEDURE declarer_incident(p_id_utilisateur IN NUMBER, p_id_materiel IN NUMBER, p_desc IN CLOB) IS
    BEGIN
        -- Insertion du ticket (le trigger dans tables.sql gérera l'ID avec la séquence)
        INSERT INTO Ticket (id_utilisateur, id_materiel, description, statut, date_creation)
        VALUES (p_id_utilisateur, p_id_materiel, p_desc, 'ouvert', SYSTIMESTAMP);
        
        -- On passe le matériel en maintenance
        UPDATE Materiel SET statut = 'maintenance' WHERE id = p_id_materiel;
        
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('Erreur lors de la déclaration de l''incident : ' || SQLERRM);
    END declarer_incident;

    -- Procédure pour qu'un technicien clôture un ticket
    PROCEDURE cloturer_ticket(p_id_ticket IN NUMBER, p_id_technicien IN NUMBER) IS
        v_id_materiel Ticket.id_materiel%TYPE;
    BEGIN
        -- Mettre à jour le ticket et récupérer l'ID du matériel concerné
        UPDATE Ticket 
        SET statut = 'resolu', id_technicien = p_id_technicien
        WHERE id = p_id_ticket 
        RETURNING id_materiel INTO v_id_materiel;
        
        -- Remettre le matériel en état disponible
        UPDATE Materiel SET statut = 'disponible' WHERE id = v_id_materiel;
        
        COMMIT;
    END cloturer_ticket;

    -- Procédure d'audit avec un curseur
    PROCEDURE audit_materiel_site(p_id_site IN NUMBER) IS
        -- Curseur pour lister tout le matériel en maintenance d'un site
        CURSOR cur_materiel_panne IS
            SELECT m.nom, m.numero_serie, m.type, s.nom as nom_site
            FROM Materiel m
            JOIN Site s ON m.id_site = s.id
            WHERE m.statut = 'maintenance' AND m.id_site = p_id_site;
            
        v_nb_pannes NUMBER := 0;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('--- AUDIT DU MATERIEL EN MAINTENANCE ---');
        
        -- Parcours du curseur avec une boucle FOR
        FOR rec IN cur_materiel_panne LOOP
            DBMS_OUTPUT.PUT_LINE('Equipement: ' || rec.nom || ' (Type: ' || rec.type || ', S/N: ' || rec.numero_serie || ')');
            v_nb_pannes := v_nb_pannes + 1;
        END LOOP;
        
        DBMS_OUTPUT.PUT_LINE('Total des équipements en panne sur ce site : ' || v_nb_pannes);
    END audit_materiel_site;

    FUNCTION fn_est_disponible(p_id_materiel IN NUMBER) RETURN NUMBER IS
        v_statut Materiel.statut%TYPE;
    BEGIN
        SELECT statut INTO v_statut FROM Materiel WHERE id = p_id_materiel;
        RETURN CASE WHEN v_statut = 'disponible' THEN 1 ELSE 0 END;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN 0;
    END fn_est_disponible;

END PKG_GLPI_METIER;
/