# Phase 0 — Audit avant l'outillage release

**Date :** 2026-07-18
**Branche :** `chore/release-tooling` (depuis `main` @ `8ccd29c`, v0.3.0 mergé)

## `nix develop --command just ci`

- **exit 0.** fmt-check ✅ · lint (qmllint exit 0) ✅ · test **24 passed, 0 failed**.

## Constats infra (point de départ)

- **Aucun `.github/`** → pas de CI GitHub Actions ni de workflow release.
- **Pas de `cliff.toml`**, pas de `CHANGELOG.md`, pas de `renovate.json`.
- `.pre-commit-config.yaml` présent, délègue déjà à `just` (fmt-check/lint) + alejandra/deadnix.
- `flake.nix` : flake-parts, nixpkgs unstable, outputs `homeModules.default`,
  `packages.dev-bar`, `apps.dev-bar`, `devShells.default`. **Pas d'output `checks`.**
  `git-cliff` **absent** du dev shell (à ajouter).
- **`plugin.json` : `"version": "0.1.0"`** — périmé (on est à v0.3.0), à corriger.
- Remote : `git@github.com:gfriloux/auspex.git` (GitHub, SSH).
- Commits **100 % Conventional Commits** avec scopes (`feat(view)`, `fix(view)`, `docs`,
  `chore`, `refactor(view)`…) → git-cliff s'applique directement.

## Conclusion

Terrain vierge côté release. Rien à nettoyer. Ce plan **n'entre pas** dans `query`/`model`/
`view` : aucun golden touché. Il ajoute de l'outillage (`nix`, `ci`, `docs`) + un bump de
version `plugin.json`.
