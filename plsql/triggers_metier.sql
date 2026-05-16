-- =====================================================================
-- FICHIER  : triggers_metier.sql
-- OBJET    : Triggers de cohérence et d'intégrité métier
-- =====================================================================

-- TRIGGER 1 : Vérifier qu'on n'affecte pas un matériel non disponible
CREATE OR REPLACE TRIGGER trg_check_dispo_materiel
BEFORE INSERT ON Affectation
FOR EACH ROW
DECLARE
    v_statut Materiel.statut%TYPE;
BEGIN
    -- Récupération du statut du matériel ciblé
    SELECT statut INTO v_statut FROM Materiel WHERE id = :NEW.id_materiel;
    
    IF v_statut != 'disponible' THEN
        -- Levée d'une exception métier
        RAISE_APPLICATION_ERROR(-20001, 'Erreur Métier: Le matériel n''est pas disponible.');
    END IF;
END;
/

-- TRIGGER 2 : Mettre à jour automatiquement le statut du matériel
CREATE OR REPLACE TRIGGER trg_maj_statut_materiel
AFTER INSERT OR UPDATE ON Affectation
FOR EACH ROW
BEGIN
    -- Si c'est une nouvelle affectation (ou une mise à jour sans date de fin)
    IF :NEW.date_fin IS NULL THEN
        UPDATE Materiel SET statut = 'affecte' WHERE id = :NEW.id_materiel;
    -- Si l'affectation est terminée (date_fin précisée)
    ELSE
        UPDATE Materiel SET statut = 'disponible' WHERE id = :NEW.id_materiel;
    END IF;
END;
/

-- TRIGGER 3 : Empêcher la modification d'un ticket 'ferme'
CREATE OR REPLACE TRIGGER trg_verif_ticket_ferme
BEFORE UPDATE ON Ticket
FOR EACH ROW
BEGIN
    -- Si le ticket était déjà fermé, on bloque toute modification
    IF :OLD.statut IN ('ferme', 'resolu', 'clos') THEN
        RAISE_APPLICATION_ERROR(-20002, 'Erreur Métier: Impossible de modifier un ticket déjà clôturé.');
    END IF;
END;
/