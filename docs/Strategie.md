# Stratégie de répartition des données (BDDR)

Ce document détaille la stratégie de distribution de la base de données pour la gestion du parc informatique entre les sites de **Cergy** et **Pau**.

## Introduction
Dans le contexte de la gestion de données à grande échelle, il est crucial de mettre en
place une stratégie efficace de distribution et de réplication des données. Cette stratégie permet d'assurer la disponibilité, la performance et la résilience des systèmes de gestion de données.

## Objectif
L'objectif de cette stratégie est de définir les meilleures pratiques pour la distribution et la réplication des données, en tenant compte des besoins spécifiques de l'organisation, des contraintes techniques et des exigences de sécurité.

## 1. Architecture technique
Nous utilisons une architecture distribuée simulée par trois schémas Oracle distincts :
- `cyglpi_hub` : schéma concentrateur (point d'accès global);
- `cergy_site` : site de Cergy ;
- `pau_site` : site de Pau.

Les échanges entre ces schémas sont réalisés via des **Database Links (DB Links)**.

## 2. Stratégie de répartition des données

### A. Tables fragmentées horizontalement

Certaines tables sont réparties horizontalement entre les sites.  
Chaque site ne stocke que ses propres données, filtrées via `id_site`.
En effet les données doivent être stockées au plus proche de leur utilisation quotidienne.

Tables concernées :

- `Utilisateur`
- `Affectation`
- `Batiment`
- `Salle`
- `Reseau`
- `EquipementReseau`
- `Materiel`
- `Ticket`

#### Utilisateur et Affectation

Chaque site gère principalement ses propres utilisateurs et affectations.

Un utilisateur de Cergy n’a pratiquement jamais besoin de consulter les agents de Pau dans les opérations courantes.  
Conserver les données localement permet donc :

- des connexions plus rapides ;
- des requêtes locales sans passage réseau ;
- une réduction de charge sur le schéma central.

Exemple de requête locale :

```sql
SELECT *
FROM Utilisateur
WHERE id_site = 1;
```

Sans fragmentation, cette requête nécessiterait systématiquement un accès distant.

#### Batiment, Salle, Reseau et EquipementReseau

Ces tables représentent l’infrastructure physique du site.
La topologie réseau ou les salles de Pau n’ont aucun intérêt opérationnel pour les techniciens de Cergy, et inversement.
La fragmentation permet donc :

- des diagnostics réseau entièrement locaux ;
- une meilleure réactivité ;
- une isolation logique des infrastructures.

#### Materiel
Le matériel est également spécifique à chaque site.
Les techniciens de Pau n’ont pas besoin de connaître le matériel de Cergy pour leurs interventions quotidiennes.
En cas de transfert d’un matériel d’un site vers un autre, la donnée sera déplacée vers le schéma du nouveau site.

La fragmentation de cette table permet :
- une gestion locale du matériel ;
- une meilleure performance des requêtes ;
- une réduction de la charge sur le schéma central.

#### Ticket
Les tickets d’incidents sont généralement liés à des équipements ou des utilisateurs spécifiques à un site.
Il est donc logique de les stocker localement pour chaque site.
Les tickets inter-sites restent possibles grâce aux vues consolidées et aux DB Links.

Cela permet :
- une gestion plus rapide des tickets ;
- une meilleure performance des requêtes ;
- une réduction de la charge sur le schéma central.

### B. Tables répliquées
Certaines tables sont répliquées en lecture seule sur les trois sites.

Tables concernées :
- `Site`
- `Role`
- `Permission`
- `RolePermission`

#### Choix de répliquer ces tables
Ces tables contiennent des données de référence utilisées par tous les sites. Elles changent rarement et sont essentielles pour les opérations quotidiennes.
Par exemple, la table `Site` contient les informations sur les différents sites, et est nécessaire pour les opérations de tous les sites.  
La table `Role` définit les rôles d’utilisateur, tandis que `Permission` et `RolePermission` définissent les permissions associées à ces rôles.  
Elles peuvent être utilisées pour la vérification des permissions, l'authentification utilisateur ou pour le contrôle des rôles.

Les répliquer localement évite :

- des accès réseau constants ;
- une surcharge du schéma central ;
- un point de congestion sur cyglpi;
- une meilleure performance des requêtes.

La réplication garantit donc des lectures rapides tout en conservant une cohérence globale.

## 3. Mécanismes de Transparence et de cohérence

Pour que l'utilisateur ou l'administrateur puisse voir l'ensemble du parc informatique sans se soucier de la localisation, nous mettons en place :

1. **Des Vues Globales (UNION ALL)** dans le schéma `CYGLPI_HUB`.
2. **Des Synonymes** pour masquer l'usage des `@DB_LINK` dans les requêtes applicatives.

### A. Utilisation des DB Links Oracle

Dans Oracle, la communication entre schémas distribués est réalisée via des `DATABASE LINK`.

Même dans une seule instance Docker, les DB Links permettent de simuler une architecture distribuée entre plusieurs sites.

### B. Vues consolidées

Pour faciliter l’accès aux données réparties, des vues consolidées sont créées dans le schéma central `cyglpi`.  
Ces vues agrègent les données des différents sites en utilisant les DB Links.

## Conclusion

La stratégie retenue repose sur un principe directeur :

- La donnée doit être stockée là où elle est principalement produite et consommée.

Les données opérationnelles sont fragmentées horizontalement afin de privilégier les performances locales et réduire les échanges réseau.

Les référentiels communs sont répliqués afin de garantir des accès rapides sans dépendance permanente au schéma central.

Cette architecture permet d’obtenir un système distribué cohérent, performant et évolutif.