# Sécurité BDD et Automatisation PL/SQL


Cette section détaille les choix techniques réalisés pour garantir l'intégrité des données, automatiser les processus métiers de la gestion de parc (GLPI) et appliquer une gouvernance stricte des accès. Ces choix s'appuient sur les concepts avancés d'Oracle vus en cours.

## 1. Gouvernance des accès
Afin de respecter le principe du moindre privilège, la sécurité a été implémentée au niveau de la base de données via la création de rôles Oracle spécifiques, mappés sur notre modélisation métier.

* **`ROLE_UTILISATEUR`** : Possède uniquement les droits de lecture (`SELECT`) sur le catalogue matériel et ses propres affectations. Il dispose du droit d'insertion (`INSERT`) sur la table `Ticket` pour déclarer un incident.
* **`ROLE_TECHNICIEN`** : Dispose de droits étendus (`SELECT`, `INSERT`, `UPDATE`) sur les tables `Materiel`, `Affectation` et `Ticket` afin de gérer le parc au quotidien, résoudre les incidents et réaffecter le matériel.
* **`ROLE_ADMIN`** : Possède les droits totaux sur l'ensemble du périmètre de l'application (Sites, Réseaux, Utilisateurs, Permissions).

## 2. Intégrité Métier : Les Triggers
Pour garantir la cohérence des données de manière transparente, trois triggers ont été implémentés :

1. **`trg_check_dispo_materiel` (`BEFORE INSERT ON Affectation`) :** Vérifie dynamiquement le statut du matériel. Si un équipement n'est pas "disponible", une exception métier (`RAISE_APPLICATION_ERROR : ORA-20001`) bloque l'affectation.
2. **`trg_maj_statut_materiel` (`AFTER INSERT OR UPDATE ON Affectation`) :**
   Automatise le cycle de vie du matériel. Lors d'une nouvelle affectation, le statut du matériel passe à "affecte". Si une date de fin est renseignée, il repasse automatiquement à "disponible".
3. **`trg_verif_ticket_ferme` (`BEFORE UPDATE ON Ticket`) :**
   Agit comme une barrière en bloquant la modification d'un ticket dont le statut est déjà résolu ou fermé (`RAISE_APPLICATION_ERROR : ORA-20002`).

## 3. Encapsulation de la logique métier : Package PL/SQL
Pour faciliter l'interaction avec la base et optimiser les performances, les actions métiers récurrentes ont été regroupées dans le package `PKG_GLPI_METIER`. Remarque : La gestion de l'auto-incrémentation des clés primaires a été déléguée aux séquences et triggers de la structure physique (tables.sql).

* **`declarer_incident`** : Procédure transactionnelle qui génère un ticket d'incident et passe simultanément le matériel concerné en statut "maintenance".
* **`cloturer_ticket`** : Procédure qui résout un incident, met à jour l'identifiant du technicien, et remet automatiquement l'équipement en disponibilité.
* **`audit_materiel_site`** : Procédure d'administration utilisant un curseur. Elle permet de parcourir via une boucle d'extraction et d'afficher efficacement la liste détaillée de tous les équipements actuellement en panne pour un site donné.
* **`fn_est_disponible`** : Fonction retournant 1 si le matériel est `disponible`, 0 sinon.

Les vues métier (`sql/views_metier.sql`) sont accessibles selon le rôle via `sql/security_roles_users.sql`.