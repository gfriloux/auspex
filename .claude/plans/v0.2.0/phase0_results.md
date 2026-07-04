# Phase 0 — Résultats de l'audit (v0.2.0)

**Date :** 2026-07-04
**Branche :** `feat/v0.2.0-surface` (part de `main` post-merge v0.1.0 + gel direction C)

## Commande

```bash
nix develop --command just ci
```

## Résultat

`just ci` **vert** : fmt-check + lint OK, **20 tests passés** (golden + inline
queries/model). Baseline saine.

## État avant travail

- Couche données v0.1.0 en place (`src/query/queries.js`, `src/model/{problems,format}.js`,
  goldens).
- `DESIGN.md` contient la direction visuelle C figée.
- Aucun QML de vue (`src/view/` absent), pas de `nix/hm-module.nix`, pas de `curl` au dev shell.

## Conclusion

Rien à défaire. Feu vert pour l'étape 1 (helpers de vue).
