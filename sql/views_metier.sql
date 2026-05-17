-- Vues métier — accès simplifié (inventaire, parc, réseau, tickets)
CREATE OR REPLACE VIEW V_INVENTAIRE_SITE AS
SELECT s.id          AS id_site,
       s.nom         AS site,
       s.ville,
       m.id          AS id_materiel,
       m.nom         AS materiel,
       m.type        AS type_materiel,
       m.numero_serie,
       m.statut,
       u.nom         AS utilisateur_affecte,
       a.date_debut  AS date_affectation
FROM   Materiel m
JOIN   Site s ON s.id = m.id_site
LEFT JOIN Affectation a ON a.id_materiel = m.id AND a.date_fin IS NULL
LEFT JOIN Utilisateur u ON u.id = a.id_utilisateur;

CREATE OR REPLACE VIEW V_ETAT_MATERIEL AS
SELECT m.id_site,
       s.nom AS site,
       m.statut,
       m.type AS type_materiel,
       COUNT(*) AS nombre
FROM   Materiel m
JOIN   Site s ON s.id = m.id_site
GROUP BY m.id_site, s.nom, m.statut, m.type;

CREATE OR REPLACE VIEW V_INVENTAIRE_RESEAU_SITE AS
SELECT s.nom AS site,
       r.ip_range,
       r.wan,
       r.vlan,
       e.nom AS equipement,
       e.type AS type_equipement
FROM   Reseau r
JOIN   Site s ON s.id = r.id_site
LEFT JOIN EquipementReseau e ON e.id_reseau = r.id;

CREATE OR REPLACE VIEW V_TICKETS_OUVERTS AS
SELECT t.id,
       t.statut,
       t.priorite,
       t.date_creation,
       u.nom  AS demandeur,
       tech.nom AS technicien,
       m.nom  AS materiel,
       s.nom  AS site
FROM   Ticket t
JOIN   Utilisateur u ON u.id = t.id_utilisateur
JOIN   Materiel m ON m.id = t.id_materiel
JOIN   Site s ON s.id = m.id_site
LEFT JOIN Utilisateur tech ON tech.id = t.id_technicien
WHERE  t.statut NOT IN ('ferme', 'resolu', 'clos');

CREATE OR REPLACE VIEW V_DROITS_ROLE AS
SELECT r.nom AS role,
       p.nom AS permission,
       p.description
FROM   Role r
JOIN   RolePermission rp ON rp.id_role = r.id
JOIN   Permission p ON p.id = rp.id_permission;
