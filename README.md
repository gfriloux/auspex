# auspex

Widget de **supervision Zabbix** pour la barre de bureau **Quickshell /
DankMaterialShell**. Un badge d'état dans la barre (compteur de problèmes + couleur de la
sévérité la plus haute) et un popup *cockpit* listant les problèmes actifs ; auspex
**notifie** à l'apparition d'un nouveau problème.

Un [Nagstamon](https://nagstamon.de/) repensé en plugin DMS natif, **orienté Zabbix 7.0**.
Données via l'**API JSON-RPC** (HTTP, **lecture seule**, polling) — **rien à installer
côté serveur**, un simple accès API en lecture suffit.

Esprit et invariants : [`DESIGN.md`](./DESIGN.md). Méthode de travail :
[`PROCEDURE_PLANS.md`](./PROCEDURE_PLANS.md) et [`CLAUDE.md`](./CLAUDE.md).

## Pile

- **Vue** : QML / Qt Quick (Quickshell), Material 3, Catppuccin Mocha.
- **Données** : `query` (corps JSON-RPC, purs) → service `Zabbix.qml` (HTTP + header
  `Authorization: Bearer`) → `model` (problèmes, pur/testable) → `view` (QML).
- **Auth** : API token Zabbix rattaché à un utilisateur **read-only** (le token vit dans
  la config/le service, jamais dans les couches données ni les tests).

## État

**v0.1.0 — couche données.** Le socle déterministe et golden-testé est en place :
construction des requêtes, parsing/normalisation, jointure problème→host, sévérité
globale, compteurs et **delta** (nouveaux / résolus). **Pas encore d'UI ni de HTTP réel**
— c'est l'objet de v0.2.0 (badge + cockpit, notifications, packaging home-manager),
précédé d'un *handoff design* (cf. `DESIGN.md`).

## Développement

Toujours entrer le dev shell Nix (fournit quickshell, qmllint/qmlformat/qmltestrunner,
just) :

```bash
nix develop
just ci        # porte complète : fmt-check + lint + test
```

Autres cibles : `just test` (golden + Qt Quick Test), `just fmt` (formate le QML),
`just bless` (régénère les goldens — relire le diff). Le `Justfile` est la **seule**
définition des portes de qualité ; pre-commit et la CI l'appellent.

## Structure du code

```
src/query/queries.js     ← builders de corps JSON-RPC (problem.get, trigger.get)
src/model/problems.js    ← parsing, jointure host, agrégats, delta (pur, golden-testé)
src/model/format.js      ← helpers de présentation (severityLabel, relativeTime)
src/view/                ← QML Quickshell (badge, cockpit) — v0.2.0
tests/                   ← fixtures API figées + goldens (modèle attendu)
.claude/plans/           ← plans de version (plan.md, manual_tests.md, phase0_results.md)
```

## Installation

Via home-manager, en tant que plugin DankMaterialShell — **disponible en v0.2.0**, avec
la surface QML.

## Licence

Voir [`LICENSE`](./LICENSE).
