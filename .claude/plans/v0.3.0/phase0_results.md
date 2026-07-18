# Phase 0 — Audit du dépôt avant v0.3.0

**Date :** 2026-07-18
**Branche :** `feat/v0.3.0-cockpit` (créée depuis `main` @ `95a3585`)

## `nix develop --command just ci`

- **fmt-check** : ✅ aucun fichier non formaté.
- **lint** (`qmllint`) : ✅ **exit 0**. 209 « Warning » émis, **tous** des résolutions
  d'import Quickshell / `qs.*` / `QtQuick*` que qmllint ne trouve pas dans le dev shell
  (types `PluginComponent`, `DankIcon`, `StyledText`, `Process`… non résolus → cascade de
  `Unqualified access` / `unresolved-type`). C'est le piège qmllint connu : la porte est le
  **code retour** de qmllint (0), pas la présence de warnings d'import inévitables hors
  runtime Quickshell. Aucun warning « réel » (logique QML) à traiter.
- **test** : ✅ 22 passed, 0 failed (golden + model + queries), 54 ms.

## Conclusion

Dépôt propre, portes vertes. Rien à nettoyer avant de commencer. La couche `query`/`model`
n'est **pas** touchée par v0.3.0 (cockpit = étage `view`) : les goldens restent figés.
