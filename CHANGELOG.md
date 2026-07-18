# Changelog

Toutes les évolutions notables d'auspex. Format inspiré de [Keep a Changelog],
versions en [SemVer]. Généré depuis les Conventional Commits par git-cliff.

[Keep a Changelog]: https://keepachangelog.com/fr/1.1.0/
[SemVer]: https://semver.org/lang/fr/

## [0.3.0] - 2026-07-18

### Fonctionnalités

- **view** : Pied de cadence du cockpit
- **view** : États chargement, erreur et unauthorized du cockpit
- **view** : Enrichir les lignes de problème (point, halo, icônes d'état)
- **view** : Légende de sévérité cliquable (filtre côté vue)
- **view** : Barre de résumé segmentée par sévérité
- **view** : En-tête télémétrie du cockpit
- **view** : Colonne host auto-ajustée au nom le plus long
- **view** : Colonnes host et description à largeur fixe (tableau aligné)
- **view** : Colonnes sévérité/âge alignées et premier poll immédiat
- **view** : Élargir le popout pour hôtes et descriptions longs
- **nix** : Module home-manager et packaging plugin
- **view** : Réglages (URL, token, intervalle, TLS)
- **view** : Badge de barre et liste minimale
- **view** : Service de poll Zabbix (curl/Process)
- **model** : Helpers severityColor et rpcError
- **model** : Sévérité globale, compteurs et delta
- **model** : Parsing et jointure problème→host
- **query** : Builders problem.get et trigger.get

### Corrections

- **view** : Supprimer le binding loop sur hostColWidth
- **view** : Poll curl fiable et popout dimensionné

### Refactorisations

- **view** : Extraire le cockpit dans son propre composant

### Documentation

- Plan outillage release (premier tag v0.3.0)
- Cockpit direction C livré (v0.3.0)
- Plan v0.3.0 (cockpit direction C)
- Installation home-manager et usage v0.2.0
- Figer la direction visuelle C (cockpit / radar)
- Documenter la couche données v0.1.0
- DESIGN, CLAUDE, PROCEDURE_PLANS et plan v0.1.0

### Tests

- Harnais golden (fixtures API -> modèle attendu)

### Divers

- Aligner plugin.json sur la version 0.3.0
- Noms d'hôtes longs dans le mock (preview d'alignement réaliste)
- Outils de dev — mock API Zabbix et barre isolée
- **nix** : Scaffold dev shell, Justfile et manifest plugin

<!-- généré par git-cliff -->
