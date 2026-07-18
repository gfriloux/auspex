# CLAUDE.md

Guidage pour Claude Code (claude.ai/code) dans ce dépôt.

> **Avant tout travail sur le code, lire [`DESIGN.md`](./DESIGN.md) puis
> [`PROCEDURE_PLANS.md`](./PROCEDURE_PLANS.md). On ne code pas sans plan validé.**

## Ce qu'est auspex

Widget de supervision Zabbix pour **Quickshell / DankMaterialShell** : badge d'état
dans la barre (compteur de problèmes + couleur de la sévérité la plus haute) + popup
cockpit listant les problèmes actifs, avec notification à l'apparition d'un nouveau
problème. Données via l'**API JSON-RPC de Zabbix 7.0** (HTTP, **lecture seule** en v1,
polling). Aucune configuration côté serveur Zabbix. Un *Nagstamon* repensé en plugin DMS
natif, orienté Zabbix. Détails et invariants : `DESIGN.md`.

## Pile & structure

- **Vue** : QML / Qt Quick (Quickshell), Material 3, Catppuccin Mocha.
- **Données** : couche `query` (construit les corps JSON-RPC, purs) → service `Zabbix.qml`
  (exécute le HTTP + header `Authorization: Bearer`) → `model` (modèle de problèmes,
  pur/testable) → `view` (QML). Le QML ne **construit** jamais de requête en direct.

```
src/            ← QML Quickshell + couches query/model
tests/          ← fixtures API Zabbix (JSON figé) + goldens (modèle attendu)
.claude/plans/  ← plans de version (plan.md, manual_tests.md, phase0_results.md)
tmp/            ← scratch non commité (handoff design, notes)
```

## Dev environment

Toujours entrer le dev shell Nix avant de builder/tester :

```bash
nix develop
```

Pour les commandes non interactives : `nix develop --command just ci`.

## Commandes

```bash
just ci          # porte complète : fmt-check + lint + test
just fmt         # qmlformat -i (formate en place)
just fmt-check   # vérifie le format, échoue si non conforme
just lint        # qmllint, aucun warning toléré
just test        # golden (API figée → modèle) + Qt Quick Test
just run         # lance le widget dans Quickshell (essai manuel)
just bless       # régénère les goldens (relire le diff)
```

Le `Justfile` est la **seule** définition des gates ; pre-commit et la CI l'appellent.

## Garde-fous (ce qui ne change pas)

- **DESIGN.md fait foi.** Hors invariants → non. API Zabbix source de vérité,
  **lecture seule (v1)**, auth **Bearer** + utilisateur read-only, **le problème est
  l'unité**, **agnostique à l'instance** (une instance = une facette : URL + token) :
  invariants durs. Passer en écriture (ack/close) = décision DESIGN explicite + PLAN dédié,
  pas un ajout discret.
- **Le token est un secret.** Il vit dans la config / le service `Zabbix.qml`, **jamais**
  dans les couches `query`/`model`, **jamais** dans une fixture ou un golden commité.
- **Git : hybride.** Claude travaille sur une **branche dédiée**, commite **atomiquement**
  (Conventional Commits, cf. PROCEDURE_PLANS.md §3), et ne fait **jamais** `merge`/`push`/`tag`.
  L'utilisateur relit, merge sur `main`, push.
- **Doc dans le même commit** que le code qu'elle décrit.
- **`tmp/`** : jamais commité.
- **Couche données déterministe** : tout changement de `query`/`model` passe par une
  fixture + un golden (cf. PROCEDURE_PLANS.md §4).
- **Outillage release** (renovate, git-cliff, CI + workflow release) : **en place depuis
  v0.3.0**. Le process de release est dans `README.md` ; le tag reste posé par l'utilisateur.
