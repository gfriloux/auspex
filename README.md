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

**v0.2.0 — service + badge + home-manager.** auspex est **installable et utilisable** :
un service poll une vraie instance Zabbix 7.0 (HTTP via curl), un **badge de barre**
affiche l'état (compteur + couleur de la pire sévérité), un **popout liste** montre les
problèmes actifs, et les réglages (URL / token / intervalle) vivent dans DMS.

Reste à venir : **cockpit complet direction C** (télémétrie, barre de résumé, filtres,
états soignés) en v0.3.0, et **notifications desktop** sur nouveau problème en v0.4.0.
Fondations, invariants et direction visuelle : `DESIGN.md`.

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
src/view/Zabbix.qml      ← service : poll HTTP (curl/Process) → modèle
src/view/AuspexWidget.qml← badge de barre + popout liste (PluginComponent)
src/view/Settings.qml    ← réglages (URL, token, intervalle, TLS)
tests/                   ← fixtures API figées + goldens (modèle attendu)
.claude/plans/           ← plans de version (plan.md, manual_tests.md, phase0_results.md)
```

## Installation

Via home-manager, en tant que plugin DankMaterialShell :

```nix
# flake.nix (inputs)
inputs.auspex.url = "github:gfriloux/auspex";

# config home-manager
imports = [inputs.auspex.homeModules.default];
programs.auspex.enable = true;
```

Puis, dans DMS : **Settings → Plugins → Auspex** pour activer le widget, et son panneau de
réglages pour renseigner l'URL et le token.

## Configuration (côté Zabbix)

1. Créer un **utilisateur Zabbix en rôle lecture seule** (aucun droit d'écriture).
2. Lui générer un **API token** (Users → API tokens).
3. Dans les réglages du plugin : renseigner l'**URL** de l'endpoint JSON-RPC
   (`https://<zabbix>/api_jsonrpc.php`), coller le **token**, régler l'**intervalle** de
   poll. Cocher « Certificat TLS non vérifié » seulement si l'instance a un certif
   auto-signé.

auspex est **lecture seule** : le token n'a besoin d'aucun droit d'écriture. Il est envoyé
en header `Authorization: Bearer` via un fichier de config curl sous `$XDG_RUNTIME_DIR`
(jamais en ligne de commande).

## Licence

Voir [`LICENSE`](./LICENSE).
